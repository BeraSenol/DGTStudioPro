import Foundation
import SwiftUI
import Testing
@testable import DGTStudioPro

/// The panel's value layer: grid geometry, sort grammar, persistence contract. @MainActor — a
/// fact about the type, not a constraint worth routing around.
@MainActor
@Suite("Collection view options")
struct CollectionViewOptionsTests {

    // MARK: Helpers

    /// A wiped scratch suite per test. Never `.standard`: these tests *write*,
    /// so a shared suite would let one case's slider land in another's
    /// assertion, and the developer's own preferences are not the fixture.
    private static func scratch(_ name: String = #function) -> UserDefaults {
        let suite = "test.collectionViewOptions.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: Column derivation

    /// The shipped default reproduces the pre-slider geometry: 6 columns at 120 pt.
    @Test func theDefaultsReproduceTheOldSixColumnGrid() {
        // 6 cards at 120 + 5 gutters at 16 + 2 insets at 16 = 832.
        let count = CollectionViewOptions.columnCount(
            containerWidth: 832,
            iconSize: CollectionViewOptions.defaultIconSize,
            spacing: CollectionViewOptions.defaultSpacing
        )
        #expect(count == 6)
    }

    /// N cards carry N−1 gutters, not N. Off by one here and the grid drops a
    /// column at exactly the widths where one would have fit flush — the
    /// failure that looks like "the window just wastes space on the right".
    @Test func aWidthThatFitsExactlyGetsThatManyColumns() {
        // 4 cards at 100 + 3 gutters at 10 + 2 insets at 16 = 462.
        #expect(
            CollectionViewOptions.columnCount(containerWidth: 462, iconSize: 100, spacing: 10) == 4
        )
        // One point short of the fifth card's own width, let alone its gutter.
        #expect(
            CollectionViewOptions.columnCount(containerWidth: 571, iconSize: 100, spacing: 10) == 4
        )
        // 5 cards at 100 + 4 gutters at 10 + 2 insets at 16 = 572.
        #expect(
            CollectionViewOptions.columnCount(containerWidth: 572, iconSize: 100, spacing: 10) == 5
        )
    }

    /// The degenerate end, from both sides of zero. A `LazyVGrid` handed an
    /// empty column array renders nothing at all, and a window narrower than
    /// one card is reachable by dragging the sidebar — so the floor is a real
    /// state, not a defensive nicety.
    @Test(arguments: [CGFloat(0), 1, 32, 80])
    func aWindowNarrowerThanOneCardStillHasAColumn(_ width: CGFloat) {
        #expect(
            CollectionViewOptions.columnCount(containerWidth: width, iconSize: 120, spacing: 16) >= 1
        )
    }

    /// Bigger icons mean fewer columns at a fixed width — the direction the
    /// slider promises. Asserted as a *relationship* rather than against two
    /// literals, because the literals would keep passing if both moved.
    @Test func alargerIconYieldsFewerColumns() {
        let narrow = CollectionViewOptions.columnCount(
            containerWidth: 900, iconSize: 80, spacing: 16
        )
        let wide = CollectionViewOptions.columnCount(
            containerWidth: 900, iconSize: 240, spacing: 16
        )
        #expect(narrow > wide)
    }

    // MARK: Clamping and persistence

    /// **This one crashed rather than failed**: a `didSet` self-assignment recurses on an
    /// `@Observable` (the macro re-enters observers) — hence computed-over-storage.
    @Test func sizesClampToTheirRangesOnWrite() {
        let options = CollectionViewOptions(defaults: Self.scratch())

        options.iconSize = 10_000
        #expect(options.iconSize == CollectionViewOptions.iconSizeRange.upperBound)

        options.iconSize = -5
        #expect(options.iconSize == CollectionViewOptions.iconSizeRange.lowerBound)

        options.spacing = 10_000
        #expect(options.spacing == CollectionViewOptions.spacingRange.upperBound)

        options.spacing = -5
        #expect(options.spacing == CollectionViewOptions.spacingRange.lowerBound)
    }

    /// A clamped write persists the *corrected* value — visible only on reload.
    @Test func aClampedWritePersistsTheClampedValue() {
        let defaults = Self.scratch()
        let first = CollectionViewOptions(defaults: defaults)
        first.iconSize = 10_000

        let reloaded = CollectionViewOptions(defaults: defaults)

        #expect(reloaded.iconSize == CollectionViewOptions.iconSizeRange.upperBound)
        #expect(
            defaults.object(forKey: StorageKeys.collectionIconSize) as? Double
                == Double(CollectionViewOptions.iconSizeRange.upperBound)
        )
    }

    /// Init writes **storage**, not the setters — routing through accessors would persist defaults
    /// for users who never touch the panel.
    @Test func constructionWritesNothingToDefaults() {
        let defaults = Self.scratch()
        _ = CollectionViewOptions(defaults: defaults)

        #expect(defaults.object(forKey: StorageKeys.collectionIconSize) == nil)
        #expect(defaults.object(forKey: StorageKeys.collectionGridSpacing) == nil)
        #expect(defaults.object(forKey: StorageKeys.librarySort) == nil)
    }

    /// The `object(forKey:)` pin: `double(forKey:)` answers 0 for absent, and clamping 0 hands
    /// every fresh install the floor.
    @Test func anAbsentPreferenceReadsTheDefaultRatherThanTheFloor() {
        let options = CollectionViewOptions(defaults: Self.scratch())

        #expect(options.iconSize == CollectionViewOptions.defaultIconSize)
        #expect(options.spacing == CollectionViewOptions.defaultSpacing)
        #expect(options.iconSize != CollectionViewOptions.iconSizeRange.lowerBound)
    }

    /// Through a *reload*, not through memory — the `InspectorSectionCollapse`
    /// shape. A round trip inside one instance proves the property setter
    /// works and says nothing about whether anything reached the defaults.
    @Test func geometryAndSortSurviveAReload() {
        let defaults = Self.scratch()
        let first = CollectionViewOptions(defaults: defaults)
        first.iconSize = 160
        first.spacing = 24
        first.librarySort = CollectionSort(field: .event, isReverse: true)
        first.playersSort = CollectionSort(field: .rating, isReverse: true)

        let second = CollectionViewOptions(defaults: defaults)

        #expect(second.iconSize == 160)
        #expect(second.spacing == 24)
        #expect(second.librarySort == CollectionSort(field: .event, isReverse: true))
        #expect(second.playersSort == CollectionSort(field: .rating, isReverse: true))
    }

    /// A stored spelling this build no longer understands is dropped, and the
    /// destination opens on its default — the retired-raw-value rule, so
    /// removing a column costs no migration.
    @Test(arguments: ["", "garbage", "event", "event:sideways", ":forward", "notAField:forward"])
    func anUnreadableStoredSortFallsBackToTheDefault(_ stored: String) {
        let defaults = Self.scratch()
        defaults.set(stored, forKey: StorageKeys.librarySort)

        let options = CollectionViewOptions(defaults: defaults)

        #expect(options.librarySort == .default)
    }
}

