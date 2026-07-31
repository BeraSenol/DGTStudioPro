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
    
    // MARK: Stored Properties
    internal let title: String
    @ViewBuilder internal let actions: () -> Actions
    
    // MARK: Initializers
    internal init(_ title: String, @ViewBuilder actions: @escaping () -> Actions) {
        self.title = title
        self.actions = actions
    }
    
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
    /// insetting the slot alone, because an `EmptyView` under a modifier is not
    /// reliably absent from layout, and one unconditional statement is worth
    /// more here than ten points of a name nobody reads to the end.
    internal static let actionsInset: CGFloat = 10

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
            actions()
        }
        .padding(.trailing, Self.actionsInset)
    }
}

// MARK: Convenience

extension InspectorSectionHeader where Actions == EmptyView {
    
    /// A header with nothing to act on — Players and Rankings today, and any
    /// section whose title is a label rather than a subject.
    internal init(_ title: String) {
        self.init(title, actions: { EmptyView() })
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
            Text("Two glyphs — the Library's PGN header.")
                .foregroundStyle(.secondary)
        } header: {
            InspectorSectionHeader("Glyph Pair") {
                HStack(spacing: 12) {
                    Button { } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.borderless)
                        .font(.body)
                    Button { } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(.borderless)
                        .font(.body)
                }
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
    }
    .listStyle(.sidebar)
    .frame(width: 300, height: 460)
}
