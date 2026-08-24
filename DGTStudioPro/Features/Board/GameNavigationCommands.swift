import SwiftUI

// MARK: Focused Value

/// The frontmost tab's `Game`, published via `.focusedSceneValue` - the menu drives whichever
/// game is in front, nothing when the active tab has none.
///
/// **A live board tab is always such a tab.** `BoardDestination` publishes `tabState.boardGame`,
/// which is derived from a loaded `PGN` and stays nil while playing over the board - so the arrows
/// cannot scrub a live game, and Decision #1's append-only rule holds at the keyboard for free
/// rather than by a guard someone could remove.
private struct ActiveGameKey: FocusedValueKey {
    typealias Value = Game
}

extension FocusedValues {
    var activeGame: Game? {
        get { self[ActiveGameKey.self] }
        set { self[ActiveGameKey.self] = newValue }
    }
}

/// The Board's Get Info trigger - a trigger binding, not the request value: a `Commands` scene
/// cannot open a window, so the destination acts and the menu only asks.
///
/// **`Binding` is not `Equatable`, and that is an owed check, not a footnote.** `BoardDestination`
/// mints `$getInfoRequested` fresh on every body pass, so SwiftUI cannot tell a re-publish from a
/// change. ROADMAP's M16 "FocusedValue, the two-run check" names this as the suspected second cause
/// of a runtime warning and says to fix it *here* if it returns - a stable trigger publish, taking a
/// D-number, since this is D53′'s trigger-binding pattern in its third use.
private struct GetInfoRequestKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var boardGetInfoRequest: Binding<Bool>? {
        get { self[GetInfoRequestKey.self] }
        set { self[GetInfoRequestKey.self] = newValue }
    }
}

// MARK: Commands

/// First/Previous/Next/Last with ←/→/Home/End. Gated on `game == nil` only - a bounds-based
/// `disabled(_:)` doesn't re-evaluate until focus changes; with no game the items disable and
/// the bare arrows are NOT consumed (the collection grids keep them).
///
/// The visible half of that trade: at either end of a game all four items stay **enabled**, and
/// pressing → on the last move is a live menu item that does nothing. `advance()` and `toEnd()` are
/// no-ops at the bound, so the cost is an enabled control rather than a wrong one - and per D81′'s
/// step/jump split, a no-op `advance()` makes no sound either.
struct GameNavigationCommands: Commands {

    @FocusedValue(\.activeGame) private var game: Game?
    @FocusedValue(\.boardGetInfoRequest) private var getInfo: Binding<Bool>?

    // No step throttle (removed): pacing ←/→ to the glide duration made a held arrow lag the key
    // repeat. If revisited: extend the in-flight repeat, never drop the input.

    var body: some Commands {
        CommandMenu("Game") {
            Button("First Move") { game?.toStart() }
                .keyboardShortcut(.home, modifiers: [])
                .disabled(game == nil)

            Button("Previous Move") { game?.retreat() }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(game == nil)

            Button("Next Move") { game?.advance() }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(game == nil)

            Button("Last Move") { game?.toEnd() }
                .keyboardShortcut(.end, modifiers: [])
                .disabled(game == nil)

            Divider()

            // The Board's only Get Info door - a Board tab has no row to right-click. The live case carries
            // nothing (a live game has no identifier until it archives).
            GetInfoMenuItem(
                requesting: getInfo,
                identifier: AccessibilityID.getInfoBoardMenuItem
            )
        }
    }
}
