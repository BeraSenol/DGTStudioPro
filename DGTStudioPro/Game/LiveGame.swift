import Foundation
import os

/// The rule set; FIDE only in v1. Illegal-move handling follows FIDE 7.5.1 — recovery's
/// "return to the last legal position".
enum DGTRuleSet: String, CaseIterable, Codable, Sendable {
    case fide = "FIDE"
    
    var displayName: String { rawValue }
}

/// The working model for a live-recorded game — `Game`'s append-only sibling: no takebacks, no
/// rollback, ever (Decision #1). Legality comes only from the core's `legalMoves()`.
@Observable
@MainActor
final class LiveGame {
    
    // MARK: Static Constants
    
    private static let logger = AppLog.logger(.dgt)
    
    // MARK: Roster
    
    /// The mutable seven-tag metadata minus result (the game tracks it). Maps onto `PGN` for archive.
    struct Roster: Equatable, Sendable {
        var event: String
        var site: String
        var date: Date?
        var round: Int?
        var white: String
        var black: String

        /// The board identity (D28′), stamped once at game start; survives crash-resume via the draft.
        /// Not exposed by the roster forms — equipment, not a seat.
        var board: String?

        /// One player on both sides? (D61′) A forwarding accessor — `Player.seatsNameOnePlayer` owns
        /// the rule (one recipe, two spellings). Note `Roster` is nonisolated: a global actor does not
        /// isolate nested types (D44′).
        var seatsNameOnePlayer: Bool {
            Player.seatsNameOnePlayer(white, black)
        }

        init(
            event: String = "?",
            site: String = "?",
            date: Date? = .now,
            round: Int? = nil,
            white: String = "?",
            black: String = "?",
            board: String? = nil
        ) {
            self.event = event
            self.site = site
            self.date = date
            self.round = round
            self.white = white
            self.black = black
            self.board = board
        }
    }
    
    // MARK: Stored Properties
    
    let ruleSet: DGTRuleSet
    var roster: Roster
    
    /// Carried into the draft and across resume — a resumed game keeps its original start time.
    let startedAt: Date
    
    /// State at each ply boundary; always `moves.count + 1` long.
    private(set) var states: [GameState]
    
    /// Piece-identity mirror of `states`, for animation parity with `Game`.
    private(set) var trackers: [PieceTracker]
    
    /// The committed moves, oldest first.
    private(set) var moves: [Move]
    
    /// SAN parallel to `moves`, computed against the state *before* each move — the archived transcript.
    private(set) var sanMoves: [String]
    
    /// `.ongoing` until detected or set manually.
    private(set) var result: GameResult
    
    // MARK: Computed Properties
    
    // Force-unwrapped deliberately: seeded in `init`, append-only, non-empty by construction —
    // `last!` states that; `[count - 1]` hides it.
    var currentState: GameState { states.last! }
    var currentTracker: PieceTracker { trackers.last! }
    var position: Position { currentState.position }

    var isFinished: Bool { result != .ongoing }
    var plyCount: Int { moves.count }
    
    /// The last move, for the board's highlight.
    var lastMove: LastMove? {
        guard let move = moves.last else { return nil }
        return LastMove(from: move.from, to: move.to)
    }
    
    /// The side-to-move king's square when in check; nil otherwise.
    var checkSquare: Square? {
        let state = currentState
        guard state.isInCheck else { return nil }
        return state.position.kingSquare(for: state.activeColor)
    }
    
    // MARK: Initializer
    
    /// Starts from `start` (standard by default). A custom start gets an empty tracker — identities
    /// can't be inferred from a bare position.
    init(
        start: GameState = .starting,
        roster: Roster,
        ruleSet: DGTRuleSet = .fide,
        startedAt: Date = .now
    ) {
        self.ruleSet = ruleSet
        self.roster = roster
        self.startedAt = startedAt
        self.states = [start]
        self.trackers = [start == .starting ? .starting : .empty]
        self.moves = []
        self.sanMoves = []
        self.result = .ongoing
        
        Self.logger?.info(
            "Started live game: \(roster.white, privacy: .public) vs \(roster.black, privacy: .public)"
        )
    }
    
    // MARK: Recording
    
    /// Records a reconstructed move; `false` (nothing changed) if finished or illegal — the
    /// resolver never hands over an illegal move, so a rejection is an upstream logic error.
    @discardableResult
    func commit(_ move: Move) -> Bool {
        guard !isFinished else {
            Self.logger?.debug("Commit ignored, game already finished")
            return false
        }
        
        let state = currentState
        guard state.legalMoves().contains(move) else {
            Self.logger?.error(
                "Commit rejected, \(move.from)→\(move.to) not legal in current state"
            )
            return false
        }
        
        let san = state.san(for: move)
        var tracker = currentTracker
        tracker.applyMove(move)
        
        moves.append(move)
        sanMoves.append(san)
        states.append(state.applying(move))
        trackers.append(tracker)
        
        // Move line before result detection, so the log reads in event order.
        Self.logger?.info("Recorded \(san, privacy: .public) [ply \(self.moves.count)]")
        updateResult()
        return true
    }
    
    // MARK: Manual Result
    
    /// Resignation by `color`; no-op if already decided.
    func resign(_ color: PieceColor) {
        guard !isFinished else { return }
        result = (color == .white) ? .blackWins : .whiteWins
        Self.logger?.info("\(color == .white ? "White" : "Black", privacy: .public) resigned")
    }
    
    /// Records an agreed draw. No-op if the game is already decided.
    func agreeDraw() {
        guard !isFinished else { return }
        result = .draw
        Self.logger?.info("Draw agreed")
    }
    
    // MARK: Result Detection
    
    /// Auto-result on a terminal position: checkmate → mover wins, stalemate → draw. The other FIDE
    /// draw conditions are deferred to manual entry.
    private func updateResult() {
        let state = currentState
        guard state.legalMoves().isEmpty else { return }
        
        if state.isInCheck {
            // Side to move is checkmated — the other side won.
            result = (state.activeColor == .white) ? .blackWins : .whiteWins
            Self.logger?.info("Checkmate, \(self.result.rawValue, privacy: .public)")
        } else {
            result = .draw
            Self.logger?.info("Stalemate, draw")
        }
    }
}
