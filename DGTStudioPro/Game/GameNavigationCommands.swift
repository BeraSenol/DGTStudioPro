//
//  GameNavigationCommands.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/05/2026.
//

import SwiftUI

// MARK: Focused Value

/// Carries the frontmost tab's working ``Game`` up to the scene's command
/// menu. Published by ``BoardDestination`` via `.focusedSceneValue` (which
/// resolves to the active window/tab), so the app-level navigation menu
/// always drives whichever game is in front — and nothing when the active
/// tab isn't showing a loaded game.
private struct ActiveGameKey: FocusedValueKey {
    typealias Value = Game
}

extension FocusedValues {
    internal var activeGame: Game? {
        get { self[ActiveGameKey.self] }
        set { self[ActiveGameKey.self] = newValue }
    }
}

// MARK: Commands

/// Move-navigation menu (First / Previous / Next / Last) with the standard
/// ←/→/Home/End shortcuts. Reads the active tab's ``Game`` through
/// `@FocusedValue` and dispatches to its scrub methods.
///
/// **Why the items are gated on `game == nil` only** — not on
/// `canAdvance`/`canRetreat`: `Game` is a reference type, so scrubbing
/// mutates it in place without changing the focused-value identity, and
/// SwiftUI would not re-evaluate a bounds-based `disabled(_:)` until focus
/// changed. That staleness could swallow a keypress at a boundary. The
/// scrub methods already no-op at the ends (and `jump(to:)` clamps), so
/// "enabled whenever a game is focused" is both correct and refresh-proof.
///
/// Gating on `game == nil` is still essential: when the active tab has no
/// loaded game (e.g. it's on the Library destination), the items are
/// disabled, so the bare-arrow key equivalents are **not** consumed and
/// fall through to the responder chain — sidebar/list arrow navigation
/// keeps working everywhere else in the app.
internal struct GameNavigationCommands: Commands {

    @FocusedValue(\.activeGame) private var game: Game?

    // No step throttle (removed 3 Aug 2026). ←/→ used to be paced to the
    // piece-glide duration through a `lastStep` timestamp and a third
    // `@AppStorage` read of `pieceAnimationDuration`, so a held arrow
    // stepped once per animation instead of once per system key repeat.
    //
    // The behaviour it bought back is the reason not to re-add it blind:
    // the key-repeat rate outruns the glide, so holding an arrow now moves
    // pieces that are still mid-flight. That is the accepted trade — the
    // throttle made held-arrow scrubbing slower than the keyboard, which is
    // the thing you actually feel, while teleporting pieces are the thing
    // you only notice if you look for them. If it ever needs revisiting,
    // the honest fix is shortening or cancelling the *animation* while a
    // repeat is in flight, not dropping the input that requested it.
    //
    // Consequences of the removal, both real: `pieceAnimationDuration` is
    // back to two read sites (corrected at `StorageKeys`), and this file no
    // longer imports AppKit — the Reduce Motion query on `NSWorkspace` was
    // the only reason it did, since `Commands` cannot reach
    // `@Environment(\.accessibilityReduceMotion)`.

    internal var body: some Commands {
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
        }
    }
}
