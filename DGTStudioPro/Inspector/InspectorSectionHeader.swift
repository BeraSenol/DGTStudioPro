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
/// host keeps its own identifier, wording and action — `InspectorEditButton`
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
                InspectorEditButton(
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
                InspectorEditButton(
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
