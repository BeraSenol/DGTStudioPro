import SwiftData
import SwiftUI

/// The Library's context menu, once.
///
/// Three hosts had three hand-written menus for the same five verbs — differing
/// in symbols, identifiers and counted plurals — and adding Get Info meant
/// editing all three. D26′'s argument applied to a menu instead of a glyph: the
/// point is not that duplication is wasteful but that a divergence becomes a
/// *compile-visible choice*.
///
/// **Built around the list's shape rather than the card's**, because the list's
/// is the superset: it is the one host whose subject can be a set, and a menu
/// that can count can always count to one. The single-game hosts pass a
/// one-element array and get singular labels back.
///
/// The closures take `[PGN]` uniformly so each host adapts once at its call
/// site. The rejected alternative, id-set closures here, would make the two
/// single-game hosts build a `Set` to describe a game they already hold.
///
/// # Keyboard shortcuts
///
/// Four of five are borrowed rather than invented: **⌘O** and **⌘I** are
/// Finder's keys for the same questions about a selected row; **⌘E** is
/// export's mnemonic against an app with no eject to collide with; **⌘⌫** is
/// Move to Trash. Only **⌘R** for Analyze had no convention to borrow — *Run*,
/// taken over the more mnemonic ⇧⌘A because that sits one slipped modifier from
/// ⌘A, and the slip would queue a depth-18 pass over everything on screen.
///
/// ⌘I lives on `GetInfoMenuItem`, not here.
///
/// **Not claimed: that these keys fire when the menu is shut.**
/// `.keyboardShortcut` inside a `.contextMenu` certainly *renders*; whether
/// SwiftUI also registers it while the menu is closed depends on whether it
/// builds the content eagerly, which nobody here has measured. Three outcomes,
/// not equally good: dead keys (the menu-bar `Commands` route is then owed);
/// live and correct; or **live and ambiguous** — the one to watch for, since
/// the icons grid renders one of these menus *per card*, and N registrations of
/// ⌘R over N different games is worse than none. The manual check tells them
/// apart; this says "renders" rather than "works" until it has been run.
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

    /// Ambient rather than a sixth parameter, and this type is most of the
    /// reason the environment value exists: three hosts build this menu, one of
    /// them per card, and each carries its own previews. The argument is at the
    /// value's declaration.
    ///
    /// Context menu content inherits the environment of the view the modifier
    /// is attached to, so the destination's one write reaches all three.
    @Environment(\.analysisRunningGameID) private var runningAnalysisID

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
                // The shared aggregate rule: running wins, then checkmark only
                // when the whole set is analyzed. This site used to spell the
                // second half as a bare `allSatisfy` — safe here, where the
                // branch above establishes non-emptiness, and *not* safe at the
                // toolbar, which guarded separately. Both spellings are gone
                // into `AnalysisGlyph.state(of:runningID:)`, which is what makes
                // the two menus' answers structurally the same one.
                //
                // The counted plural keeps its verb: "Analyzed 3 Games" would
                // read as a claim about what happened rather than a menu item
                // you can click.
                AnalysisLabel(
                    state: AnalysisGlyph.state(of: games, runningID: runningAnalysisID),
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
            // Finder's Move to Trash — and **the app's only copy of ⌘⌫ since
            // 6 Aug 2026**, which is a materially different claim from the one
            // this comment made a day earlier.
            //
            // The trail, because it has now reversed twice and the current state
            // is the least safe of the three. Plain ⌫ was live through
            // `LibraryDestination.onDeleteCommand` and was retired 5 Aug by
            // request, precisely because being live was the problem — one
            // keystroke from a focused row, failing on a multi-selection you had
            // forgotten about. ⌘⌫ then moved onto the toolbar's Delete button,
            // deliberately *not* here, because a `keyboardShortcut` on an
            // always-present, already-guarded control is live whenever the
            // destination shows while this copy is known only to **render** —
            // nobody has measured whether SwiftUI registers a `.contextMenu`'s
            // shortcut with the menu shut. On 6 Aug the toolbar button was
            // removed by request and this became the only copy there is.
            //
            // So the outstanding measurement stopped being academic: if these
            // keys are dead, delete-by-keyboard is gone from the app entirely
            // and nothing says so. Accepted with the alternative on the table (a
            // menu-bar `Commands` scene, which is what would carry them for
            // certain); the boardless checklist is where it gets answered.
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
/// The analysis state rides along on the singular row through
/// `AnalysisGlyph.state(of:runningID:)`, and both fixtures below have no
/// evaluations, so every row here shows the unanalyzed side of it.
///
/// **The `.analyzing` state is not previewable here and that is worth naming.**
/// It comes from `\.analysisRunningGameID`, which a canvas leaves nil — and
/// injecting one would mean minting a `PersistentIdentifier`, which needs a
/// container. `AnalysisGlyph`'s own previews cover the three states against the
/// label; what this file's previews are for is *arity*, which is orthogonal.
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
