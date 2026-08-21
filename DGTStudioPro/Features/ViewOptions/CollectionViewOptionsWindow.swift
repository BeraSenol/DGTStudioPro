import SwiftUI

/// Which collection surface the panel is describing - both halves, because the destination
/// decides which sort fields exist and the mode whether the grid section renders.
struct CollectionViewOptionsSubject: Equatable, Sendable {
    
    enum Collection: String, Sendable {
        case library
        case players
        
        /// `rawValue.capitalized`, matching `Destination.displayName` (21 Aug 2026). The
        /// hand-written switch returned the same two strings the raw values already capitalise
        /// to - two derivations for one answer, on two enums that are parallel by construction.
        var displayName: String {
            rawValue.capitalized
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

        // Since the geometry became per-destination the panel binds the *subject's* pair, not a
        // shared one. Resolved to real bindings by a switch rather than built from get/set
        // closures, so the sliders stay one copy of the markup and keep the property setters'
        // clamp. `Use Defaults` restores this collection only - the other surface is not the
        // reader's subject and must not move under them.
        let size = iconSizeBinding(collection, options)
        let gap = spacingBinding(collection, options)

        return Section("Grid") {
            // `in:` takes the ranges the type clamps to, so the slider cannot ask for a value the object
            // silently corrects - extremes that do nothing read as a stuck slider.
            sizedSlider(
                title: "Icon size",
                value: "\(Int(size.wrappedValue)) pt",
                binding: size,
                range: CollectionViewOptions.iconSizeRange,
                step: Self.iconSizeStep,
                minimumGlyph: sizeGlyph,
                minimumSize: 10,
                maximumGlyph: sizeGlyph,
                maximumSize: 16,
                identifier: AccessibilityID.viewOptionsIconSize
            )
            sizedSlider(
                title: "Grid spacing",
                value: nil,
                binding: gap,
                range: CollectionViewOptions.spacingRange,
                step: Self.spacingStep,
                minimumGlyph: "square.grid.2x2.fill",
                minimumSize: 10,
                maximumGlyph: "square.grid.3x3.fill",
                maximumSize: 16,
                identifier: AccessibilityID.viewOptionsSpacing
            )
            Button("Use Defaults") {
                size.wrappedValue = CollectionViewOptions.defaultIconSize
                gap.wrappedValue = CollectionViewOptions.defaultSpacing
            }
            .accessibilityIdentifier(AccessibilityID.viewOptionsUseDefaults)
        }
    }

    /// The subject's own geometry bindings. Two short switches for the reason `sortSection` gives
    /// for its two: the alternative is a keyed subscript, and `@Bindable` projects bindings through
    /// key paths, not through subscripts of our own.
    private func iconSizeBinding(
        _ collection: CollectionViewOptionsSubject.Collection,
        _ options: Bindable<CollectionViewOptions>
    ) -> Binding<CGFloat> {
        switch collection {
        case .library: options.libraryIconSize
        case .players: options.playersIconSize
        }
    }

    private func spacingBinding(
        _ collection: CollectionViewOptionsSubject.Collection,
        _ options: Bindable<CollectionViewOptions>
    ) -> Binding<CGFloat> {
        switch collection {
        case .library: options.librarySpacing
        case .players: options.playersSpacing
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
        HStack {
            HStack {
                Text("\(title):")
                if let value {
                    // `monospacedDigit` so the row does not twitch as the number crosses a digit boundary mid-drag.
                    Text(value)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: Self.labelColumnWidth, alignment: .leading)
            
            // The glyphs ride the slider's OWN value-label slots (17 Aug 2026), not a
            // hand-built `HStack { Image; Slider; Image }`. That version left a wide gap
            // between the minimum glyph and the track which survived making both the slider
            // and its column greedy - three siblings in an HStack have no rule about who hugs
            // whom, and inside a grouped `Form` the leftover width settled between them. These
            // slots are the API's answer: AppKit hugs them to the track's ends and owns the
            // spacing.
            // `step:` draws the tick marks - ticks and snapping are one decision, so the step
            // constants carry the argument.
            Slider(value: binding, in: range, step: step) {
                // Hidden below but present: VoiceOver would not associate the row's visible
                // `Text` label on its own.
                Text(title)
            } minimumValueLabel: {
                Image(systemName: minimumGlyph)
                    .font(.system(size: minimumSize))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 6)
            } maximumValueLabel: {
                Image(systemName: maximumGlyph)
                    .font(.system(size: maximumSize))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
            }
            // The row draws its own label column, so the slider's built-in one would be a
            // second copy of the same words. Both glyphs are styled from this one helper, so
            // they still cannot diverge - the tint that used to sit on their shared HStack.
            .labelsHidden()
            .accessibilityIdentifier(identifier)
            .accessibilityLabel(title)
            // The tallest glyph sets the row height; otherwise rows sit at different heights per `maximumSize`.
            .frame(maxWidth: .infinity, minHeight: 24)
        }
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
