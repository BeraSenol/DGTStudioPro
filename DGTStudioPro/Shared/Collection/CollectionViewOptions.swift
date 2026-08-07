import SwiftUI

/// Everything the View Options panel sets, owned by one type.
///
/// **An owning type, not `@AppStorage`, and D25′'s reason applies literally.**
/// Icon size is read by the grid that lays out columns *and* by the card that
/// draws a glyph, and the sort is read by a table header *and* by a picker.
/// Four `@AppStorage` sites for two values is four chances to disagree about a
/// default — the twin-read-site pattern, which `SleepInhibitor` and
/// `InspectorSectionCollapse` already answer this way. Every reader goes
/// through a property here; the defaults are stated exactly once, in `init`.
///
/// **The `UserDefaults` injection is load-bearing rather than tidy**, the
/// `InspectorSectionCollapse` finding: `.defaultAppStorage(_:)` redirects the
/// property *wrapper* and has nothing to say about an object handed a suite at
/// construction. A suite passed here is the one this object reads, which is
/// what makes the tests able to drive it without touching `.standard`.
///
/// **Clamped on every read-back rather than only on write**, the
/// `EngineConfiguration` arrangement: a hand-edited plist cannot push the grid
/// into a column of nothing or a card the size of the window.
@MainActor
@Observable
internal final class CollectionViewOptions {

    // MARK: Geometry constants

    /// The card's width, which is what the grid packs.
    ///
    /// The default is the old `CollectionGridMetrics.minimumColumnWidth`
    /// verbatim, so a fresh install and every install that never opens the
    /// panel lay out exactly as before this shipped. The floor is where a
    /// two-line name stops fitting at all; the ceiling is where six columns
    /// need a wider window than a laptop has.
    internal static let iconSizeRange: ClosedRange<CGFloat> = 80...240
    internal static let defaultIconSize: CGFloat = 120

    /// Both axes, as before — the gutters read square.
    internal static let spacingRange: ClosedRange<CGFloat> = 4...40
    internal static let defaultSpacing: CGFloat = 16

    /// **The glyph is a fraction of the card, not a second slider.** 0.5 is
    /// not a taste: it is 60 over 120, the exact pair the card and the grid
    /// carried before this existed, so at the default nothing moves. Deriving
    /// it means "icon size" changes the icon — a slider that repacked the grid
    /// while leaving the glyph at 60pt would be named after the one thing it
    /// did not do.
    internal static let glyphWidthFraction: CGFloat = 0.5

    /// Unchanged, and deliberately not on the panel. It insets the grid from
    /// the window's own dividers, which is a property of the destination's
    /// chrome rather than of the cards — Finder does not offer it either.
    internal static let inset: CGFloat = 16

    // MARK: Stored Properties

    private let defaults: UserDefaults

    /// **Never assign to a property from inside its own `didSet` on an
    /// `@Observable` type.** The first version of these two clamped in
    /// `didSet` with a comment claiming it "re-enters once and settles" — the
    /// rule for a plain stored property, where Swift deliberately does not
    /// re-run an observer for an assignment made inside it. `@Observable`
    /// rewrites every stored property into a computed one over private
    /// storage, so the self-assignment goes through the *setter* rather than
    /// touching storage, the observer fires again, and it recurses until the
    /// stack guard page. It crashed as `EXC_BAD_ACCESS (code=2)`, which reads
    /// like a memory bug and is a control-flow one.
    ///
    /// Computed over explicit storage instead: one place that clamps, one that
    /// writes, and no observer to re-enter. `EngineConfiguration.clamped(to:)`
    /// is still the app's one clamp — a second spelling here would be the twin
    /// this type exists to avoid.
    ///
    /// The storage is *not* `@ObservationIgnored`: the macro instruments it,
    /// so a view reading `iconSize` through the accessor registers a
    /// dependency on the stored property underneath and still updates. Marking
    /// it ignored would compile and silently stop the grid from redrawing when
    /// the slider moves.
    private var iconSizeStorage: CGFloat

    internal var iconSize: CGFloat {
        get { iconSizeStorage }
        set {
            let clamped = newValue.clamped(to: Self.iconSizeRange)
            guard clamped != iconSizeStorage else { return }
            iconSizeStorage = clamped
            defaults.set(Double(clamped), forKey: StorageKeys.collectionIconSize)
        }
    }

    private var spacingStorage: CGFloat

    internal var spacing: CGFloat {
        get { spacingStorage }
        set {
            let clamped = newValue.clamped(to: Self.spacingRange)
            guard clamped != spacingStorage else { return }
            spacingStorage = clamped
            defaults.set(Double(clamped), forKey: StorageKeys.collectionGridSpacing)
        }
    }

