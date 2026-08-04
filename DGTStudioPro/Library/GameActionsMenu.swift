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
///
/// # Keyboard shortcuts (4 Aug 2026, late)
///
/// Every item carries one, and four of the five are borrowed rather than
/// invented: **⌘O** open and **⌘I** info are Finder's exact keys for the exact
/// same questions about a selected row; **⌘E** is export's near-universal
/// mnemonic and this app has no eject to collide with; **⌘⌫** is Move to Trash,
/// mirroring the plain ⌫ that `LibraryDestination.onDeleteCommand` already
/// answers, so the destructive verb has the same two spellings Finder gives it.
/// Only **⌘R** for Analyze had no convention to borrow — it reads as *Run*,
/// which is what an engine pass is, and it was taken over the more mnemonic
/// ⇧⌘A because that sits one slipped modifier from the select-all this
/// destination gained the same day, and the slip would queue a depth-18 pass
/// over everything on screen.
///
/// `GetInfoMenuItem` has carried ⌘I since M10 and is the precedent this follows
/// rather than a fourth thing to keep in sync — the key lives on that type, not
/// here.
///
/// **What is deliberately not claimed: that these keys fire when the menu is
/// shut.** `.keyboardShortcut` inside a `.contextMenu` certainly *renders* — ⌘I
/// has been visible on this menu since M10 — and whether SwiftUI also registers
/// it while the menu is closed depends on whether it builds the content eagerly,
/// which is a fact about the framework nobody here has measured. Three outcomes
/// are possible and they are not equally good: dead keys (labels only, and the
/// menu-bar `Commands` route is then owed); live and correct; or **live and
/// ambiguous**, which is the one to watch for, because the icons grid renders
/// one of these menus *per card* — N registrations of ⌘R over N different games
/// is worse than none. The manual check in the instructions is written to tell
/// the three apart, and this comment says "renders" rather than "works" until it
/// has been run.
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
                // Finder's key for the same verb. Only ever present in the
                // singular arity, which is the product decision above rendered
                // as a fact about the keyboard too: there is no ⌘O over nine
                // games because there is no Open over nine games.
                .keyboardShortcut("o", modifiers: .command)
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
            // R for Run — the one key here with no convention behind it, chosen
            // over ⇧⌘A for the reason in the type's doc.
            .keyboardShortcut("r", modifiers: .command)

            Button {
                onExport(games)
            } label: {
                Label(
                    games.count > 1 ? "Export \(games.count) PGNs" : "Export PGN",
                    systemImage: "square.and.arrow.up"
                )
            }
            .keyboardShortcut("e", modifiers: .command)
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
            // Finder's Move to Trash. The plain ⌫ is already live through
            // `LibraryDestination.onDeleteCommand`, so this is the second
            // spelling of one verb rather than a new door — and both land on
            // the same confirmation, which is what makes two spellings safe.
            .keyboardShortcut(.delete, modifiers: .command)
        }
    }
}

// MARK: Previews

/// Rendered inside a `Menu` rather than behind a `.contextMenu`, because a
/// canvas has no right-click: the modifier compiles and shows nothing, which
/// is a preview that witnesses the call site instead of the content. A `Menu`
/// pulls the same `body` down where it can be read.
///
/// The three arities are the whole point of this type and the reason there are
/// three rows: **one** game shows Open and Get Info, **many** shows neither
/// and counts everything else, and **none** renders an empty menu rather than
/// a menu of no-ops. That last one is the branch a host reaches by
/// right-clicking empty space in a table, and it is the one the three
/// hand-written menus each answered differently before this type existed.
///
/// The analyzed/unanalyzed split rides along on the singular row: `Analyze`
/// versus `Re-analyze` is `AnalysisGlyph.isAnalyzed`'s aggregate rule, and
/// a fixture with no evaluations is the unanalyzed side of it.
#Preview("Every Arity") {
    let one = PGN(
        event: "World Championship",
        site: "Dubai",
        round: 7,
        white: "Carlsen, Magnus",
        black: "Nepomniachtchi, Ian",
        result: .whiteWins
    )
    let two = PGN(
        event: "Club Championship",
        site: "Antwerp",
        round: 101,
        white: "Senol, Bera",
        black: "Reinaud, Lorenzo",
        result: .draw
    )

    return VStack(alignment: .leading, spacing: 16) {
        Menu("One Game") {
            GameActionsMenu(games: [one], onOpen: { _ in }, onAnalyze: { _ in },
                            onExport: { _ in }, onDelete: { _ in })
        }
        Menu("Two Games") {
            GameActionsMenu(games: [one, two], onOpen: { _ in }, onAnalyze: { _ in },
                            onExport: { _ in }, onDelete: { _ in })
        }
        Menu("Empty Selection") {
            GameActionsMenu(games: [], onOpen: { _ in }, onAnalyze: { _ in },
                            onExport: { _ in }, onDelete: { _ in })
        }
    }
    .menuStyle(.borderlessButton)
    .padding()
    .frame(width: 260)
    .modelContainer(for: PGN.self, inMemory: true)
}
