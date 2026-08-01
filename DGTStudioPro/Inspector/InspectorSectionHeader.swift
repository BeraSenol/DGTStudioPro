//
//  InspectorSectionHeader.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 27/07/2026.
//

import SwiftUI

/// A sidebar section header that names the thing the section is about, with
/// the action on that thing trailing it.
///
/// Extracted from `SevenTagRosterSection` the moment a second family of
/// inspectors wanted the same header: Library's roster header is the game's
/// name, Players' is the player's, Rankings' is the ranked player's. Left
/// inline it would have been copied three times, and the copies would agree
/// only while someone remembered — `InspectorEmptyState`'s argument (D26′)
/// one layer up.
///
/// `title` is a `String`, not a `LocalizedStringKey`, and that is the whole
/// point of the type: these headers carry *data* — a game's name, a player's
/// name, a formatted headline — not copy. A `LocalizedStringKey` would send a
/// player's name through the strings table looking for a translation.
///
/// One line, truncating: a header with a control pinned beside it must have a
/// settled height, and every title here is either a name that also appears in
/// the rows below or a headline whose parts do (White and Black). Truncation
/// costs nothing that isn't a glance away.
///
/// The action is a `@ViewBuilder` slot rather than an `onEdit` closure so each
/// host keeps its own identifier, wording and action — `InspectorEditButtonView`
/// is what every host currently passes, and a host with nothing to offer
/// passes nothing and gets a plain heading.
internal struct InspectorSectionHeader<Actions: View>: View {

    // MARK: Type Properties

    /// How far the header's trailing edge sits from the inspector's, and so
    /// how far the outermost control sits from it.
    ///
    /// It used to live on `InspectorEditButtonView` as `.padding(.trailing, 10)`
    /// under a doc comment reading "stated here and nowhere else" — true of the
    /// *number* and false of the *job*. That padding did two things at once:
    /// inset the header's trailing control, and widen the pencil's hit target.
    /// Those coincide only while the pencil is last, and M5's Players header put
    /// a menu after it, at which point the edge inset silently transferred to a
    /// control carrying none. Three distances from one edge resulted — 10 pt at
    /// the four lone pencils, 8 pt at the Library's PGN glyph pair (which had
    /// quietly added its own), and 0 pt at the actions menu.
    ///
    /// Owning it here is what makes a host unable to get it wrong: whatever goes
    /// into the actions slot, and however much of it, the outermost control is
    /// this far from the edge. `InspectorEditButtonView` keeps the hit target,
    /// which was the half that genuinely belonged to it.
    ///
    /// Stated trade-off: it is applied to the whole row, not to `actions()`, so
    /// a header with *no* actions also gives up these 10 pt — a title long
    /// enough to truncate now truncates 10 pt earlier. Taken deliberately over
    /// insetting the slot alone, and the distinction is worth being precise
    /// about because the trailing cluster below relies on its other half: a
    /// **bare** `EmptyView` is flattened out of a `ViewBuilder` list and lays
    /// nothing out, but an `EmptyView` **under a modifier** is a
    /// `ModifiedContent` — a different type, and no longer the one SwiftUI
    /// special-cases. So `actions().padding(…)` is a claim about layout nobody
    /// here has checked, while `HStack(spacing: 12) { chevron; actions() }`
    /// rests only on the flattening. One unconditional statement beats ten
    /// points of a name nobody reads to the end.
    ///
    /// Computed, not stored, because this type is generic and **generic types
    /// cannot have stored static properties**. `SevenTagRosterSection` records
    /// the same constraint at `noGamePlaceholder`, for the same reason, in a
    /// file this milestone edited on its way here — so the lesson was one
    /// scroll away and got re-learned from the compiler anyway. It joins the
    /// standing roll of pre-recorded lessons re-learned in anger.
    internal static var actionsInset: CGFloat { 10 }

    // MARK: Stored Properties
    internal let title: String

    /// The section's stored identity, or `nil` for a header that does not
    /// collapse. Optional rather than required because "collapsible" is a
    /// property of the section, not of the header type — and because a
    /// required parameter would force every future header to mint an
    /// `InspectorSection` case before it could render at all.
    internal let section: InspectorSection?

    @ViewBuilder internal let actions: () -> Actions

    @Environment(InspectorSectionCollapse.self) private var collapse

    // MARK: Initializers
    internal init(
        _ title: String,
        section: InspectorSection? = nil,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title = title
        self.section = section
        self.actions = actions
    }

    // MARK: Body
    internal var body: some View {
        HStack(spacing: 0) {
            Text(title)
            // Stated because a `List` section header uppercases by
            // default on some styles, and a game or player name is not
            // a label to be shouted.
                .textCase(nil)
                .lineLimit(1)
            Spacer(minLength: 8)
            // The chevron sits **leading** of the actions, so the action glyph
            // stays rightmost — which is where the four lone pencils already
            // are, and what the Library's bespoke disclosure said it did.
            // It didn't: its doc read "Leading of the copy button, which keeps
            // the action glyph rightmost" while the `HStack` listed copy first
            // and the chevron second, putting the app's one disclosure in the
            // one slot every other inspector reserves for a verb. The order
            // here is that comment's intent, finally executed.
            HStack(spacing: 12) {
                if let section {
                    disclosure(for: section)
                }
                actions()
            }
        }
        .padding(.trailing, Self.actionsInset)
    }

    // MARK: Instance Methods

