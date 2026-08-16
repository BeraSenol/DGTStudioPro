import SwiftUI

// MARK: Focused Value

/// The frontmost tab's `Game`, published via `.focusedSceneValue` - the menu drives whichever
/// game is in front, nothing when the active tab has none.
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
