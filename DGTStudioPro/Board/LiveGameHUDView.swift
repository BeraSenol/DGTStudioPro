//
//  LiveGameHUDView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/06/2026.
//

import SwiftUI

/// The live-play status banner floating over the Board destination's mirror
/// branch (M3.1). One banner, one state at a time, derived fresh on every
/// body evaluation from the app-global `DGTLiveSession` + `DGTConnection`.
/// The session's published flags are derived from a single `Mode` and can
/// never contradict each other, so the priority chain below is total and
/// unambiguous.
///
/// States, in priority order:
/// 1. No game, no board      → how to connect.                `live.hud.disconnected`
/// 2. No game, board ready   → set up the pieces / New Game.  `live.hud.idle`
/// 3. Game finished          → result chip + New Game.        `live.hud.finished`
/// 4. Game, board unplugged  → reconnect prompt (M7 will
///    auto-reconnect; for now the toolbar is the path back).  `live.hud.unplugged`
/// 5. Recovering             → minimal restore banner; the
///    full per-square guidance lands in M6.                   `live.hud.recovering`
/// 6. Correction hint        → gentle nudge, visually
///    distinct (orange) from recovery (red).                  `live.hud.correction`
/// 7. Awaiting setup         → set up the start — or, once
///    M4's resume exists, restore the game's current
///    position (`plyCount` decides the wording).              `live.hud.setup`
/// 8. Playing                → side to move + last SAN + ply. `live.hud.playing`
///
/// Accessibility identifiers are a tested contract: every state carries its
/// own (`live.hud.<state>`, dotted lowercase), and the New Game button is
/// `live.hud.newgame`.
internal struct LiveGameHUDView: View {
    
    // MARK: Configuration
    
    /// Everything one banner state needs to render. Built fresh each body
    /// evaluation — never stored, so it can't go stale against the session.
    private struct Configuration: Equatable {
        var identifier: String
        var symbol: String
        var tint: Color
        var title: String
        var subtitle: String?
        var showsNewGameButton = false
    }
    
    // MARK: Environment
    
    @Environment(DGTLiveSession.self) private var session
    @Environment(DGTConnection.self) private var connection
    
    // MARK: Stored Properties
    
    /// Invoked by the banner's "New Game" button (idle + finished states).
    /// Presentation — the roster sheet and the replace-confirmation — is the
    /// Board destination's job; the HUD only reports intent.
    internal let onNewGame: () -> Void
    
    // MARK: Initializer
    
    internal init(onNewGame: @escaping () -> Void = {}) {
        self.onNewGame = onNewGame
    }
    
    // MARK: Body
    
