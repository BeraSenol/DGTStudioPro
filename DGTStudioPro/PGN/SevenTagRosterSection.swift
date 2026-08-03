//
//  SevenTagRosterSection.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 23/07/2026.
//

import SwiftUI

/// The Seven Tag Roster as one sidebar section (D22′): a headline carrying
/// whatever action the host offers on it, then the seven tags in the
/// standard's order. Shared by all three inspectors that show a game's
/// metadata — the Board's review inspector, the live inspector, and the
/// Library inspector.
///
/// Rows are driven by `SevenTagRoster.allCases`, so a host cannot render six
/// tags or invent an order. The labels are the PGN tag names verbatim and are
/// deliberately not localized: they're the standard's identifiers, the same
/// strings that appear in the file the user exports.
///
/// The action renders **in the header**, trailing, not as a row beneath the
/// tags: the rows are a fixed set of seven, so an eighth that is a verb reads
/// as part of the roster, and the bottom of the section is the wrong end from
/// the heading the action acts on. `InspectorEditButtonView` is the shape every
/// host passes.
///
/// The slot stays a `@ViewBuilder` rather than an `onEdit` closure so each
/// host keeps its own accessibility identifier and wording — the live
/// inspector's Edit Details is `live.inspector.editdetails`, the review
/// side's Edit Info is `board.editInfo`, not one entry pretending two buttons
/// in two inspectors are the same button. A host with nothing to offer passes
/// nothing and the header is a plain heading again.
///
/// The header itself is `InspectorSectionHeader` — shared with the Players
/// inspector (and with Rankings' until D48′ merged it away), which has the
/// same header and no roster, so the shape could not stay in here once
/// another family wanted it.
internal struct SevenTagRosterSection<Actions: View>: View {
    
    // MARK: Static Constants
    
    /// No game at all — distinct from `RosterSummary.unknownTag`'s "this
    /// game doesn't say". Preserves the Board inspector's existing empty
    /// state exactly.
    private static var noGamePlaceholder: String { "—" }
    
    // MARK: Stored Properties
    
    internal let roster: RosterSummary?
    internal let headline: String
    @ViewBuilder internal let actions: () -> Actions
    
    // MARK: Body
    
    /// Collapses as `.roster` (D45′) — one identity across all three hosts,
    /// because it is one section shown three times rather than three sections
    /// that resemble each other. Folding the roster on the Board folds it in
    /// the Library, which is the reading `InspectorSection` takes throughout.
    internal var body: some View {
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
    internal init(roster: RosterSummary?, headline: String) {
        self.init(roster: roster, headline: headline, actions: { EmptyView() })
    }
}

// MARK: Previews

/// Tag form in, display form out: `white` is supplied as PGN carries it
/// ("Senol, Bera") and the row shows "Bera Senol". That boundary is
/// `subscript(_:)`'s job (D23′), and this is the only place it's visible.
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

/// D22′'s first placeholder: `?`, and `????.??.??` for the date, meaning
/// *this game doesn't say*. All seven rows still render — the roster is a
/// fixed set, so an unset tag prints PGN's own unknown vocabulary rather
/// than dropping the line, the same rule D24′ export follows.
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

/// D22′'s *second* placeholder, and the reason there are two: an em dash
/// means *there is no game to ask*. Worth opening beside "Unknown Tags" —
/// the absent/corrupt distinction is the whole decision, and it exists
/// nowhere but on screen.
#Preview("No Game") {
    List {
        SevenTagRosterSection(roster: nil, headline: "Game")
    }
    .listStyle(.sidebar)
    .frame(width: 340, height: 300)
    .environment(InspectorSectionCollapse.preview)
}

/// The `@ViewBuilder` action slot — the reason this type is generic rather
/// than taking an `onEdit` closure: each host brings its own title and
/// registry identifier instead of two buttons pretending to be one.
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
