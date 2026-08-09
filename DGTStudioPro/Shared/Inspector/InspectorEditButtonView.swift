import SwiftUI

/// The pencil that edits what a section header names (D26′). Hardcodes the pencil so edit
/// affordances cannot drift; one `label` feeds both `.help` and `.accessibilityLabel` so
/// tooltip and spoken label cannot disagree. One production consumer since D57′ (the live
/// inspector's Edit Details) — not dead, but "shared" is starting to describe history.
internal struct InspectorEditButtonView: View {
    
    // MARK: Stored Properties
    internal let label: LocalizedStringKey
    internal let identifier: String
    internal let action: () -> Void
    
    // MARK: Body
    internal var body: some View {
        Button(action: action) {
            Image(systemName: "pencil")
                // The label's frame is the hit area under `.borderless`, and an SF Symbol's frame is mostly
                // transparent — `.contentShape` makes the whole box clickable.
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        // Stated, not inherited: a header's small secondary font makes an ~11 pt mouse target.
        // `.font(.body)` is the only thing sizing it.
        .font(.body)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: Previews

/// In the surface it exists for, headline long enough to truncate — the pencil stays pinned
/// trailing, the header one line tall.
#Preview("In a Section Header") {
    List {
        SevenTagRosterSection(
            roster: RosterSummary(
                event: "World Championship",
                site: "Dubai",
                date: Date(timeIntervalSince1970: 1_720_000_000),
                round: 7,
                white: "Carlsen, Magnus",
                black: "Nepomniachtchi, Ian",
                result: .ongoing
            ),
            headline: "Reviewing 7. Magnus Carlsen vs Ian Nepomniachtchi"
        ) {
            InspectorEditButtonView(
                // **Edit Details is the app's only pencil** — repointed as the others went (D57′, D59′).
                label: "Edit Details",
                identifier: AccessibilityID.liveInspectorEditDetails,
                action: {}
            )
        }
    }
    .listStyle(.sidebar)
    .frame(width: 300, height: 320)
    .environment(InspectorSectionCollapse.preview)
}

/// The narrowest drag, with and without an action — where a shift in header height shows.
#Preview("Narrow, With and Without") {
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
        SevenTagRosterSection(roster: nil, headline: "Game Details")
    }
    .listStyle(.sidebar)
    .frame(width: 260, height: 560)
    .environment(InspectorSectionCollapse.preview)
}
