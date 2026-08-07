import SwiftUI

/// Which collection surface the View Options panel is currently describing.
///
/// **Both halves, because the panel's contents depend on both.** The
/// destination decides which sort fields exist; the mode decides whether
/// there is a grid to size at all — a gallery filmstrip is one row by
/// construction (`IconGridSelection`'s degenerate case), so it has no columns
/// to give and its panel shows sort alone.
internal struct CollectionViewOptionsSubject: Equatable, Sendable {

    internal enum Collection: String, Sendable {
        case library
        case players

        internal var displayName: String {
            switch self {
            case .library: "Library"
            case .players: "Players"
            }
        }
    }

    internal var collection: Collection
    internal var mode: CollectionViewMode

    /// Only the icons grid packs columns. List and columns modes are tables,
    /// and the gallery is a one-row strip.
    internal var hasSizableGrid: Bool { mode == .icons }
}

private struct CollectionViewOptionsSubjectKey: FocusedValueKey {
    typealias Value = CollectionViewOptionsSubject
}

extension FocusedValues {
    /// Published by both collection destinations; read by the panel and by the
    /// View menu item. `focusedSceneValue`, so it resolves per window/tab and
    /// the panel follows whichever browser is in front.
    internal var collectionViewOptionsSubject: CollectionViewOptionsSubject? {
        get { self[CollectionViewOptionsSubjectKey.self] }
        set { self[CollectionViewOptionsSubjectKey.self] = newValue }
    }
}

/// Finder's ⌘J, for the two collection destinations.
///
/// **A singleton `Window`, and this is the third scene in the app that needed
/// no wrapper type.** D46′ and D53′ each had to mint one
/// (`EvaluationGraphRequest`, `GetInfoRequest`) because `openWindow(value:)`
/// routes by the value's *type* and the main group already claims
/// `PersistentIdentifier`. There is nothing to route here: the panel does not
/// take a subject, it *reads* the front one, so it is opened by
/// `openWindow(id:)` and the trap is sidestepped rather than paid a fourth
/// time — the `AnalysisQueueStatusWindowView` arrangement.
///
/// **One panel, not one per destination**, which is Finder's own answer and
/// also the honest one here: two panels that look identical while controlling
/// different destinations is a worse failure than a panel that retargets, and
/// the geometry half is shared between them anyway (`collectionViewMode`'s
/// argument — a size is a preference about browsing, not about a destination).
internal struct CollectionViewOptionsWindow: View {

    internal static let sceneID = "collectionViewOptions"

    @Environment(CollectionViewOptions.self) private var options

    /// **A pure reader — no `@FocusedValue` here, and that is the fix rather
    /// than a style choice.** This window first held the focused value and
    /// latched the last non-nil one, which cannot work: opening the panel
    /// makes it key, so by its first render the focused value is already nil
    /// and the latch has nothing to catch. Every path into this window showed
    /// the "no collection in front" arm, including the one that opened it from
    /// the Library. The latch moved into the destinations, which are on screen
    /// while their own window is key; see `CollectionViewOptions.activeSubject`.
    private var subject: CollectionViewOptionsSubject? { options.activeSubject }

