//
//  LiveGameHUDView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/06/2026.
//

import SwiftUI

/// The live-play status banner shown above the mirror board (M3.1) — the
/// always-visible answer to "what is the app doing with my board right now?"
///
/// Pure presentation: `BoardDestination` derives a `Phase` from
/// `DGTLiveSession` + `DGTConnection` and hands it over together with the one
/// action the banner can trigger (New Game). The view holds no state and
/// knows nothing about the session, which keeps every phase trivially
/// previewable.
///
/// Accessibility: one dotted, lowercase identifier per phase
/// (`live.hud.<phase>`) — identifiers are a tested contract.
internal struct LiveGameHUDView: View {
    
    // MARK: Phase
    
    /// Everything the banner can say. Derivation (including priority between
    /// overlapping session flags) lives in `BoardDestination.hudPhase`.
    internal enum Phase: Equatable {
        /// No board connected — point at the connection toolbar.
        case disconnected
        /// The board vanished mid-game and the auto-reconnect loop (M7.3)
        /// is retrying. Replugging resumes seamlessly — or through
        /// recovery, if pieces moved while the board was dark.
        case reconnecting
        /// Connected, no game running: invite setup or a manual New Game.
        case idle
        /// A game exists but the physical pieces don't match its position
        /// yet. Serves fresh starts in M3 and doubles as the resume prompt
        /// in M4 (the session's exit predicate is the *current* position).
        case awaitingSetup
        /// Live tracking: side to move, last SAN, ply count.
        case playing(sideToMove: PieceColor, lastSAN: String?, ply: Int)
        /// A legal move is recognized but one physical fix remains (e.g. an
        /// en-passant capture whose taken pawn wasn't lifted). A gentle
        /// nudge — visually distinct from recovery.
        case correction(message: String)
        /// The board can't be explained by any legal move — restore the last
        /// legal position. Minimal v1 banner; per-square guidance is M6.
        case recovering(lastSAN: String?)
        /// Terminal result reached and safely in the Library.
        case finished(result: GameResult)
        /// Terminal result reached but the Library save failed — the game
        /// is held (draft kept, new-game suppressed) until Retry succeeds
        /// or the player discards from the inspector.
        case archiveFailed(result: GameResult, message: String)
    }
    
    // MARK: Stored Properties
    
    internal let phase: Phase
    
    /// Invoked by the "New Game…" button (shown while `idle` / `finished`).
    /// Presenting the dialog is the destination's job.
    internal let onNewGame: () -> Void
    
    /// Invoked by the "Retry" button (shown while `archiveFailed`). The
    /// matching Discard lives in the inspector behind its existing
    /// destructive confirmation, so the HUD stays state-free. Defaulted so
    /// existing call sites and previews stay valid.
    internal var onRetryArchive: () -> Void = {}
    
    // MARK: Body
    
    internal var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(tint)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer(minLength: 12)
            
            if showsNewGameButton {
                Button("New Game…", action: onNewGame)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("live.hud.newgame")
            }
            
            if case .archiveFailed = phase {
                Button("Retry", action: onRetryArchive)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("live.hud.retryarchive")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
    
    // MARK: Phase Presentation
    
    private var showsNewGameButton: Bool {
        switch phase {
        case .idle, .finished: true
        default: false
        }
    }
    
    private var title: String {
        switch phase {
        case .disconnected:
            "No board connected"
        case .reconnecting:
            "Board disconnected — reconnecting…"
        case .idle:
            "Board connected"
        case .awaitingSetup:
            "Set up the starting position on the board…"
        case .playing(let side, _, _):
            side == .white ? "White to move" : "Black to move"
        case .correction:
            "One correction needed"
        case .recovering:
            "Illegal move or disturbed pieces"
        case .finished(let result):
            Self.headline(for: result)
        case .archiveFailed(let result, _):
            Self.headline(for: result) + " — not saved yet"
        }
    }
    
    private var subtitle: String? {
        switch phase {
        case .disconnected:
            "Connect your DGT board to record games live."
        case .reconnecting:
            "Plug the board back in — the game picks up where it left off."
        case .idle:
            "Set up the pieces to be offered a game, or start one now."
        case .awaitingSetup:
            "Live recording begins once the pieces match."
        case .playing(_, let lastSAN, let ply):
            lastSAN.map { "Last move: \($0) · ply \(ply)" }
            ?? "Waiting for the first move."
        case .correction(let message):
            message
        case .recovering(let lastSAN):
            lastSAN.map { "Restore the position after \($0) — square-by-square guidance is below." }
            ?? "Restore the starting position — square-by-square guidance is below."
        case .finished:
            "Saved to your Library. Start a new game whenever you're ready."
        case .archiveFailed(_, let message):
            "\(message) Retry, or discard the game from the inspector."
        }
    }
    
    private var symbolName: String {
        switch phase {
        case .disconnected:  "cable.connector.horizontal"
        case .reconnecting:  "arrow.triangle.2.circlepath"
        case .idle:          "checkmark.circle"
        case .awaitingSetup: "checkerboard.rectangle"
        case .playing:       "record.circle"
        case .correction:    "lightbulb"
        case .recovering:    "exclamationmark.triangle.fill"
        case .finished:      "flag.checkered"
        case .archiveFailed: "exclamationmark.arrow.circlepath"
        }
    }
    
    private var tint: Color {
        switch phase {
        case .disconnected:  .secondary
        case .reconnecting:  .orange
        case .idle:          .green
        case .awaitingSetup: .blue
        case .playing:       .red
        case .correction:    .orange
        case .recovering:    .red
        case .finished:      .green
        case .archiveFailed: .orange
        }
    }
    
    private var accessibilityIdentifier: String {
        switch phase {
        case .disconnected:  "live.hud.disconnected"
        case .reconnecting:  "live.hud.reconnecting"
        case .idle:          "live.hud.idle"
        case .awaitingSetup: "live.hud.awaitingsetup"
        case .playing:       "live.hud.playing"
        case .correction:    "live.hud.correction"
        case .recovering:    "live.hud.recovering"
        case .finished:      "live.hud.finished"
        case .archiveFailed: "live.hud.archivefailed"
        }
    }
    
    /// A human headline for a terminal result. `.ongoing` is unreachable
    /// from the `finished` phase but kept total for safety.
    private static func headline(for result: GameResult) -> String {
        switch result {
        case .whiteWins: "1–0 — White wins"
        case .blackWins: "0–1 — Black wins"
        case .draw:      "½–½ — Draw"
        case .ongoing:   "Game over"
        }
    }
}

// MARK: - Previews

#Preview("All Phases") {
    VStack(spacing: 0) {
        LiveGameHUDView(phase: .disconnected, onNewGame: {})
        LiveGameHUDView(phase: .reconnecting, onNewGame: {})
        LiveGameHUDView(phase: .idle, onNewGame: {})
        LiveGameHUDView(phase: .awaitingSetup, onNewGame: {})
        LiveGameHUDView(
            phase: .playing(sideToMove: .black, lastSAN: "Nf3", ply: 5),
            onNewGame: {}
        )
        LiveGameHUDView(
            phase: .correction(
                message: "Remove the captured pawn on e5 to complete dxe6."
            ),
            onNewGame: {}
        )
        LiveGameHUDView(phase: .recovering(lastSAN: "Qxf7"), onNewGame: {})
        LiveGameHUDView(phase: .finished(result: .whiteWins), onNewGame: {})
        LiveGameHUDView(
            phase: .archiveFailed(
                result: .whiteWins,
                message: "The Library couldn't be written."
            ),
            onNewGame: {}
        )
    }
    .padding(.bottom)
    .frame(width: 520)
}