    internal var body: some View {
        let config = configuration
        
        HStack(spacing: 10) {
            Image(systemName: config.symbol)
                .font(.title3)
                .foregroundStyle(config.tint)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(config.title)
                    .font(.callout.weight(.semibold))
                if let subtitle = config.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            if config.showsNewGameButton {
                Spacer(minLength: 12)
                Button("New Game", action: onNewGame)
                    .controlSize(.small)
                    .accessibilityIdentifier("live.hud.newgame")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 560)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(config.tint.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(config.identifier)
        .animation(.easeInOut(duration: 0.15), value: config)
    }
    
    // MARK: State Derivation
    
    private var configuration: Configuration {
        guard let game = session.liveGame else {
            return connection.isConnected ? idle : disconnected
        }
        if game.isFinished { return finished(game) }
        if !connection.isConnected { return unplugged }
        if session.needsRecovery { return recovering(game) }
        if let hint = session.correctionHint { return correction(hint) }
        if session.awaitingPhysicalSetup { return setup(game) }
        return playing(game)
    }
    
    private var disconnected: Configuration {
        Configuration(
            identifier: "live.hud.disconnected",
            symbol: "antenna.radiowaves.left.and.right.slash",
            tint: .secondary,
            title: "No board connected",
            subtitle: "Connect your DGT board from the toolbar to record games as you play."
        )
    }
    
    private var idle: Configuration {
        Configuration(
            identifier: "live.hud.idle",
            symbol: "checkerboard.rectangle",
            tint: .secondary,
            title: "Board connected — ready when you are",
            subtitle: "Set up the starting position to be offered a game, or start one now.",
            showsNewGameButton: true
        )
    }
    
    private func finished(_ game: LiveGame) -> Configuration {
        Configuration(
            identifier: "live.hud.finished",
            symbol: "flag.checkered",
            tint: .green,
            title: "\(game.result.rawValue) — \(label(for: game.result))",
            subtitle: "Game over. Details stay editable in the inspector; start a new game when you're ready.",
            showsNewGameButton: true
        )
    }
    
    private var unplugged: Configuration {
        Configuration(
            identifier: "live.hud.unplugged",
            symbol: "antenna.radiowaves.left.and.right.slash",
            tint: .red,
            title: "Board disconnected",
            subtitle: "The game is paused — reconnect the board from the toolbar to continue."
        )
    }
    
    private func recovering(_ game: LiveGame) -> Configuration {
        let target = numberedLastSAN(of: game).map { "the position after \($0)" }
        ?? "the starting position"
        return Configuration(
            identifier: "live.hud.recovering",
            symbol: "exclamationmark.triangle.fill",
            tint: .red,
            title: "Board doesn't match the game",
            subtitle: "Illegal move or disturbed pieces — restore \(target) and play continues."
        )
    }
    
    private func correction(_ hint: DGTLiveSession.CorrectionHint) -> Configuration {
        Configuration(
            identifier: "live.hud.correction",
            symbol: "info.circle.fill",
            tint: .orange,
            title: "Finish the move",
            subtitle: hint.message
        )
    }
    
    private func setup(_ game: LiveGame) -> Configuration {
        // `awaitingSetup`'s exit predicate compares against the game's
        // *current* position, so a resumed game (M4) reuses this state with
        // the mid-game wording — `plyCount` is what tells the two apart.
        if game.plyCount == 0 {
            return Configuration(
                identifier: "live.hud.setup",
                symbol: "square.grid.3x3",
                tint: .blue,
                title: "Set up the starting position",
                subtitle: "Place the pieces on their starting squares — tracking begins automatically."
            )
        }
        let target = numberedLastSAN(of: game).map { "the position after \($0)" }
        ?? "the game's current position"
        return Configuration(
            identifier: "live.hud.setup",
            symbol: "square.grid.3x3",
            tint: .blue,
            title: "Restore the game position",
            subtitle: "Set the board to \(target) — play resumes automatically."
        )
    }
    
    private func playing(_ game: LiveGame) -> Configuration {
        let subtitle = numberedLastSAN(of: game).map {
            "Last move \($0) · ply \(game.plyCount)"
        } ?? "Recording — waiting for the first move."
        return Configuration(
            identifier: "live.hud.playing",
            symbol: "record.circle",
            tint: .red,
            title: "\(name(of: game.currentState.activeColor)) to move",
            subtitle: subtitle
        )
    }
    
    // MARK: Formatting
    
    /// The transcript's last move with its move number — "12. e4" for White,
    /// "12… Nf6" for Black — or nil before the first move.
    private func numberedLastSAN(of game: LiveGame) -> String? {
        guard let san = game.sanMoves.last else { return nil }
        let plyIndex = game.sanMoves.count - 1
        let moveNumber = plyIndex / 2 + 1
        return plyIndex.isMultiple(of: 2) ? "\(moveNumber). \(san)" : "\(moveNumber)… \(san)"
    }
    
    private func label(for result: GameResult) -> String {
        switch result {
        case .whiteWins: "White wins"
        case .blackWins: "Black wins"
        case .draw:      "Draw"
        case .ongoing:   "In progress"
        }
    }
    
    private func name(of color: PieceColor) -> String {
        color == .white ? "White" : "Black"
    }
}

// MARK: - Previews

#Preview("No Board") {
    LiveGameHUDView()
        .padding(40)
        .environment(DGTLiveSession())
        .environment(DGTConnection())
}

#Preview("Game Awaiting Board") {
    // With no connection, a created game renders the unplugged banner —
    // the connected states need hardware (or M7's remembered device).
    let session = DGTLiveSession()
    session.startNewGame(
        roster: .init(white: "Heylen, Christophe", black: "Brouns, Reinaud")
    )
    return LiveGameHUDView()
        .padding(40)
        .environment(session)
        .environment(DGTConnection())
}