    /// **`didSet` is safe here and would not be if these ever needed
    /// correcting.** The two sorts persist whatever they are handed — the
    /// value is already valid by construction, since `CollectionSort` cannot
    /// hold a field that does not exist — so nothing assigns to the property
    /// from inside its own observer, which is the one thing that recurses on an
    /// `@Observable` type (see `iconSize`). If a future field ever needs
    /// normalizing on write, these must become computed-over-storage rather
    /// than growing a self-assignment here.
    internal var librarySort: CollectionSort<LibrarySortField> {
        didSet {
            guard librarySort != oldValue else { return }
            defaults.set(librarySort.storedValue, forKey: StorageKeys.librarySort)
        }
    }

    internal var playersSort: CollectionSort<PlayersSortField> {
        didSet {
            guard playersSort != oldValue else { return }
            defaults.set(playersSort.storedValue, forKey: StorageKeys.playersSort)
        }
    }

    // MARK: Session State

    /// Which collection surface the View Options panel should describe.
    ///
    /// **Session state, deliberately unpersisted** — every other property here
    /// is a preference, and this is a fact about what is on screen right now.
    /// Restoring it would point a restored panel at a window that may not
    /// exist. Filed below the four preferences under its own `MARK` rather
    /// than between the two sorts, where it split a pair that reads as one
    /// fact; the distinction it is on the wrong side of is the whole reason it
    /// has no `didSet`.
    ///
    /// **Written by the destinations, read by the panel — and the panel must
    /// not read focus itself.** The first version had the window hold
    /// `@FocusedValue` and latch the last non-nil subject, which cannot work
    /// and is worth recording rather than quietly replacing: opening the panel
    /// makes it key, so the focused value is *already* nil at the panel's
    /// first render, and the latch had nothing to catch. A latch only works
    /// where a non-nil value is observable, and that is inside the
    /// destination, which is on screen while its own window is key. So the
    /// destination mirrors, this holds, and the panel is a pure reader.
    ///
    /// That is also what makes it retarget correctly across tabs: focus
    /// changes fire in the destination, where `.onAppear` would not.
    internal var activeSubject: CollectionViewOptionsSubject?

    // MARK: Initialization

    /// **`object(forKey:)` rather than `double(forKey:)` for the two
    /// measurements**, because `double(forKey:)` returns 0 for an absent key
    /// and 0 is inside no sane range — clamping it would silently hand every
    /// fresh install the floor instead of the default. The absent case has to
    /// be distinguishable from a stored zero, which only the optional read is.
    internal init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Closures rather than unapplied `init` references throughout, and the
        // reason is worth one comment because the tidier spelling does not
        // compile. `.map(CGFloat.init)` is ambiguous — `CGFloat` has an
        // initializer for every numeric type in the standard library, and an
        // unapplied reference gives the type checker nothing to pick from; the
        // argument's `Double` type is not enough, because several of those
        // overloads accept it. `CollectionSort.init(storedValue:)` is the same
        // shape one label away from two sibling initializers. A closure states
        // the call and the ambiguity is gone.
        // The **storage**, not the accessors: going through the setters here
        // would write the defaults straight back into `UserDefaults` on first
        // launch, turning "absent" into "present" and quietly discarding the
        // distinction the `object(forKey:)` read above exists to preserve.
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

    /// The card's document glyph width at the current size.
    internal var glyphWidth: CGFloat { iconSize * Self.glyphWidthFraction }

    /// How many columns fit, computed rather than left to `.adaptive`.
    ///
    /// **This is the whole reason the grid is not adaptive**, and it is the
    /// `CollapsibleSection` rule in geometric form. `IconGridSelection` needs
    /// the column count to answer "where does ↓ land", and `.adaptive` never
    /// reports the count it chose — so an adaptive grid would mean the layout
    /// packing one number of columns while the arrow keys stepped by another,
    /// and the two would agree only by luck at whatever window width someone
    /// happened to test. Computing it here makes it one number, used twice.
    ///
    /// Floors at 1: a window narrower than one card still renders a column
    /// rather than dividing by a count of zero. Pinned from both ends by
    /// `aWindowNarrowerThanOneCardStillHasAColumn`.
    internal static func columnCount(
        containerWidth: CGFloat,
        iconSize: CGFloat,
        spacing: CGFloat
    ) -> Int {
        let available = containerWidth - inset * 2
        guard available > 0, iconSize > 0 else { return 1 }
        // `+ spacing` on both sides of the divide because N cards carry N−1
        // gutters, not N. Without it the count is short by one at exactly the
        // widths where a card would have fit flush.
        let fitted = Int(((available + spacing) / (iconSize + spacing)).rounded(.down))
        return max(1, fitted)
    }

    internal func columnCount(containerWidth: CGFloat) -> Int {
        Self.columnCount(containerWidth: containerWidth, iconSize: iconSize, spacing: spacing)
    }

    /// `.flexible`, not `.fixed`, so the last column's slack is shared out
    /// rather than left as a ragged right edge. The count is ours; the width
    /// inside it is still SwiftUI's to distribute.
    internal func columns(containerWidth: CGFloat) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: Self.iconSizeRange.lowerBound), spacing: spacing),
            count: columnCount(containerWidth: containerWidth)
        )
    }
}
