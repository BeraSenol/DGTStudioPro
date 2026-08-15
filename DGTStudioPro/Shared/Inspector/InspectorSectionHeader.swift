import SwiftUI

/// A section header naming the thing the section is about, action trailing.
/// `title` is a `String`, not `LocalizedStringKey` — titles are data (a player's name is not
/// copy to localize). One line, truncating.
struct InspectorSectionHeader<Actions: View>: View {
    
    // MARK: Type Properties
    
    /// Trailing inset for the whole actions row. Owned here so a host cannot get it wrong whatever
    /// it passes into the slot — as a padding on the pencil it insetted the edge AND widened the hit
    /// target, which coincide only while the pencil is last (three distances from one edge resulted).
    /// Computed, not stored: generic types cannot have stored static properties.
    static var actionsInset: CGFloat { 12 }
    
    // MARK: Stored Properties
    let title: String
    
    /// The section's identity, or nil for a non-collapsing header. Optional so a plain header does
    /// not have to mint an `InspectorSection` case to render.
    let section: InspectorSection?
    
    @ViewBuilder let actions: () -> Actions
    
    @Environment(InspectorSectionCollapse.self) private var collapse
    
    // MARK: Initializers
    init(
        _ title: String,
        section: InspectorSection? = nil,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title = title
        self.section = section
        self.actions = actions
    }
    
    // MARK: Body
    var body: some View {
        HStack(spacing: 0) {
            Text(title)
            // A `List` section header uppercases by default on some styles; a name is not to be shouted.
                .textCase(nil)
                .lineLimit(1)
            Spacer(minLength: 8)
            // Chevron **trailing** the actions (reversed 2 Aug 2026): the disclosure sits at one fixed
            // distance from the edge whatever the arity, one column down the inspector. Price: action
            // glyphs are no longer rightmost — the original argument, consciously given up.
            HStack(spacing: 12) {
                actions()
                if let section {
                    disclosure(for: section)
                }
            }
        }
        .padding(.trailing, Self.actionsInset)
    }
    
    // MARK: Instance Methods
    
    /// One chevron rotated, not two symbols swapped — a continuous motion the eye tracks.
    private func disclosure(for section: InspectorSection) -> some View {
        let isCollapsed = collapse.isCollapsed(section)
        // Annotated `String` on purpose — the inverse of `InspectorEditButtonView`'s
        // `LocalizedStringKey` label: that carries copy, this interpolates a title that is data.
        let label: String = isCollapsed ? "Show \(title)" : "Hide \(title)"
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                collapse.toggle(section)
            }
        } label: {
            Image(systemName: "chevron.right")
                .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        // A glyph at header font size is an ~11 pt mouse target.
        .font(.body)
        .help(label)
        .accessibilityLabel(label)
        // The registry takes the raw value (String-only rule); this is the only caller and it
        // holds the real type.
        .accessibilityIdentifier(AccessibilityID.inspectorSectionDisclosure(section.rawValue))
    }
}

// MARK: Convenience

extension InspectorSectionHeader where Actions == EmptyView {
    
    /// A header with nothing to act on. It may still collapse — a chevron is not an action on the
    /// section's subject.
    init(_ title: String, section: InspectorSection? = nil) {
        self.init(title, section: section, actions: { EmptyView() })
    }
}

// MARK: Previews

/// Four headers stacked, with and without actions: the claim is equal height and baseline, and
/// a name long enough to truncate is the case that breaks it.
#Preview("Every Inspector Header") {
    List {
        Section {
            Text("Event, Site, Date, Round, White, Black, Result")
                .foregroundStyle(.secondary)
        } header: {
            InspectorSectionHeader("Bera Senol vs Lorenzo Baelus") {
                InspectorEditButtonView(
                    label: "Rename",
                    identifier: AccessibilityID.libraryInspectorRename,
                    action: {}
                )
            }
        }
        Section {
            Text("The Board inspector's headline, long enough to truncate")
                .foregroundStyle(.secondary)
        } header: {
            InspectorSectionHeader(
                "Reviewing 7. Magnus Carlsen vs Ian Nepomniachtchi"
            ) {
                InspectorEditButtonView(
                    // The app's one surviving `InspectorEditButtonView` (live inspector's Edit Details).
                    label: "Edit Details",
                    identifier: AccessibilityID.liveInspectorEditDetails,
                    action: {}
                )
            }
        }
        Section {
            Text("Games, Win Rate, Mates Delivered…")
                .foregroundStyle(.secondary)
        } header: {
            InspectorSectionHeader("Bera Senol")
        }
        Section {
            Text("Rank, Wins, Record, Rating…")
                .foregroundStyle(.secondary)
        } header: {
            InspectorSectionHeader("Christos Dermentzoglou")
        }
    }
    .listStyle(.sidebar)
    .frame(width: 300, height: 420)
    .environment(InspectorSectionCollapse.preview)
}

/// Every arity the app passes, stacked so trailing edges read against each other — the standing
/// witness for `actionsInset`. Look for a vertical line, not a row.
#Preview("Actions, Every Arity") {
    List {
        Section {
            Text("One control, four inspectors' pencils.")
                .foregroundStyle(.secondary)
        } header: {
            InspectorSectionHeader("Lone Pencil") {
                InspectorEditButtonView(
                    // The app's one surviving `InspectorEditButtonView`.
                    label: "Edit Details",
                    identifier: AccessibilityID.liveInspectorEditDetails,
                    action: {}
                )
            }
        }
        Section {
            Text("Chevron, pencil, glyph, the Library's PGN header.")
                .foregroundStyle(.secondary)
        } header: {
            // The one multi-control header. Pencil leads: the edit verb is the section's verb, Copy a
            // convenience on what it shows.
            InspectorSectionHeader("Pencil and Glyph", section: .pgn) {
                InspectorEditButtonView(
                    label: "Edit Details",
                    identifier: AccessibilityID.liveInspectorEditDetails,
                    action: {}
                )
                Button { } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless)
                    .font(.body)
            }
        }
        Section {
            Text("No actions, Opening, Evaluation, Moves, Recent Games…")
                .foregroundStyle(.secondary)
        } header: {
            InspectorSectionHeader("Nothing To Act On")
        }
        Section {
            Text("A chevron and nothing else.")
                .foregroundStyle(.secondary)
        } header: {
            // The arity to look hardest at — the one claim written from reasoning, not a compiler: with
            // no actions the `EmptyView` should flatten out of the builder and contribute no spacing.
            InspectorSectionHeader("Collapsible, No Actions", section: .recentGames)
        }
    }
    .listStyle(.sidebar)
    .frame(width: 300, height: 540)
    .environment(InspectorSectionCollapse.preview)
}
