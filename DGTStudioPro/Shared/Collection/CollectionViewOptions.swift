import SwiftUI

/// Everything the View Options panel sets, owned by one type: values read by
/// grid and card alike go through properties here; defaults stated once, in `init`.
/// `UserDefaults` injection is load-bearing (scratch suites); clamped on every read-back.
@MainActor
@Observable
final class CollectionViewOptions {

    // MARK: Geometry constants

    /// Card width the grid packs. Default is the old `minimumColumnWidth` verbatim, so an install
    /// that never opens the panel lays out exactly as before.
    static let iconSizeRange: ClosedRange<CGFloat> = 80...240
    static let defaultIconSize: CGFloat = 120

    /// Both axes, as before — the gutters read square.
    static let spacingRange: ClosedRange<CGFloat> = 4...40
    static let defaultSpacing: CGFloat = 16

    /// The glyph is a fraction of the card, not a second slider. 0.5 = 60/120, the exact pre-panel
    /// pair — at the default nothing moves.
    static let glyphWidthFraction: CGFloat = 0.5

    /// Deliberately not on the panel: insets the grid from the window's dividers — destination
    /// chrome, not cards. Finder doesn't offer it either.
    static let inset: CGFloat = 16

    // MARK: Stored Properties

    private let defaults: UserDefaults

    /// **Never assign to a property inside its own `didSet` on an `@Observable` type** — the macro
    /// re-enters observers, unlike a plain stored property. Hence computed-over-storage with the
    /// clamp in the setter. Storage is not `@ObservationIgnored` — the macro instruments it.
    private var iconSizeStorage: CGFloat

    var iconSize: CGFloat {
        get { iconSizeStorage }
        set {
            let clamped = newValue.clamped(to: Self.iconSizeRange)
            guard clamped != iconSizeStorage else { return }
            iconSizeStorage = clamped
            defaults.set(Double(clamped), forKey: StorageKeys.collectionIconSize)
        }
    }

    private var spacingStorage: CGFloat

    var spacing: CGFloat {
        get { spacingStorage }
        set {
            let clamped = newValue.clamped(to: Self.spacingRange)
            guard clamped != spacingStorage else { return }
            spacingStorage = clamped
            defaults.set(Double(clamped), forKey: StorageKeys.collectionGridSpacing)
        }
    }

    /// `didSet` is safe *here* and would not be if these needed correcting: sorts persist whatever
    /// they are handed — already valid by construction.
    var librarySort: CollectionSort<LibrarySortField> {
        didSet {
            guard librarySort != oldValue else { return }
            defaults.set(librarySort.storedValue, forKey: StorageKeys.librarySort)
        }
    }

    var playersSort: CollectionSort<PlayersSortField> {
        didSet {
            guard playersSort != oldValue else { return }
            defaults.set(playersSort.storedValue, forKey: StorageKeys.playersSort)
        }
    }

    // MARK: Session State

    /// Which surface the panel describes. **Session state, deliberately unpersisted** — a fact
    /// about what is on screen. Written by the destinations; the panel must not read focus itself
    /// (opening it makes it key, so its focused value is already nil).
    var activeSubject: CollectionViewOptionsSubject?

    // MARK: Initialization

    /// `object(forKey:)`, not `double(forKey:)`: the latter returns 0 for absent, and clamping 0
    /// hands every fresh install the floor instead of the default.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Closures, not `.map(CGFloat.init)` — ambiguous: CGFloat has an initializer for every numeric
        // type. Assigning the **storage**: the setters' clamp path is for later writes, not seeding.
        let storedIconSize = (defaults.object(forKey: StorageKeys.collectionIconSize) as? Double)
            .map { CGFloat($0) }
        self.iconSizeStorage = (storedIconSize ?? Self.defaultIconSize)
            .clamped(to: Self.iconSizeRange)

        let storedSpacing = (defaults.object(forKey: StorageKeys.collectionGridSpacing) as? Double)
            .map { CGFloat($0) }
        self.spacingStorage = (storedSpacing ?? Self.defaultSpacing)
            .clamped(to: Self.spacingRange)

        self.librarySort = defaults.string(forKey: StorageKeys.librarySort)
            .flatMap { CollectionSort<LibrarySortField>(storedValue: $0) } ?? .default

        self.playersSort = defaults.string(forKey: StorageKeys.playersSort)
            .flatMap { CollectionSort<PlayersSortField>(storedValue: $0) } ?? .default
    }

    // MARK: Derived Geometry

    /// The card's glyph width at the current size.
    var glyphWidth: CGFloat { iconSize * Self.glyphWidthFraction }

    /// Columns computed rather than `.adaptive` — `IconGridSelection` needs the count to answer
    /// "where does ↓ land", and `.adaptive` never reports one. Pinned from both ends.
    static func columnCount(
        containerWidth: CGFloat,
        iconSize: CGFloat,
        spacing: CGFloat
    ) -> Int {
        let available = containerWidth - inset * 2
        guard available > 0, iconSize > 0 else { return 1 }
        // `+ spacing` both sides: N cards carry N−1 gutters — without it the count is short by one
        // exactly where a card would have fit flush.
        let fitted = Int(((available + spacing) / (iconSize + spacing)).rounded(.down))
        return max(1, fitted)
    }

    func columnCount(containerWidth: CGFloat) -> Int {
        Self.columnCount(containerWidth: containerWidth, iconSize: iconSize, spacing: spacing)
    }

    /// `.flexible`, not `.fixed`: the count is ours; the width inside it is SwiftUI's to distribute.
    func columns(containerWidth: CGFloat) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: Self.iconSizeRange.lowerBound), spacing: spacing),
            count: columnCount(containerWidth: containerWidth)
        )
    }
}
