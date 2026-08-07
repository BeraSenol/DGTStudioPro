import Foundation
import SwiftUI
import Testing
@testable import DGTStudioPro

/// The View Options panel's value layer: grid geometry, the sort grammar, and
/// the persistence contract.
///
/// **`@MainActor` because `CollectionViewOptions` is** — it is an
/// `@Observable` class injected into a `WindowGroup` and read from views. The
/// column-count arithmetic is `static` and could have been checked from
/// anywhere, and it is deliberately *not* split into a nonisolated suite: the
/// isolation here is a fact about the type, not a constraint worth routing
/// around, and D44′'s lesson cuts the other way too — a suite should sit where
/// its subject does unless the nonisolation is itself the claim.
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

    /// The shipped default reproduces the geometry that stood before the
    /// slider existed: 6 columns at 120pt in a window that was showing 6.
    ///
    /// This is the pin that says the migration was a no-op for anyone who
    /// never opens the panel — `CollectionGridMetrics.columnCount` was a hard
    /// 6, and a change that quietly repacked every existing grid would be a
    /// visual regression nobody asked for.
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

    /// **This one crashed rather than failed, and that is the useful part.**
    /// The clamp was written in `didSet` as a self-assignment — correct for a
    /// plain stored property, where Swift will not re-run an observer for an
    /// assignment made inside it, and infinitely recursive on an `@Observable`
    /// type, where the macro has already rewritten the property into a
    /// computed one over private storage. The symptom was
    /// `EXC_BAD_ACCESS (code=2)` on the stack guard page: a memory error
    /// spelling a control-flow bug.
    ///
    /// Kept as three writes rather than split, because reaching the *second*
    /// one at all is most of what it proves — a recursing setter never
    /// returns.
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

    /// A clamped write must still **persist** the corrected value, not the
    /// one that was asked for.
    ///
    /// The recursion fix moved the `defaults.set` from a `didSet` into a
    /// setter, and the obvious way to write that setter — store, then write
    /// `newValue` — persists the unclamped number. Nothing in memory would
    /// show it: the property reads back correct all session, and the floor
    /// only appears on the next launch, through the clamp on load. Reload is
    /// the only place this is visible.
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

    /// The init must write **storage**, not go through the setters.
    ///
    /// Routing initialization through the accessors would persist the defaults
    /// on first launch, turning "absent" into "present" — which destroys the
    /// distinction `object(forKey:)` is read for two tests up, silently and
    /// only for users who never touch the panel.
    @Test func constructionWritesNothingToDefaults() {
        let defaults = Self.scratch()
        _ = CollectionViewOptions(defaults: defaults)

        #expect(defaults.object(forKey: StorageKeys.collectionIconSize) == nil)
        #expect(defaults.object(forKey: StorageKeys.collectionGridSpacing) == nil)
        #expect(defaults.object(forKey: StorageKeys.librarySort) == nil)
    }

    /// **The `object(forKey:)` pin.** `double(forKey:)` answers 0 for an
    /// absent key, and 0 is below both floors — so reading that way and
    /// clamping would hand every fresh install the smallest icon in the range
    /// while looking exactly like a stored preference. The arm that catches it
    /// is an empty suite, which is the state a new Mac is in.
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
    /// destination opens on its default — D45′'s retired-raw-value rule, so
    /// removing a column costs no migration.
    @Test(arguments: ["", "garbage", "event", "event:sideways", ":forward", "notAField:forward"])
    func anUnreadableStoredSortFallsBackToTheDefault(_ stored: String) {
        let defaults = Self.scratch()
        defaults.set(stored, forKey: StorageKeys.librarySort)

        let options = CollectionViewOptions(defaults: defaults)

        #expect(options.librarySort == .default)
    }
}

/// The sort grammar itself — the half that has to survive a table header and a
/// picker writing the same value.
///
/// **Nonisolated, and that is load-bearing.** `CollectionSort` and both field
/// enums are pure value types with no view and no store; a suite that needed
/// the main actor here would mean one of them had acquired isolation it has no
/// use for. The D44′ compile-time witness.
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

    /// **A persistence contract, asserted on literals** — one of the few
    /// places a hard-coded string is the correct thing to test (D36′'s
    /// `theCheckmateTypeFieldKeepsItsStoredRawValue`). These land in
    /// `UserDefaults`; letting a Swift rename move them would silently reset
    /// the user's sort, and nothing else in the app would notice.
    @Test func libraryFieldRawValuesAreStable() {
        #expect(LibrarySortField.index.rawValue == "index")
        #expect(LibrarySortField.checkmateType.rawValue == "checkmateType")
        #expect(LibrarySortField.eco.rawValue == "eco")
        #expect(PlayersSortField.rank.rawValue == "rank")
        #expect(PlayersSortField.winRate.rawValue == "winRate")
        #expect(PlayersSortField.specialMates.rawValue == "specialMates")
    }

    /// The two statements of the launch order must agree.
    ///
    /// `LibraryDestination.defaultSortOrder` and `LibrarySortField.default`
    /// are the same claim in two files — the destination's is what the mode
    /// views' previews use, this one is what an absent preference reads as. If
    /// they diverge, the app opens on one order and every canvas shows
    /// another, which is invisible until someone compares them side by side.
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
