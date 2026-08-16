import SwiftUI

/// Which collection surface the panel is describing - both halves, because the destination
/// decides which sort fields exist and the mode whether the grid section renders.
struct CollectionViewOptionsSubject: Equatable, Sendable {

    enum Collection: String, Sendable {
        case library
        case players

        var displayName: String {
            switch self {
            case .library: "Library"
            case .players: "Players"
            }
        }
    }

    var collection: Collection
    var mode: CollectionViewMode

    /// Only the icons grid packs columns; list and columns are tables, the gallery is a strip.
    var hasSizableGrid: Bool { mode == .icons }
}

private struct CollectionViewOptionsSubjectKey: FocusedValueKey {
    typealias Value = CollectionViewOptionsSubject
}

extension FocusedValues {
    /// Published by both collection destinations, read by the panel and the View menu item.
    /// `focusedSceneValue` resolves per window, so the panel follows the front browser.
    var collectionViewOptionsSubject: CollectionViewOptionsSubject? {
        get { self[CollectionViewOptionsSubjectKey.self] }
        set { self[CollectionViewOptionsSubjectKey.self] = newValue }
    }
}

/// Finder's ⌘J. A singleton `Window` - one panel, opened by id, no wrapper type to mint.
/// One panel, not one per destination: sizes are preferences about browsing, not destinations.
struct CollectionViewOptionsWindow: View {

    static let sceneID = "collectionViewOptions"

    @Environment(CollectionViewOptions.self) private var options

    /// A pure reader - no `@FocusedValue` here, and that is the fix: opening the panel makes it key,
    /// so by first render the focused value is already nil. The destinations latch into `options`.
    private var subject: CollectionViewOptionsSubject? { options.activeSubject }

