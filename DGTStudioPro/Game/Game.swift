import Foundation
import os

/// Ephemeral working model over a persisted `PGN`: walks the moves once at construction,
/// caches per-ply `GameState`s, and scrubs. Not persisted — rebuilt cheaply per open.
@Observable
@MainActor
internal final class Game {
    
    // MARK: Static Constants
    
    private static let logger = AppLog.logger(.game)
    
    // MARK: Errors
    
    internal enum BuildError: Error, Equatable {
        /// A SAN failed to parse; index, SAN and parser error carried for "move 14 ('Bxd5'): …" diagnostics.
        case invalidMove(index: Int, san: String, underlying: SANParseError)
    }
    
    // MARK: Source Material
    
    internal let pgn: PGN
    
    // MARK: Cached State Walk
    
    /// `states[0]` is the start; `states[i]` follows `moves[i-1]`. Always `moves.count + 1` long.
    internal let states: [GameState]
    
    /// Mirror of `states` for piece-identity tracking — stable animation identity across promotions
    /// and castling.
    internal let trackers: [PieceTracker]
    
    /// Parsed moves; `moves[i]` sits between `states[i]` and `states[i+1]`.
    internal let moves: [Move]
    
    // MARK: Scrub State
    
    /// Current ply in `0...moves.count`; 0 = before any move, end = default.
    internal private(set) var currentPly: Int
    
    // MARK: Computed Properties
    
    internal var currentState: GameState { states[currentPly] }
    internal var currentTracker: PieceTracker { trackers[currentPly] }

    /// The last move reaching `currentState`, or nil at ply 0 — the last-move highlight.
    internal var lastMove: LastMove? {
        guard currentPly > 0 else { return nil }
        let move = moves[currentPly - 1]
        return LastMove(from: move.from, to: move.to)
    }
    
    /// The side-to-move king's square when in check — the check highlight.
    internal var checkSquare: Square? {
        guard currentState.isInCheck else { return nil }
        return currentState.position.kingSquare(for: currentState.activeColor)
    }
    
    internal var canAdvance: Bool { currentPly < moves.count }
    internal var canRetreat: Bool { currentPly > 0 }
    
    /// Evaluation at `currentPly`, or nil. The off-by-one is the contract: `evaluations[i]` scores
    /// the position *after* `moves[i]`, so this reads `currentPly - 1`.
    internal var currentEvaluation: Evaluation? {
        guard currentPly > 0 else { return nil }
        return pgn.evaluation(atPly: currentPly - 1)
    }
    
    // MARK: Initializer
    
    /// Walks the move list, caching every state; throws on the first unparseable SAN — the stored
    /// row diverged from the core's rules.
    internal init(pgn: PGN) throws(BuildError) {
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
            } catch {
                Self.logger?.error(
                    """
                    SAN parse failed for '\(pgn.name, privacy: .public)' \
                    at move \(index + 1) (index \(index)): \
                    SAN='\(san, privacy: .public)' \
                    sideToMove=\(String(describing: state.activeColor), privacy: .public) \
                    fenBefore='\(FEN(state).string, privacy: .public)' \
                    error=\(String(describing: error), privacy: .public) \
                    priorMoves=[\(pgn.moves.prefix(index).joined(separator: " "), privacy: .public)]
                    """
                )
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
        
        Self.logger?.info(
            "Built game '\(pgn.name, privacy: .public)' plies=\(moves.count)"
        )
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
    
    /// Jumps to a ply, clamped.
    internal func jump(to ply: Int) {
        currentPly = max(0, min(ply, moves.count))
    }
    
    /// Jumps to the starting position.
    internal func toStart() { currentPly = 0 }
    
    /// Jumps to the final position.
    internal func toEnd() { currentPly = moves.count }
}