    /// One chevron rotated rather than two symbols swapped, so the state change
    /// is a continuous motion the eye tracks instead of a substitution it has
    /// to re-read. Inherited wholesale from the Library's PGN disclosure, which
    /// is the control this replaces.
    private func disclosure(for section: InspectorSection) -> some View {
        let isCollapsed = collapse.isCollapsed(section)
        // Annotated `String` on purpose, and it is the inverse of the choice
        // `InspectorEditButtonView` makes one file over. That type's `label`
        // is a `LocalizedStringKey` because it carries *copy* ("Edit Info"),
        // and a `String` there would silently pick the non-localizing
        // overloads. Here the label interpolates `title`, which is **data** —
        // a game's name, a player's name — so a `LocalizedStringKey` would
        // send "Hide Bera Senol vs Lorenzo Reinaud" to the strings table
        // looking for a translation. That is the exact trap this file's own
        // header doc names as the reason `title` is not a `LocalizedStringKey`,
        // and interpolating it into one would have re-opened it from the side.
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
        // `InspectorEditButtonView`'s reason: a glyph at header font size is
        // an ~11 pt mouse target.
        .font(.body)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityIdentifier(AccessibilityID.inspectorSectionDisclosure(section))
    }
}

// MARK: Convenience

extension InspectorSectionHeader where Actions == EmptyView {

    /// A header with nothing to act on — Players and Rankings today, and any
    /// section whose title is a label rather than a subject.
    ///
    /// It may still collapse: a chevron is not an action on the section's
    /// subject, it is an action on the section, which is why it lives in the
    /// header's own body rather than in the slot a host fills.
    internal init(_ title: String, section: InspectorSection? = nil) {
        self.init(title, section: section, actions: { EmptyView() })
    }
}

// MARK: Previews

/// All four inspectors' headers in one column, two with an action and two
/// without. The type's claim is that a header carrying a control and one not
/// carrying one are the same height and the same baseline; stacked is the
/// only way to see that, and a name long enough to truncate is the case that
/// breaks it.
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
                    label: "Edit Info",
                    identifier: AccessibilityID.boardEditInfoButton,
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

/// Every arity of the actions slot the app actually passes, stacked so their
/// trailing edges are readable against each other — one control, two glyphs,
/// a control plus a menu, and none.
///
/// This is the preview the type should have had. `actionsInset` is a claim
/// about *every* header's outermost control, and until now the only witness
/// was four headers all passing a lone pencil — the one arity where the old
/// arrangement happened to be right. The multi-control rows are the ones that
/// were wrong for a month: the Players shape put its menu flush against the
/// edge, and the Library shape sat two points inside everything else.
///
/// What to look at is a vertical line, not a row: if any one of the four
/// trailing controls is out of column with the others, the inset has escaped
/// its single statement again.
#Preview("Actions — Every Arity") {
    List {
        Section {
            Text("One control — four inspectors' pencils.")
                .foregroundStyle(.secondary)
        } header: {
            InspectorSectionHeader("Lone Pencil") {
                InspectorEditButtonView(
                    label: "Edit Info",
                    identifier: AccessibilityID.boardEditInfoButton,
                    action: {}
                )
            }
        }
        Section {
            Text("Chevron plus a glyph — the Library's PGN header, D45′ shape.")
                .foregroundStyle(.secondary)
        } header: {
            InspectorSectionHeader("Glyph Pair", section: .pgn) {
                Button { } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless)
                    .font(.body)
            }
        }
        Section {
            Text("Pencil plus menu — the Players profile header (M5).")
                .foregroundStyle(.secondary)
        } header: {
            InspectorSectionHeader("Pencil and Menu") {
                HStack(spacing: 12) {
                    InspectorEditButtonView(
                        label: "Rename Player",
                        identifier: AccessibilityID.playersRenameButton,
                        action: {}
                    )
                    Menu {
                        Button("Merge Into…") { }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    // `.menuIndicator(.hidden)` and `.fixedSize()` copied from
                    // `PlayersInspectorView.actionsMenu` deliberately: without
                    // them the menu reserves width for a disclosure arrow, and
                    // this preview would show the trailing control in a column
                    // the app never puts it in — a preview that agrees with
                    // itself and not with the screen.
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .font(.body)
                }
            }
        }
        Section {
            Text("No actions — Opening, Evaluation, Moves, Recent Games…")
                .foregroundStyle(.secondary)
        } header: {
            InspectorSectionHeader("Nothing To Act On")
        }
        Section {
            Text("A chevron and nothing else.")
                .foregroundStyle(.secondary)
        } header: {
            // The arity worth looking hardest at, and the one thing in D45′
            // written from reasoning rather than from a compiler. The trailing
            // cluster is `HStack(spacing: 12) { chevron; actions() }`, and with
            // no actions that slot resolves to `EmptyView` — which should
            // contribute no subview and therefore no 12 pt of spacing, because
            // spacing applies *between* subviews and there is only one.
            //
            // Should. This preview is where that stops being an argument: if
            // this chevron sits 12 pt inside the one above it, `EmptyView` is
            // being laid out and the gap needs to move onto the chevron under
            // a condition instead.
            InspectorSectionHeader("Collapsible, No Actions", section: .recentGames)
        }
    }
    .listStyle(.sidebar)
    .frame(width: 300, height: 540)
    .environment(InspectorSectionCollapse.preview)
}
