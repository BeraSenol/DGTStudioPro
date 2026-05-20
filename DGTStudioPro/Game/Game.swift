//
//  Game.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/05/2026.
//

import Foundation

/// Live, ephemeral working model for a single chess game.
///
/// Built on top of a persisted ``PGN`` (the archive form): walks the move
/// list once at construction time and caches the per-ply ``GameState`` and
/// ``PieceTracker`` so the inspector, board view, and keyboard scrubber
/// can read "everything at ply N" in O(1).
///
/// `Game` is not persisted. SwiftData stores `PGN`; the cumulative state
/// list lives in memory only and is rebuilt cheaply each time a game is
/// opened. Per the Phase 8 design locks: SwiftData rows stay lean (no
/// derived-data bloat), and all scrub navigation — forward, backward, or
/// random jump — is constant-time.
///
/// The default scrub position is end-of-game, matching the convention
/// established by Lichess, Chess.com, and ChessBase: open a game, see the
/// final state, scrub backward to study.
@Observable
@MainActor
internal final class Game {

    // MARK: Errors

    internal enum BuildError: Error, Equatable {
        /// A SAN string in `pgn.moves` failed to parse against the state
        /// reached after the prior moves. The index, original SAN, and
        /// underlying parser error are carried so callers can surface
        /// "move 14 ('Bxd5'): no legal move matches" diagnostics.
        case invalidMove(index: Int, san: String, underlying: SANParseError)
    }

    // MARK: Source Material

    internal let pgn: PGN

    // MARK: Cached State Walk

    /// State at each ply boundary. `states[0]` is the starting position
    /// (no moves played); `states[i]` is the state reached after applying
    /// `moves[i - 1]`. Length is always `pgn.moves.count + 1`.
    internal let states: [GameState]

    /// Mirror of `states` for piece-identity tracking. Indexing matches.
    /// Used by the board view to keep animation identity stable across
    /// promotions and castling.
    internal let trackers: [PieceTracker]

    /// The parsed `Move` objects produced by walking each SAN string.
    /// `moves[i]` is the move played between `states[i]` and `states[i + 1]`.
    /// Length is `pgn.moves.count`.
    internal let moves: [Move]

    // MARK: Scrub State

    /// Current ply index in `0 ... moves.count`. 0 = before any move is
    /// played; `moves.count` = after the final move (default).
    internal private(set) var currentPly: Int

    // MARK: Computed Properties

    internal var currentState: GameState { states[currentPly] }
    internal var currentTracker: PieceTracker { trackers[currentPly] }

    /// FEN of the position at `currentPly`. Convenience for "copy FEN"
    /// and engine handoff.
    internal var currentFEN: FEN { FEN(currentState) }

    /// The last move played to reach `currentState`, or `nil` at ply 0.
    /// The board view uses this for the "last move" highlight.
    internal var lastMove: LastMove? {
        guard currentPly > 0 else { return nil }
        let move = moves[currentPly - 1]
        return LastMove(from: move.from, to: move.to)
    }

    /// Square of the side-to-move's king when in check; `nil` otherwise.
    /// Drives the king-in-check highlight on the board.
    internal var checkSquare: Square? {
        guard currentState.isInCheck else { return nil }
        return currentState.position.kingSquare(for: currentState.activeColor)
    }

    /// Engine evaluation at `currentPly`, sourced from `pgn.evaluations`.
    /// Returns `nil` at ply 0 (no move has been scored), when the game
    /// hasn't been analyzed, or when the specific ply wasn't evaluated.
    internal var currentEvaluation: Evaluation? {
        guard currentPly > 0 else { return nil }
        return pgn.evaluation(atPly: currentPly - 1)
    }

    internal var canAdvance: Bool { currentPly < moves.count }
    internal var canRetreat: Bool { currentPly > 0 }
    internal var isAtStart:  Bool { currentPly == 0 }
    internal var isAtEnd:    Bool { currentPly == moves.count }

    // MARK: Initializer

    /// Builds a `Game` from a `PGN` by walking the move list and caching
    /// every intermediate state. Throws on the first SAN string that
    /// fails to parse — the caller should treat that as corrupt PGN data
    /// (the import path catches its own malformed cases earlier; reaching
    /// here means the stored row diverged from the chess core's rules).
    internal init(pgn: PGN) throws {
        self.pgn = pgn

        var states: [GameState] = [.starting]
        var trackers: [PieceTracker] = [.starting]
        var moves: [Move] = []

        states.reserveCapacity(pgn.moves.count + 1)
        trackers.reserveCapacity(pgn.moves.count + 1)
        moves.reserveCapacity(pgn.moves.count)

        var state: GameState = .starting
        var tracker: PieceTracker = .starting

        for (index, san) in pgn.moves.enumerated() {
            let move: Move
            do {
                move = try state.parseSAN(san)
            } catch let error as SANParseError {
                throw BuildError.invalidMove(
                    index: index, san: san, underlying: error
                )
            }

            tracker.applyMove(move)
            state = state.applying(move)

            moves.append(move)
            states.append(state)
            trackers.append(tracker)
        }

        self.states = states
        self.trackers = trackers
        self.moves = moves
        self.currentPly = moves.count
    }

    // MARK: Navigation

    /// Advances one ply. No-op at end of game.
    internal func advance() {
        guard canAdvance else { return }
        currentPly += 1
    }

    /// Retreats one ply. No-op at start.
    internal func retreat() {
        guard canRetreat else { return }
        currentPly -= 1
    }

    /// Jumps to an arbitrary ply, clamping to the valid range. Used by
    /// `MoveHistoryView` tap-to-jump and (Phase 11) keyboard home/end.
    internal func jump(to ply: Int) {
        currentPly = max(0, min(ply, moves.count))
    }

    /// Jumps to the starting position.
    internal func toStart() { currentPly = 0 }

    /// Jumps to the final position.
    internal func toEnd() { currentPly = moves.count }
}
