//
//  GameActionsMenu.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 04/08/2026.
//

import SwiftData
import SwiftUI

/// The Library's context menu, once.
///
/// **The divergence this closes was real and had already produced three
/// different menus for five verbs.** `LibraryGameCardView` used `Label`s with
/// symbols and put an accessibility identifier on Export; `LibraryColumnsView`
/// used bare `Button("Open")` / `Button("Analyze")` / `Button("Export…")` with
/// no symbols and no identifiers; `LibraryListView` used `Label`s plus counted
/// plurals for a multi-selection. Same verbs, same destination, three
/// renderings — and adding Get Info meant editing all three by hand, which is
/// the moment it stopped being tolerable.
///
/// D26′'s argument, applied to a menu instead of a glyph: the point of a shared
/// type is not that duplication is wasteful but that a divergence becomes a
/// *compile-visible choice*. Three hand-written menus made "Columns has no
/// symbols" invisible unless two view modes were open side by side, which is
/// exactly the failure the shared-chrome family exists to prevent.
///
/// **Built around the list's shape rather than the card's**, because the
/// list's is the superset: it is the one host whose subject can be a set, and
/// a menu that can count can always count to one. The card and columns hosts
/// pass a single-element array and get the singular labels back.
///
/// The closures take `[PGN]` uniformly, so each host adapts once at its call
/// site instead of this type carrying three shapes. That adaptation is a
/// deliberate cost: the alternative — id-set closures here — would make the
/// two single-game hosts build a `Set` to describe one game they already hold.
internal struct GameActionsMenu: View {

    // MARK: Stored Properties

    /// The games the menu acts on: the whole selection when a selected row is
    /// right-clicked, otherwise just the one under the pointer.
    internal let games: [PGN]

    /// Single-game only, and that is a product decision rather than a
    /// limitation: one window per game, so "Open" over a selection of nine
    /// would mean nine windows or an arbitrary pick.
    internal let onOpen: (PGN) -> Void
    internal let onAnalyze: ([PGN]) -> Void
    internal let onExport: ([PGN]) -> Void
    internal let onDelete: ([PGN]) -> Void

    // MARK: Body
    internal var body: some View {
        if !games.isEmpty {
            if games.count == 1, let game = games.first {
                Button {
                    onOpen(game)
                } label: {
                    Label("Open in Board", systemImage: "checkerboard.rectangle")
                }
                GetInfoMenuItem(
                    request: .game(game.persistentModelID),
                    identifier: AccessibilityID.getInfoMenuItem(Destination.library.rawValue)
                )
            }

            Button {
                onAnalyze(games)
            } label: {
                // The toolbar's aggregate rule: checkmark only when the whole
                // set is analyzed. Safe to spell as a bare `allSatisfy` here
                // where the list host needed an emptiness guard beside it —
                // the branch above already established the set is non-empty,
                // and `allSatisfy` over nothing is vacuously true.
                //
                // The counted plural keeps its verb: "Analyzed 3 Games" would
                // read as a claim about what happened rather than a menu item
                // you can click.
                AnalysisLabel(
                    analyzed: games.allSatisfy(AnalysisGlyph.isAnalyzed),
                    title: games.count > 1 ? "Analyze \(games.count) Games" : nil
                )
            }

            Button {
                onExport(games)
            } label: {
                Label(
                    games.count > 1 ? "Export \(games.count) PGNs" : "Export PGN",
                    systemImage: "square.and.arrow.up"
                )
            }
            .accessibilityIdentifier(AccessibilityID.libraryExport)

            Divider()

            Button(role: .destructive) {
                onDelete(games)
            } label: {
                Label(
                    games.count > 1 ? "Delete \(games.count) Games" : "Delete",
                    systemImage: "trash"
                )
            }
        }
    }
}