    var body: some View {
        @Bindable var options = options

        Group {
            if let subject {
                Form {
                    sortSection(for: subject, options: $options)
                    if subject.hasSizableGrid {
                        gridSection(for: subject.collection, options: $options)
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
                // Reachable on a cold restore with no collection ever in front. Named rather than left as an
                // empty `Form`, which reads as a broken window.
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

    /// Two branches, deliberately: the destinations' field enums are different types, and a generic
    /// picker buys nothing over two short switches.
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

    /// Words, not an arrow glyph: "descending" reads correctly for dates, counts, ratings and names;
    /// ↑ beside "Last Played" says nothing about which end is recent.
    private func directionPicker(isReverse: Binding<Bool>) -> some View {
        Picker("Order", selection: isReverse) {
            Text("Ascending").tag(false)
            Text("Descending").tag(true)
        }
        .pickerStyle(.inline)
        .accessibilityIdentifier(AccessibilityID.viewOptionsSortDirection)
    }

    private func gridSection(
        for collection: CollectionViewOptionsSubject.Collection,
        options: Bindable<CollectionViewOptions>
    ) -> some View {
        // The size slider wears the subject's own silhouette (16 Aug 2026, by request): a document
        // sheet meant nothing on Players, whose cards are person monograms. Spacing keeps the grid
        // glyphs on both - a grid is a grid whatever fills it.
        let sizeGlyph = collection == .players ? "person" : "doc"

        return Section("Grid") {
            // `in:` takes the ranges the type clamps to, so the slider cannot ask for a value the object
            // silently corrects - extremes that do nothing read as a stuck slider.
            sizedSlider(
                title: "Icon size",
                value: "\(Int(options.wrappedValue.iconSize)) pt",
                binding: options.iconSize,
                range: CollectionViewOptions.iconSizeRange,
                step: Self.iconSizeStep,
                minimumGlyph: sizeGlyph,
                minimumSize: 11,
                maximumGlyph: sizeGlyph,
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

    /// Both steps chosen so the shipped default lands **on** a tick - `Use Defaults` moves the
    /// thumb, and a thumb between ticks reads as a failed snap.
    private static let iconSizeStep: CGFloat = 20
    private static let spacingStep: CGFloat = 4

    /// The label cluster's fixed slot, so the two sliders' tracks start at one x whatever the
    /// title says - two rows with hugging labels are two sliders that never align (the tag
    /// editor's 16 Aug lesson, one window over). Wide enough for "Icon size: 240 pt".
    private static let labelColumnWidth: CGFloat = 118

    /// Finder's View Options slider on one line (label above until 16 Aug 2026, by request):
    /// value in the label, small/large glyphs at the ends - the affordance, not decoration.
    /// Icon size shows a value, grid spacing does not (Finder's split); `pt`, not `128×128` -
    /// the layout has no square to promise.
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
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Text("\(title):")
                if let value {
                    // `monospacedDigit` so the row does not twitch as the number crosses a digit boundary mid-drag.
                    Text(value)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: Self.labelColumnWidth, alignment: .leading)

            HStack(spacing: 10) {
                Image(systemName: minimumGlyph)
                    .font(.system(size: minimumSize))
                // `step:` draws the tick marks - ticks and snapping are one decision, so the step constants
                // carry the argument.
                Slider(value: binding, in: range, step: step)
                    .accessibilityIdentifier(identifier)
                    // VoiceOver would not associate the visible `Text` label on its own.
                    .accessibilityLabel(title)
                Image(systemName: maximumGlyph)
                    .font(.system(size: maximumSize))
            }
            // Both glyphs together, so a host tinting one tints both - a divergence reads as one enabled.
            .foregroundStyle(.secondary)
            // The tallest glyph sets the row height; otherwise rows sit at different heights per `maximumSize`.
            .frame(minHeight: 24)
        }
        .padding(.vertical, 2)
    }
}

/// The View menu's half of ⌘J - a `Commands` scene has no `openWindow`, so the shared button
/// carries the action and this scene just hosts it.
struct CollectionViewOptionsCommands: Commands {

    @FocusedValue(\.collectionViewOptionsSubject) private var subject

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            // ⌘J applied here and nowhere else: the shortcut lived on the shared button with five hosts, so
            // icons mode registered ⌘J twice - live and ambiguous, the exact class flagged for ⌘R/⌘E.
            ShowViewOptionsButton()
                .keyboardShortcut("j", modifiers: .command)
                .disabled(subject == nil)
        }
    }
}

/// The shared button for the menu and the four grid backgrounds - the *wording* must not fork.
/// Carries label and action, deliberately not the shortcut: a key equivalent is a claim to own
/// the verb globally, and only the menu may make it.
struct ShowViewOptionsButton: View {

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Show View Options") {
            openWindow(id: CollectionViewOptionsWindow.sceneID)
        }
        .accessibilityIdentifier(AccessibilityID.showViewOptions)
    }
}

// MARK: Previews

/// The standing witness for the slider row - glyph ratio and tick spacing are visual claims no
/// compiler or unit test can see.
#Preview("Library - Icons") {
    CollectionViewOptionsWindow()
        .environment(
            PreviewFixtures.viewOptions(
                subject: CollectionViewOptionsSubject(collection: .library, mode: .icons)
            )
        )
        .frame(width: 360, height: 420)
}

/// Both sliders at an extreme: three digits over a held thumb - if the row shifts as the number
/// widens, `monospacedDigit` came off. Also both thumbs against the maximum glyph.
#Preview("Library - Icons, Extremes") {
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

/// Players' field list - ten cases to the Library's nine; catches a picker bound to the wrong
/// destination's options. Also the person glyphs on the size slider (the Library keeps the doc).
#Preview("Players - Icons") {
    CollectionViewOptionsWindow()
        .environment(
            PreviewFixtures.viewOptions(
                subject: CollectionViewOptionsSubject(collection: .players, mode: .icons)
            )
        )
        .frame(width: 360, height: 420)
}

/// The gallery arm: no grid section, with the sentence saying why.
#Preview("Library - Gallery") {
    CollectionViewOptionsWindow()
        .environment(
            PreviewFixtures.viewOptions(
                subject: CollectionViewOptionsSubject(collection: .library, mode: .gallery)
            )
        )
        .frame(width: 360, height: 420)
}

/// The unlatched state - a restored panel with nothing in front.
#Preview("No Subject") {
    CollectionViewOptionsWindow()
        .environment(PreviewFixtures.viewOptions())
        .frame(width: 360, height: 420)
}
