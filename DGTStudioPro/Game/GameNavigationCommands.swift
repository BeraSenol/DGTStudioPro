//
//  GameNavigationCommands.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/05/2026.
//

import AppKit
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

    /// The glide preference, read here as its third site (the layer's own
    /// and SettingsView's slider are the others; `StorageKeys` documents
    /// the set): a held arrow repeats at the system key-repeat rate, which
    /// outruns the piece animation and turns review into pieces teleporting
    /// mid-flight. Stepping is paced to the glide instead (2 Aug 2026).
    @AppStorage(StorageKeys.pieceAnimationDuration)
    private var animationDuration = BoardPieceLayer.defaultDuration

    /// When the last ←/→ step fired. `@MainActor` because a mutable static
    /// needs an isolation under language mode 6, and menu actions already
    /// run there; a static rather than instance state because `Commands`
    /// values are recreated freely and cannot hold `@State`.
    @MainActor private static var lastStep: Date = .distantPast

    internal var body: some Commands {
        CommandMenu("Game") {
            Button("First Move") { game?.toStart() }
                .keyboardShortcut(.home, modifiers: [])
                .disabled(game == nil)

            Button("Previous Move") { step { game?.retreat() } }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(game == nil)

            Button("Next Move") { step { game?.advance() } }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(game == nil)

            Button("Last Move") { game?.toEnd() }
                .keyboardShortcut(.end, modifiers: [])
                .disabled(game == nil)
        }
    }

    /// One step per glide: repeats (and deliberate rapid taps — the glide
    /// wouldn't have finished either way) inside the animation window are
    /// dropped. Under Reduce Motion there is no glide to outrun, so the
    /// gate opens fully — read via `NSWorkspace` because `Commands` is not
    /// a view and `@Environment(\.accessibilityReduceMotion)` cannot reach
    /// it. Home/End stay ungated: jumps are single actions, not repeats.
    @MainActor
    private func step(_ move: () -> Void) {
        let interval = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? 0
            : BoardPieceLayer.clampedDuration(animationDuration)
        let now = Date.now
        guard now.timeIntervalSince(Self.lastStep) >= interval else { return }
        Self.lastStep = now
        move()
    }
}