/// The sort grammar — the half that survives a header and a picker writing one value.
/// Nonisolated, load-bearing: the types must stay value-layer.
@Suite("Collection sort fields")
struct CollectionSortFieldTests {

    /// **The round trip that makes two doors safe.** The panel reads the
    /// header's choice by matching key paths; if this breaks, clicking a
    /// column silently stops updating the panel and the two drift apart with
    /// no error anywhere.
    @Test func everyLibraryFieldSurvivesTheComparatorRoundTrip() {
        for field in LibrarySortField.allCases {
            for isReverse in [false, true] {
                let sort = CollectionSort(field: field, isReverse: isReverse)
                let recovered = CollectionSort<LibrarySortField>(comparators: sort.comparators)
                #expect(recovered == sort, "\(field.rawValue) reverse=\(isReverse)")
            }
        }
    }

    @Test func everyPlayersFieldSurvivesTheComparatorRoundTrip() {
        for field in PlayersSortField.allCases {
            for isReverse in [false, true] {
                let sort = CollectionSort(field: field, isReverse: isReverse)
                let recovered = CollectionSort<PlayersSortField>(comparators: sort.comparators)
                #expect(recovered == sort, "\(field.rawValue) reverse=\(isReverse)")
            }
        }
    }

    /// The whole domain, both directions — endpoint off-by-ones survive spot
    /// checks, and a field added later without a `keyPath` case would show up
    /// here rather than as a picker that silently stops working.
    @Test func everyFieldSurvivesTheStoredStringRoundTrip() {
        for field in LibrarySortField.allCases {
            for isReverse in [false, true] {
                let sort = CollectionSort(field: field, isReverse: isReverse)
                #expect(CollectionSort<LibrarySortField>(storedValue: sort.storedValue) == sort)
            }
        }
    }

    /// Nil is a real answer and has to stay one: an unmapped column should
    /// leave the panel showing nothing rather than quietly claiming the sort
    /// is something else.
    @Test func anUnknownKeyPathMatchesNoField() {
        #expect(LibrarySortField.matching(\PGN.timeControl) == nil)
        #expect(
            CollectionSort<LibrarySortField>(
                comparators: [KeyPathComparator(\PGN.timeControl)]
            ) == nil
        )
    }

    /// The separator is load-bearing for the one-key encoding, so it is pinned
    /// rather than trusted — a future field spelled `"eco:full"` would make
    /// every stored sort unreadable in a way that reads as a corrupt
    /// preference rather than as a naming mistake.
    @Test func everyFieldRawValueIsSeparatorSafe() {
        #expect(LibrarySortField.allCases.allSatisfy { !$0.rawValue.contains(":") })
        #expect(PlayersSortField.allCases.allSatisfy { !$0.rawValue.contains(":") })
    }

    /// A persistence contract asserted on literals — one of the few places a hard-coded string is
    /// the correct thing to test.
    @Test func libraryFieldRawValuesAreStable() {
        #expect(LibrarySortField.index.rawValue == "index")
        #expect(LibrarySortField.checkmateType.rawValue == "checkmateType")
        #expect(LibrarySortField.eco.rawValue == "eco")
        #expect(PlayersSortField.rank.rawValue == "rank")
        #expect(PlayersSortField.winRate.rawValue == "winRate")
        #expect(PlayersSortField.specialMates.rawValue == "specialMates")
    }

    /// The two statements of the launch order must agree — goes red if either moves alone.
    @Test func theLibraryDefaultMatchesTheDestination() {
        let fromField = CollectionSort<LibrarySortField>.default.comparators
        let fromDestination = LibraryDestination.defaultSortOrder

        #expect(fromField.count == fromDestination.count)
        #expect(fromField.first?.keyPath == fromDestination.first?.keyPath)
        #expect(fromField.first?.order == fromDestination.first?.order)
    }

    @Test func thePlayersDefaultMatchesTheDestination() {
        let fromField = CollectionSort<PlayersSortField>.default.comparators
        let fromDestination = PlayersDestination.defaultSortOrder

        #expect(fromField.first?.keyPath == fromDestination.first?.keyPath)
        #expect(fromField.first?.order == fromDestination.first?.order)
    }
}
