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

    /// Both axes, as before - the gutters read square.
    static let spacingRange: ClosedRange<CGFloat> = 4...40
    static let defaultSpacing: CGFloat = 16

    /// The glyph is a fraction of the card, not a second slider. 0.5 = 60/120, the exact pre-panel
    /// pair - at the default nothing moves.
    static let glyphWidthFraction: CGFloat = 0.5

    /// Where both destinations open before anyone chooses. Stated once here rather than twice as
    /// an `@AppStorage` initial value at each destination, which is the twin this replaced.
    static let defaultViewMode: CollectionViewMode = .list

    /// Deliberately not on the panel: insets the grid from the window's dividers - destination
    /// chrome, not cards. Finder doesn't offer it either.
    static let inset: CGFloat = 16

    // MARK: Stored Properties

    private let defaults: UserDefaults

    /// **Never assign to a property inside its own `didSet` on an `@Observable` type** - the macro
    /// re-enters observers, unlike a plain stored property. Hence computed-over-storage with the
    /// clamp in the setter. Storage is not `@ObservationIgnored` - the macro instruments it.
    ///
    /// Four geometry properties where there were two, flat rather than a `[Collection: CGFloat]`
    /// dictionary: the macro instruments a dictionary as one value, so writing the Library's size
    /// would notify the Players grid too and re-lay out a surface nothing changed on. Flat pairs
    /// also match the sorts below, which were already per-destination.
    private var libraryIconSizeStorage: CGFloat

    var libraryIconSize: CGFloat {
        get { libraryIconSizeStorage }
        set {
            let clamped = newValue.clamped(to: Self.iconSizeRange)
            guard clamped != libraryIconSizeStorage else { return }
            libraryIconSizeStorage = clamped
            defaults.set(Double(clamped), forKey: StorageKeys.libraryIconSize)
        }
    }

    private var playersIconSizeStorage: CGFloat

    var playersIconSize: CGFloat {
        get { playersIconSizeStorage }
        set {
            let clamped = newValue.clamped(to: Self.iconSizeRange)
            guard clamped != playersIconSizeStorage else { return }
            playersIconSizeStorage = clamped
            defaults.set(Double(clamped), forKey: StorageKeys.playersIconSize)
        }
    }

    private var librarySpacingStorage: CGFloat

    var librarySpacing: CGFloat {
        get { librarySpacingStorage }
        set {
            let clamped = newValue.clamped(to: Self.spacingRange)
            guard clamped != librarySpacingStorage else { return }
            librarySpacingStorage = clamped
            defaults.set(Double(clamped), forKey: StorageKeys.libraryGridSpacing)
        }
    }

    private var playersSpacingStorage: CGFloat

    var playersSpacing: CGFloat {
        get { playersSpacingStorage }
        set {
            let clamped = newValue.clamped(to: Self.spacingRange)
            guard clamped != playersSpacingStorage else { return }
            playersSpacingStorage = clamped
            defaults.set(Double(clamped), forKey: StorageKeys.playersGridSpacing)
        }
    }

    /// `didSet` is safe *here* and would not be if these needed correcting: sorts and modes persist
    /// whatever they are handed - already valid by construction.
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

    /// View mode, owned here rather than read at each destination by `@AppStorage`.
    ///
    /// It was the latter, against one shared key, and the two `.list` initial values were a
    /// documented twin. Moving it here is what `StorageKeys` says the twins should eventually
    /// become: the default is stated once, in `init`, and - the reason it had to move now - an
    /// `@AppStorage` default must be a literal, so a view could never fall back to the retired key
    /// the migration reads.
    var libraryViewMode: CollectionViewMode {
        didSet {
            guard libraryViewMode != oldValue else { return }
            defaults.set(libraryViewMode.rawValue, forKey: StorageKeys.libraryViewMode)
        }
    }

    var playersViewMode: CollectionViewMode {
        didSet {
            guard playersViewMode != oldValue else { return }
            defaults.set(playersViewMode.rawValue, forKey: StorageKeys.playersViewMode)
        }
    }

    // MARK: Session State

    /// Which surface the panel describes. **Session state, deliberately unpersisted** - a fact
    /// about what is on screen. Written by the destinations; the panel must not read focus itself
    /// (opening it makes it key, so its focused value is already nil).
    var activeSubject: CollectionViewOptionsSubject?

    // MARK: Initialization

    /// `object(forKey:)`, not `double(forKey:)`: the latter returns 0 for absent, and clamping 0
    /// hands every fresh install the floor instead of the default.
    ///
    /// **The migration is a read, not a write.** Each of the six new keys falls back to the retired
    /// shared key before it falls back to the constant, so an install that had tuned its grid or
    /// picked a view mode keeps both, on both destinations, without anything being copied at
    /// launch. The new key is written the first time the reader moves that slider, and the old one
    /// is never written again - which is what keeps `constructionWritesNothingToDefaults` true.
    /// The two destinations start life agreeing, and diverge the moment either is touched.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Closures, not `.map(CGFloat.init)` - ambiguous: CGFloat has an initializer for every numeric
        // type. Assigning the **storage**: the setters' clamp path is for later writes, not seeding.
        func storedSize(_ key: String, legacy: String) -> CGFloat? {
            let value = defaults.object(forKey: key) ?? defaults.object(forKey: legacy)
            return (value as? Double).map { CGFloat($0) }
        }

        self.libraryIconSizeStorage =
            (storedSize(StorageKeys.libraryIconSize, legacy: StorageKeys.legacyCollectionIconSize)
                ?? Self.defaultIconSize).clamped(to: Self.iconSizeRange)
        self.playersIconSizeStorage =
            (storedSize(StorageKeys.playersIconSize, legacy: StorageKeys.legacyCollectionIconSize)
                ?? Self.defaultIconSize).clamped(to: Self.iconSizeRange)

        self.librarySpacingStorage =
            (storedSize(StorageKeys.libraryGridSpacing, legacy: StorageKeys.legacyCollectionGridSpacing)
                ?? Self.defaultSpacing).clamped(to: Self.spacingRange)
        self.playersSpacingStorage =
            (storedSize(StorageKeys.playersGridSpacing, legacy: StorageKeys.legacyCollectionGridSpacing)
                ?? Self.defaultSpacing).clamped(to: Self.spacingRange)

        self.librarySort = defaults.string(forKey: StorageKeys.librarySort)
            .flatMap { CollectionSort<LibrarySortField>(storedValue: $0) } ?? .default

        self.playersSort = defaults.string(forKey: StorageKeys.playersSort)
            .flatMap { CollectionSort<PlayersSortField>(storedValue: $0) } ?? .default

        // A stored spelling this build no longer understands falls back rather than trapping - the
        // retired-raw-value rule the sorts already follow.
        func storedMode(_ key: String) -> CollectionViewMode? {
            let raw = defaults.string(forKey: key)
                ?? defaults.string(forKey: StorageKeys.legacyCollectionViewMode)
            return raw.flatMap(CollectionViewMode.init(rawValue:))
        }

        self.libraryViewMode = storedMode(StorageKeys.libraryViewMode) ?? Self.defaultViewMode
        self.playersViewMode = storedMode(StorageKeys.playersViewMode) ?? Self.defaultViewMode
    }

    // MARK: Per-Collection Access

    /// The geometry for one collection, read by the grids and the panel so neither restates the
    /// library-or-players branch. Read-only: writes go through the named properties, which is what
    /// keeps the clamp and the persistence in one place per value.
    func iconSize(for collection: CollectionViewOptionsSubject.Collection) -> CGFloat {
        switch collection {
        case .library: libraryIconSize
        case .players: playersIconSize
        }
    }

    func spacing(for collection: CollectionViewOptionsSubject.Collection) -> CGFloat {
        switch collection {
        case .library: librarySpacing
        case .players: playersSpacing
        }
    }

    /// The card's glyph width for one collection's current size.
    func glyphWidth(for collection: CollectionViewOptionsSubject.Collection) -> CGFloat {
        iconSize(for: collection) * Self.glyphWidthFraction
    }

    func columnCount(
        containerWidth: CGFloat,
        for collection: CollectionViewOptionsSubject.Collection
    ) -> Int {
        Self.columnCount(
            containerWidth: containerWidth,
            iconSize: iconSize(for: collection),
            spacing: spacing(for: collection)
        )
    }

    /// `.flexible`, not `.fixed`: the count is ours; the width inside it is SwiftUI's to distribute.
    func columns(
        containerWidth: CGFloat,
        for collection: CollectionViewOptionsSubject.Collection
    ) -> [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(minimum: Self.iconSizeRange.lowerBound),
                spacing: spacing(for: collection)
            ),
            count: columnCount(containerWidth: containerWidth, for: collection)
        )
    }

    // MARK: Derived Geometry

    /// Columns computed rather than `.adaptive` - `IconGridSelection` needs the count to answer
    /// "where does ↓ land", and `.adaptive` never reports one. Pinned from both ends.
    static func columnCount(
        containerWidth: CGFloat,
        iconSize: CGFloat,
        spacing: CGFloat
    ) -> Int {
        let available = containerWidth - inset * 2
        guard available > 0, iconSize > 0 else { return 1 }
        // `+ spacing` both sides: N cards carry N−1 gutters - without it the count is short by one
        // exactly where a card would have fit flush.
        let fitted = Int(((available + spacing) / (iconSize + spacing)).rounded(.down))
        return max(1, fitted)
    }

    // The un-keyed `glyphWidth`, `columnCount(containerWidth:)` and `columns(containerWidth:)` are
    // gone with the shared geometry they read. Their keyed replacements are above; a caller now
    // has to say which collection it is laying out, which is the point - an overload that silently
    // picked one would be the shared value back under a new name.
}