    internal var body: some View {
        @Bindable var options = options

        Group {
            if let subject {
                Form {
                    sortSection(for: subject, options: $options)
                    if subject.hasSizableGrid {
                        gridSection(options: $options)
                    } else {
                        Section {
                            Text("Icon size and spacing apply to icon view.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .formStyle(.grouped)
                .navigationTitle("\(subject.collection.displayName) View Options")
            } else {
                // Reachable on a cold launch that restores this window with no
                // collection destination ever having been in front — the panel
                // has no subject to latch yet. Named rather than left to render
                // an empty `Form`, which reads as a broken window.
                // Argument order follows the memberwise init
                // (title / systemImage / message / identifier), not the order
                // they read in — a labelled memberwise init is still
                // positional.
                InspectorEmptyState(
                    title: "No Collection in Front",
                    systemImage: "slider.horizontal.3",
                    message: "Open the Library or Players to set view options.",
                    identifier: AccessibilityID.viewOptionsUnavailable
                )
            }
        }
        .frame(minWidth: 320, minHeight: 260)
    }

    // MARK: Sections

    /// Two branches rather than one generic control, deliberately.
    ///
    /// The two destinations' field enums are different types, so a shared
    /// picker would have to be generic over `CollectionSortField` *and* over
    /// which property of `CollectionViewOptions` it binds to — a type
    /// parameter plus a key path, to save eight lines of `Picker`. The
    /// `OpeningSection` call: two surfaces that agree today, each owning its
    /// own reason to.
    @ViewBuilder
    private func sortSection(
        for subject: CollectionViewOptionsSubject,
        options: Bindable<CollectionViewOptions>
    ) -> some View {
        Section("Sort By") {
            switch subject.collection {
            case .library:
                Picker("Sort By", selection: options.librarySort.field) {
                    ForEach(LibrarySortField.allCases, id: \.self) { field in
                        Text(field.displayName).tag(field)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.viewOptionsSortField)

                directionPicker(isReverse: options.librarySort.isReverse)

            case .players:
                Picker("Sort By", selection: options.playersSort.field) {
                    ForEach(PlayersSortField.allCases, id: \.self) { field in
                        Text(field.displayName).tag(field)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.viewOptionsSortField)

                directionPicker(isReverse: options.playersSort.isReverse)
            }
        }
    }

    /// Ascending / descending as words rather than an arrow glyph: the two
    /// destinations sort by dates, counts, ratings and names, and "descending"
    /// is the only label that reads correctly for all four. A ↑ beside "Last
    /// Played" tells you nothing about which end is recent.
    private func directionPicker(isReverse: Binding<Bool>) -> some View {
        Picker("Order", selection: isReverse) {
            Text("Ascending").tag(false)
            Text("Descending").tag(true)
        }
        .pickerStyle(.inline)
        .accessibilityIdentifier(AccessibilityID.viewOptionsSortDirection)
    }

    private func gridSection(options: Bindable<CollectionViewOptions>) -> some View {
        Section("Grid") {
            // `in:` takes the same ranges the type clamps to, so the slider
            // cannot ask for a value the object will silently correct — a
            // control whose extremes do nothing is the shape people report as
            // a stuck slider.
            sizedSlider(
                title: "Icon size",
                value: "\(Int(options.wrappedValue.iconSize)) pt",
                binding: options.iconSize,
                range: CollectionViewOptions.iconSizeRange,
                step: Self.iconSizeStep,
                minimumGlyph: "doc",
                minimumSize: 11,
                maximumGlyph: "doc",
                maximumSize: 22,
                identifier: AccessibilityID.viewOptionsIconSize
            )
            sizedSlider(
                title: "Grid spacing",
                value: nil,
                binding: options.spacing,
                range: CollectionViewOptions.spacingRange,
                step: Self.spacingStep,
                minimumGlyph: "square.grid.2x2.fill",
                minimumSize: 13,
                maximumGlyph: "square.grid.3x3.fill",
                maximumSize: 18,
                identifier: AccessibilityID.viewOptionsSpacing
            )
            Button("Use Defaults") {
                options.wrappedValue.iconSize = CollectionViewOptions.defaultIconSize
                options.wrappedValue.spacing = CollectionViewOptions.defaultSpacing
            }
            .accessibilityIdentifier(AccessibilityID.viewOptionsUseDefaults)
        }
    }

    // MARK: Slider Steps

    /// **Both steps are chosen so the shipped default lands *on* a tick**, which
    /// is the one constraint that is not cosmetic: `Use Defaults` moves the
    /// thumb, and a thumb resting between two tick marks reads as a control that
    /// failed to snap rather than as a deliberate value.
    ///
    /// 80…240 by 20 gives nine ticks with 120 on the fifth; 4…40 by 4 gives ten
    /// with 16 on the fourth. Finder's own sliders snap, so this matches the
    /// reference in behaviour as well as in appearance.
    ///
    /// **Accepted consequence, named because it is invisible until it happens:**
    /// a value stored before this shipped may sit off-tick (the range was
    /// continuous). It stays exactly as stored — the clamp does not round — and
    /// snaps on the first drag. Rounding stored preferences on read to make a
    /// control look tidy would be the control editing the model.
    private static let iconSizeStep: CGFloat = 20
    private static let spacingStep: CGFloat = 4

    /// Finder's View Options slider: the value in the label, and the same idea
    /// drawn small and large at the two ends.
    ///
    /// **The flanking glyphs are the affordance, not decoration.** A bare slider
    /// says a number is changing and not which direction makes it bigger, and
    /// these two panels control geometry that has no natural "more is up".
    /// Drawn from the two `.font(.system(size:))` values rather than
    /// `.imageScale`, which offers three steps and no control over the ratio —
    /// and the ratio is the whole signal.
    ///
    /// **Icon size shows a value and grid spacing does not**, matching Finder.
    /// The asymmetry is the reference's and it is defensible: a card size is a
    /// thing you might want to reproduce or describe, where a gutter is judged
    /// entirely by eye.
    ///
    /// **`pt`, not `128×128`.** Finder can write a square because its icons are
    /// square; `iconSize` here is a card's **width**, and the height follows the
    /// name label, which wraps to three lines. Writing `120×120` would invent a
    /// dimension the layout does not have — the one place this deliberately
    /// departs from the reference.
    @ViewBuilder
    private func sizedSlider(
        title: String,
        value: String?,
        binding: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        step: CGFloat,
        minimumGlyph: String,
        minimumSize: CGFloat,
        maximumGlyph: String,
        maximumSize: CGFloat,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("\(title):")
                if let value {
                    // `monospacedDigit` so the row does not twitch as the
                    // number crosses a digit boundary mid-drag — the label sits
                    // above a slider whose thumb is under the pointer, and a
                    // width that changes while you drag reads as a glitch.
                    Text(value)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: minimumGlyph)
                    .font(.system(size: minimumSize))
                // `step:` is what draws the tick marks on macOS; there is no
                // separate tick API on SwiftUI's `Slider`. So the ticks and the
                // snapping are one decision, which is why the step constants
                // carry the argument rather than this call site.
                Slider(value: binding, in: range, step: step)
                    .accessibilityIdentifier(identifier)
                    // The visible label is the `Text` above, which VoiceOver
                    // would not associate with this control on its own.
                    .accessibilityLabel(title)
                Image(systemName: maximumGlyph)
                    .font(.system(size: maximumSize))
            }
            // Both glyphs together, so a host that tints one tints both — they
            // are a matched pair and a divergence would read as one of them
            // being enabled.
            .foregroundStyle(.secondary)
            // The tallest glyph sets the row height; without this the two rows
            // sit at different heights purely because their `maximumSize`
            // values differ, which reads as misalignment rather than as scale.
            .frame(minHeight: 24)
        }
        .padding(.vertical, 2)
    }
}

/// The View menu's half of ⌘J.
///
/// **A `Commands` scene has no `openWindow`** any more than it has a
/// `modelContext` — `DiagnosticsCommands` records the latter and `D53′` the
/// former. The item therefore lives here and calls the environment action from
/// a plain `Button`, which *is* available to a command's content because the
/// menu is built inside the scene's environment.
///
/// Disabled when no collection destination is in front, and the condition is
/// producible both ways: a Board tab publishes no subject, a Library or
/// Players tab publishes one. The D40′ check applied at minting rather than at
/// the next sweep.
internal struct CollectionViewOptionsCommands: Commands {

    @FocusedValue(\.collectionViewOptionsSubject) private var subject

    internal var body: some Commands {
        CommandGroup(after: .toolbar) {
            ShowViewOptionsButton()
                .disabled(subject == nil)
        }
    }
}

/// The button both the menu and the grids' background context menus use.
///
/// Extracted because there are five call sites — the View menu plus four grid
/// backgrounds — and the first version of this had the label spelled twice
/// with two different capitalizations. `GameActionsMenu`'s argument at a
/// smaller scale: the item's *wording* is what must not fork, because a menu
/// and a keyboard shortcut naming the same verb differently is two features as
/// far as the reader is concerned.
internal struct ShowViewOptionsButton: View {

    @Environment(\.openWindow) private var openWindow

    internal var body: some View {
        Button("Show View Options") {
            openWindow(id: CollectionViewOptionsWindow.sceneID)
        }
        .keyboardShortcut("j", modifiers: .command)
        .accessibilityIdentifier(AccessibilityID.showViewOptions)
    }
}

// MARK: Previews

/// The full panel: sort, plus the grid section at its shipped defaults. This is
/// the standing witness for the slider row — the flanking glyphs' size ratio and
/// the tick spacing are visual claims that neither the compiler nor a unit test
/// can see.
///
/// **All three previews below passed `activeSubject == nil` until 7 Aug 2026**
/// and therefore rendered the empty arm, including this one; see
/// `PreviewFixtures.viewOptions(subject:iconSize:spacing:)`.
#Preview("Library — Icons") {
    CollectionViewOptionsWindow()
        .environment(
            PreviewFixtures.viewOptions(
                subject: CollectionViewOptionsSubject(collection: .library, mode: .icons)
            )
        )
        .frame(width: 360, height: 420)
}

/// **Both sliders at an extreme**, which is the arity no fixture reaches by
/// accident: `240 pt` is three digits where the default is two, and the label
/// sits directly above a thumb the pointer is holding. If the row shifts as the
/// number widens, `monospacedDigit` came off. Also the only canvas showing both
/// thumbs hard against the maximum glyph, which is where a spacing mistake in
/// the `HStack` shows.
#Preview("Library — Icons, Extremes") {
    CollectionViewOptionsWindow()
        .environment(
            PreviewFixtures.viewOptions(
                subject: CollectionViewOptionsSubject(collection: .library, mode: .icons),
                iconSize: CollectionViewOptions.iconSizeRange.upperBound,
                spacing: CollectionViewOptions.spacingRange.upperBound
            )
        )
        .frame(width: 360, height: 420)
}

/// The Players sort field list, which is a different enum with ten cases where
/// the Library's has nine — the branch that would catch a picker bound to the
/// wrong destination's options.
#Preview("Players — Icons") {
    CollectionViewOptionsWindow()
        .environment(
            PreviewFixtures.viewOptions(
                subject: CollectionViewOptionsSubject(collection: .players, mode: .icons)
            )
        )
        .frame(width: 360, height: 420)
}

/// The gallery arm: no grid section, and the sentence saying why rather than a
/// silently shorter panel.
#Preview("Library — Gallery") {
    CollectionViewOptionsWindow()
        .environment(
            PreviewFixtures.viewOptions(
                subject: CollectionViewOptionsSubject(collection: .library, mode: .gallery)
            )
        )
        .frame(width: 360, height: 420)
}

/// The unlatched state — a restored panel with nothing in front. The branch a
/// reader hits by accident, and now the only preview that renders it.
#Preview("No Subject") {
    CollectionViewOptionsWindow()
        .environment(PreviewFixtures.viewOptions())
        .frame(width: 360, height: 420)
}
