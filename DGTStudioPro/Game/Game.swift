import Foundation
import os

/// Ephemeral working model over a persisted `PGN`: walks the moves once at construction,
/// caches per-ply `GameState`s, and scrubs. Not persisted — rebuilt cheaply per open.
@Observable
@MainActor
final class Game {
    
    // MARK: Static Constants
    
    private static let logger = AppLog.logger(.game)
    
    // MARK: Errors
    
    enum BuildError: Error, Equatable {
        /// A SAN failed to parse; index, SAN and parser error carried for "move 14 ('Bxd5'): …" diagnostics.
        case invalidMove(index: Int, san: String, underlying: SANParseError)
    }
    
    // MARK: Source Material
    
    let pgn: PGN
    
    // MARK: Cached State Walk
    
    /// `states[0]` is the start; `states[i]` follows `moves[i-1]`. Always `moves.count + 1` long.
    let states: [GameState]
    
    /// Mirror of `states` for piece-identity tracking — stable animation identity across promotions
    /// and castling.
    let trackers: [PieceTracker]
    
    /// Parsed moves; `moves[i]` sits between `states[i]` and `states[i+1]`.
    let moves: [Move]
    
    // MARK: Scrub State
    
    /// Current ply in `0...moves.count`; 0 = before any move, end = default.
    private(set) var currentPly: Int
    
    // MARK: Computed Properties
    
    var currentState: GameState { states[currentPly] }
    var currentTracker: PieceTracker { trackers[currentPly] }

    /// The last move reaching `currentState`, or nil at ply 0 — the last-move highlight.
    var lastMove: LastMove? {
        guard currentPly > 0 else { return nil }
        let move = moves[currentPly - 1]
        return LastMove(from: move.from, to: move.to)
    }
    
    /// The side-to-move king's square when in check — the check highlight.
    var checkSquare: Square? {
        guard currentState.isInCheck else { return nil }
        return currentState.position.kingSquare(for: currentState.activeColor)
    }
    
    var canAdvance: Bool { currentPly < moves.count }
    var canRetreat: Bool { currentPly > 0 }
    
    /// Evaluation at `currentPly`, or nil. The off-by-one is the contract: `evaluations[i]` scores
    /// the position *after* `moves[i]`, so this reads `currentPly - 1`.
    var currentEvaluation: Evaluation? {
        guard currentPly > 0 else { return nil }
        return pgn.evaluation(atPly: currentPly - 1)
    }
    
    // MARK: Initializer
    
    /// Walks the move list, caching every state; throws on the first unparseable SAN — the stored
    /// row diverged from the core's rules.
    init(pgn: PGN) throws(BuildError) {
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
    
    // MARK: Cues

    /// Board cue for a **single step**, wired by `BoardDestination`. Nil — previews, tests,
    /// any `Game` built outside the destination — is silent by construction, the settable-hook
    /// invariant applied one layer down from the session.
    ///
    /// The step/jump split is expressed by *which methods call this*, not by a flag a caller
    /// passes: `advance` and `retreat` announce, `jump(to:)`, `toStart()` and `toEnd()` do not.
    /// A caller cannot get it wrong, because a caller is never asked. The rule it encodes: one
    /// keypress, one sound — Home over a 90-ply game crossing 90 plies is one position change,
    /// and 90 clicks for it would be the machine-gun this hook exists to avoid.
    @ObservationIgnored var onStep: ((BoardCue) -> Void)?

    // MARK: Navigation

    /// Advances one ply. No-op at end of game.
    func advance() {
        guard canAdvance else { return }
        currentPly += 1
        announceCurrentPly()
    }

    /// Retreats one ply. No-op at start.
    func retreat() {
        guard canRetreat else { return }
        currentPly -= 1
        announceCurrentPly()
    }

    /// Jumps to a ply, clamped. Silent — see `onStep`.
    func jump(to ply: Int) {
        currentPly = max(0, min(ply, moves.count))
    }

    /// Jumps to the starting position. Silent — see `onStep`.
    func toStart() { currentPly = 0 }

    /// Jumps to the final position. Silent — see `onStep`.
    func toEnd() { currentPly = moves.count }

    /// The cue for the move that produced the position now on screen. One expression for both
    /// directions, deliberately: the cue describes *where you are*, not which way you arrived, so
    /// retreating onto a check sounds like a check. Silent at ply 0, where no move produced the
    /// position — the start is not a move played.
    ///
    /// The nil-hook guard comes first so an unwired `Game` never pays `BoardCue`'s `legalMoves()`
    /// in a check position.
    private func announceCurrentPly() {
        guard let onStep, currentPly > 0 else { return }
        onStep(BoardCue.cue(for: moves[currentPly - 1], landing: states[currentPly]))
    }
}
