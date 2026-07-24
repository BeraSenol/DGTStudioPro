//
//  LiveGameHUDView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/06/2026.
//

import SwiftUI

/// The live-play status card (M3.1; re-homed into the sidebar's
/// `SessionSidebarPanel` by D15′) — the answer to "what is the app doing
/// with my board right now?", shown whenever a board is connected or
/// being chased (`reconnecting`). Plain disconnected has no card at all:
/// the message carried no action, so it lives in the live inspector's
/// empty state. Laid out as a narrow vertical card for the sidebar; the
/// container owns outer spacing. The `live.hud.*` identifiers are
/// unchanged — their witness stays the hardware checklist, so the
/// re-home is not a contract break.
internal struct LiveGameHUDView: View {
    
    // MARK: Phase
    
    /// Everything the banner can say. Derivation (including priority between
    /// overlapping session flags) lives in `BoardDestination.hudPhase`.
    internal enum Phase: Equatable {
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
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: symbolName)
                    .foregroundStyle(tint)
                    .font(.headline)
            }
            
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if showsNewGameButton {
                Button("New Game", action: onNewGame)
                    .padding(.top)
                    .buttonStyle(.bordered)
                    .foregroundStyle(tint)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(AccessibilityID.liveHUDNewGame)
            }
            
            if case .archiveFailed = phase {
                Button("Retry", action: onRetryArchive)
                    .padding(.top)
                    .buttonStyle(.bordered)
                    .foregroundStyle(tint)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(AccessibilityID.liveHUDRetryArchive)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        )
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
        case .reconnecting:  .orange
        case .idle:          .green
        case .awaitingSetup: .blue
        case .playing:       .green
        case .correction:    .orange
        case .recovering:    .red
        case .finished:      .blue
        case .archiveFailed: .red
        }
    }
    
    private var accessibilityIdentifier: String {
        switch phase {
        case .reconnecting:  AccessibilityID.liveHUDReconnecting
        case .idle:          AccessibilityID.liveHUDIdle
        case .awaitingSetup: AccessibilityID.liveHUDAwaitingSetup
        case .playing:       AccessibilityID.liveHUDPlaying
        case .correction:    AccessibilityID.liveHUDCorrection
        case .recovering:    AccessibilityID.liveHUDRecovering
        case .finished:      AccessibilityID.liveHUDFinished
        case .archiveFailed: AccessibilityID.liveHUDArchiveFailed
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

// MARK: Previews

#Preview("All Phases") {
    VStack(spacing: 6) {
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
    .frame(width: 400)
}
