import SwiftUI

/// The Seven Tag Roster as one section, shared by all three inspectors. Rows driven by
/// `SevenTagRoster.allCases`, so a host cannot render six tags or invent an order; labels are
/// the standard's identifiers, unlocalized. The action renders in the header, trailing.
struct SevenTagRosterSection<Actions: View>: View {
    
    // MARK: Static Constants
    
    /// No game at all - distinct from "this game doesn't say". Preserves the Board's empty state.
    private static var noGamePlaceholder: String { RosterSummary.displayUnknown }
    
    // MARK: Stored Properties
    
    let roster: RosterSummary?
    let headline: String
    @ViewBuilder let actions: () -> Actions
    
    // MARK: Body
    
    /// Collapses as `.roster` - one section shown three times, not three that resemble each other.
    var body: some View {
        CollapsibleSection(.roster, title: headline) {
            ForEach(SevenTagRoster.allCases, id: \.self) { tag in
                LabeledContent(tag.rawValue, value: value(for: tag))
            }
        } actions: {
            actions()
        }
    }
    
    private func value(for tag: SevenTagRoster) -> String {
        roster?[tag] ?? Self.noGamePlaceholder
    }
}

// MARK: Convenience

extension SevenTagRosterSection where Actions == EmptyView {
    
    /// Rendered by all three inspectors that show a game's metadata: the Board's
    /// review inspector, the live inspector, and the Library inspector.
    init(roster: RosterSummary?, headline: String) {
        self.init(roster: roster, headline: headline, actions: { EmptyView() })
    }
}

// MARK: Previews

/// Tag form in, display form out - `subscript(_:)`'s boundary, visible only here.
#Preview("Full Roster") {
    List {
        SevenTagRosterSection(
            roster: RosterSummary(
                event: "Club Championship",
                site: "Antwerp",
                date: Date(timeIntervalSince1970: 1_720_000_000),
                round: 3,
                white: "Senol, Bera",
                black: "Reinaud, Lorenzo",
                result: .whiteWins
            ),
            headline: "Reviewing 3. Bera Senol vs Lorenzo Reinaud"
        )
    }
    .listStyle(.sidebar)
    .frame(width: 340, height: 300)
    .environment(InspectorSectionCollapse.preview)
}

/// Every unknown folds to the one placeholder glyph (one glyph for every unknown - the stored `?`s are PGN vocabulary, never
/// shown), and all seven rows still render: a fixed set never drops a line.
#Preview("Unknown Tags") {
    List {
        SevenTagRosterSection(
            roster: RosterSummary(
                event: "?",
                site: "?",
                date: nil,
                round: nil,
                white: "?",
                black: "?",
                result: .ongoing
            ),
            headline: "Recording"
        )
    }
    .listStyle(.sidebar)
    .frame(width: 340, height: 300)
    .environment(InspectorSectionCollapse.preview)
}

/// The nil-roster branch. Since the one-glyph collapse it renders identically to "Unknown Tags" - open them side
/// by side to see the *collapse*, which is the decision, not a defect. (This comment claimed the
/// two were distinguishable on screen until 16 Aug 2026; the collapse had ended that a week earlier.)
#Preview("No Game") {
    List {
        SevenTagRosterSection(roster: nil, headline: "Game")
    }
    .listStyle(.sidebar)
    .frame(width: 340, height: 300)
    .environment(InspectorSectionCollapse.preview)
}

/// The `@ViewBuilder` slot - why this type is generic: each host brings its own title and identifier.
#Preview("With Action") {
    List {
        SevenTagRosterSection(
            roster: RosterSummary(
                event: "Club Championship",
                site: "Antwerp",
                date: Date(timeIntervalSince1970: 1_720_000_000),
                round: 101,
                white: "Senol, Bera",
                black: "Reinaud, Lorenzo",
                result: .ongoing
            ),
            headline: "Recording 101. Bera Senol vs Lorenzo Reinaud"
        ) {
            InspectorEditButtonView(
                label: "Edit Details",
                identifier: AccessibilityID.liveInspectorEditDetails,
                action: {}
            )
        }
    }
    .listStyle(.sidebar)
    .frame(width: 340, height: 330)
    .environment(InspectorSectionCollapse.preview)
}
