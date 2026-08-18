import SwiftData
import SwiftUI

/// The Library's context menu, once - three hosts had three hand-written copies of five verbs.
/// Keys borrowed where a convention exists (⌘O open, ⌘E export, ⌘⌫ trash); ⌘R = Run for
/// Analyze, chosen over ⇧⌘A (one slipped modifier from ⌘A). **Not claimed: that keys fire while
/// the menu is shut** - rendered for certain, liveness unmeasured.
struct GameActionsMenu: View {

    // MARK: Stored Properties

    /// The whole selection when a selected row is right-clicked, else the one under the pointer.
    let games: [PGN]

    /// Every closure takes the set. Open's old singular rule was well argued and wrong -
    /// N windows is Finder's answer; the arbitrary pick was the real hazard.
    let onOpen: ([PGN]) -> Void
    let onAnalyze: ([PGN]) -> Void
    let onExport: ([PGN]) -> Void
    let onDelete: ([PGN]) -> Void

    /// Ambient rather than a sixth parameter - three hosts, one per card, each with previews.
    @Environment(\.analysisRunningGameID) private var runningAnalysisID

    // MARK: Body
    var body: some View {
        if !games.isEmpty {
            // Get Info stays singular - the only item that is: its window resolves one subject; a
            // set has no roster to show.
            if games.count == 1, let game = games.first {
                GetInfoMenuItem(
                    request: .game(game.persistentModelID),
                    identifier: AccessibilityID.getInfoMenuItem(Destination.library.rawValue)
                )

                Divider()
            }

            // Named for what it does since 17 Aug 2026: this item is the ONLY door to a new
            // tab. Double-click stopped taking it that day - opening a tab per double-click
            // buried the reader in tabs they never asked for - and now loads the game into the
            // tab they are already in. A second item for that would just restate the gesture.
            Button {
                onOpen(games)
            } label: {
                Label(
                    games.count > 1 ? "Open \(games.count) in New Tabs" : "Open in New Tab",
                    systemImage: "checkerboard.rectangle"
                )
            }
            // Finder's key. The counted plural makes ⌘O over nine games legible before the press; the
            // destination's threshold, not this menu, stops ⌘A ⌘O being unrecoverable.
            .keyboardShortcut("o", modifiers: .command)

            Button {
                onAnalyze(games)
            } label: {
                // The shared aggregate rule: running wins, then checkmark only when the whole set is analyzed.
                // Title comes from `menuTitle`, not the label's `actionTitle` default: this is an
                // action surface, so an analyzed game reads "Re-Analyze" while the badges in the
                // list and columns keep stating "Analyzed".
                let state = AnalysisGlyph.state(of: games, runningID: runningAnalysisID)
                AnalysisLabel(
                    state: state,
                    title: AnalysisGlyph.menuTitle(state, count: games.count)
                )
            }
            // R for Run - the one key with no convention behind it (see the type doc).
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
            // A second `.keyboardShortcut("r")` sat here once - the outer modifier wins, so Export was ⌘R
            // and ⌘E was dead, with both items drawing glyphs. Stacking the modifier is legal; a menu is
            // the worst place for it.

            Divider()

            Button(role: .destructive) {
                onDelete(games)
            } label: {
                Label(
                    games.count > 1 ? "Delete \(games.count) Games" : "Delete",
                    systemImage: "trash"
                )
            }
            // Finder's Move to Trash - **the app's only copy of ⌘⌫ since 6 Aug 2026** (the toolbar button
            // that carried it is gone), resting on a copy known only to render. Plain ⌫ deliberately does
            // nothing anywhere.
            .keyboardShortcut(.delete, modifiers: .command)
        }
    }
}

// MARK: Previews

/// Rendered inside a `Menu`, not behind `.contextMenu` - a canvas has no right-click, and the
/// modifier would witness the call site instead of the content. `.analyzing` is not previewable
/// here: the environment value is nil in a canvas.
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
