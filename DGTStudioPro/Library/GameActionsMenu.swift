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
/// mnemonic and this app has no eject to collide with; **⌘⌫** is Move to Trash.
/// That last one mirrored a plain ⌫ handled by `LibraryDestination` until 5 Aug
/// 2026, when ⌫ alone was retired by request — its failure mode is a
/// multi-selection you had forgotten about, reachable by a finger already
/// resting nearby. The live copy of ⌘⌫ is the toolbar Delete button's now; this
/// is its mirror in the menu.
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

    /// Every closure here takes the set, as of D56′.
    ///
    /// This one said "single-game only, and that is a product decision rather
    /// than a limitation: one window per game, so Open over a selection of nine
    /// would mean nine windows or an arbitrary pick." Both halves of that
    /// sentence were true and it drew the wrong conclusion from them — nine
    /// windows is what Finder does, and the arbitrary pick was the thing to
    /// avoid. D56′ has the argument and the threshold that keeps ⌘A ⌘O from
    /// being a mistake you cannot undo.
    internal let onOpen: ([PGN]) -> Void
    internal let onAnalyze: ([PGN]) -> Void
    internal let onExport: ([PGN]) -> Void
    internal let onDelete: ([PGN]) -> Void

    // MARK: Body
    internal var body: some View {
        if !games.isEmpty {
            // Get Info stays singular, and after D56′ it is the **only** item
            // that is — which makes it the one place worth saying why. Open
            // widened because N windows is a coherent answer to "open these";
            // Get Info cannot, because its window resolves one subject and a
            // set has no roster, no opening and no result to show. That is a
            // fact about D53′'s window rather than a leftover of the rule
            // Open just left behind.
            if games.count == 1, let game = games.first {
                GetInfoMenuItem(
                    request: .game(game.persistentModelID),
                    identifier: AccessibilityID.getInfoMenuItem(Destination.library.rawValue)
                )

                Divider()
            }

            Button {
                onOpen(games)
            } label: {
                Label(
                    games.count > 1 ? "Open \(games.count) in Board" : "Open in Board",
                    systemImage: "checkerboard.rectangle"
                )
            }
            // Finder's key for the same verb, and since D56′ it is present at
            // every arity — the counted plural is what makes ⌘O over nine games
            // legible before you press it. The destination's threshold, not
            // this menu, is what stops ⌘A ⌘O being unrecoverable.
            .keyboardShortcut("o", modifiers: .command)

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

            Divider()

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
            // A second `.keyboardShortcut("r")` sat here until D56′ — a leftover
            // from moving Get Info above Open, which put Analyze's key on
            // Export. The outer modifier wins, so Export *was* ⌘R and ⌘E did
            // nothing, with both items drawing a glyph. Worth a comment rather
            // than a silent deletion: two `.keyboardShortcut`s on one control
            // compile, render one, and give no warning — the last-wins rule is
            // the whole failure, and a menu is where it is least visible
            // because every item shows a key whether or not it owns it.

            Divider()

            Button(role: .destructive) {
                onDelete(games)
            } label: {
                Label(
                    games.count > 1 ? "Delete \(games.count) Games" : "Delete",
                    systemImage: "trash"
                )
            }
            // Finder's Move to Trash.
            //
            // **This comment said the opposite until 5 Aug 2026** — that plain
            // ⌫ was "already live through `LibraryDestination.onDeleteCommand`,
            // so this is the second spelling of one verb rather than a new
            // door". Both halves were true when written and neither is now: ⌫
            // was retired by request, precisely because being live was the
            // problem (one keystroke from a focused row, and its failure mode
            // is a multi-selection you forgot about). The live copy of ⌘⌫ is
            // the toolbar Delete button's; this one mirrors it in the menu,
            // and both land on the same confirmation.
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
/// three rows: **one** game shows Get Info and the singular labels, **many**
/// drops Get Info alone and counts every remaining item including Open, and
/// **none** renders an empty menu rather than a menu of no-ops. That last one
/// is the branch a host reaches by right-clicking empty space in a table, and
/// it is the one the three hand-written menus each answered differently before
/// this type existed.
///
/// *(This paragraph read "one game shows Open and Get Info, many shows neither"
/// until D56′ widened Open. Corrected here in the same change, per the
/// two-homes rule — and the Two Games row is now the one that would have caught
/// the regression, because it is where a still-singular Open would render as an
/// absence nobody notices.)*
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
    .frame(width: 200)
    .modelContainer(for: PGN.self, inMemory: true)
}
