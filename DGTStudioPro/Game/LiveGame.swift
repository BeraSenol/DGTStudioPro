//
//  LiveGame.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 13/06/2026.
//

import Foundation
import os

/// The rule set a game is played under. Stored and shown on the game; FIDE is
/// the only option in v1, and switching rule sets is a late-stage concern.
/// Illegal-move handling follows FIDE Art. 7.5.1 (reinstate the position before
/// the irregularity), which the recovery system (D6) implements as "return to
/// the last legal position."
internal enum DGTRuleSet: String, CaseIterable, Codable, Sendable {
    case fide = "FIDE"
    
    internal var displayName: String { rawValue }
}

/// The working model for a game being recorded live from the DGT board.
///
/// `LiveGame` is the append-only sibling of `Game`: where `Game` builds once
/// from a finished `PGN` and only scrubs, `LiveGame` starts from a position and
/// grows one move at a time as the board reports them. It owns the running
/// state walk, the SAN transcript (for the eventual PGN), the seven-tag roster,
/// the rule set, and the result — which it auto-detects on checkmate and
/// stalemate.
///
/// One board ⇒ one live game, so the app holds a single optional `LiveGame` on
/// `DGTLiveSession`. The displayed board always mirrors the *physical* board
/// (see `DGTConnection.physicalBoard`); this model tracks the *legal* game in
/// parallel and is what gets archived to the Library (D7) when finished.
///
/// Legality is sourced only from the chess core's own `legalMoves()` — a
/// committed move must be legal in the current state or it is rejected.
@Observable
@MainActor
internal final class LiveGame {
    
    // MARK: Static Constants
    
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "dgt"
    )
    
    // MARK: Roster
    
    /// The mutable seven-tag metadata (minus result, which the game tracks as
    /// it plays). Maps directly onto `PGN`'s tags for the D7 archive step.
    internal struct Roster: Equatable, Sendable {
        internal var event: String
        internal var site: String
        internal var date: Date?
        internal var round: Int?
        internal var white: String
        internal var black: String
        
        internal init(
            event: String = "?",
            site: String = "?",
            date: Date? = .now,
            round: Int? = nil,
            white: String = "?",
            black: String = "?"
        ) {
            self.event = event
            self.site = site
            self.date = date
            self.round = round
            self.white = white
            self.black = black
        }
    }
    
    // MARK: Stored Properties
    
    internal let ruleSet: DGTRuleSet
    internal var roster: Roster
    
    /// When this game began — carried into the draft (M4) and across resume,
    /// so a resumed game keeps its original start time.
    internal let startedAt: Date
    
    /// State at each ply boundary. `states[0]` is the start; `states[i]` is the
    /// state after `moves[i - 1]`. Always `moves.count + 1` long.
    private(set) internal var states: [GameState]
    
    /// Piece-identity mirror of `states`, for animation parity with `Game`.
    private(set) internal var trackers: [PieceTracker]
    
    /// The committed moves, oldest first.
    private(set) internal var moves: [Move]
    
    /// SAN strings parallel to `moves`, computed against the state *before*
    /// each move — the transcript archived to PGN.
    private(set) internal var sanMoves: [String]
    
    /// The current result. `.ongoing` until checkmate / stalemate is detected
    /// or a result is set manually (resignation / agreed draw).
    private(set) internal var result: GameResult
    
    // MARK: Computed Properties
    
    // Force-unwrapped deliberately: `states` and `trackers` are seeded in
    // `init` and only ever appended to, so both are non-empty by construction.
    // `last!` states that; `[count - 1]` hides it behind arithmetic.
    internal var currentState: GameState { states.last! }
    internal var currentTracker: PieceTracker { trackers.last! }
    internal var position: Position { currentState.position }
    internal var currentFEN: FEN { FEN(currentState) }
    
    internal var isFinished: Bool { result != .ongoing }
    internal var plyCount: Int { moves.count }
    
    /// The last move played, for the board's last-move highlight.
    internal var lastMove: LastMove? {
        guard let move = moves.last else { return nil }
        return LastMove(from: move.from, to: move.to)
    }
    
    /// Square of the side-to-move's king when in check; nil otherwise.
    internal var checkSquare: Square? {
        let state = currentState
        guard state.isInCheck else { return nil }
        return state.position.kingSquare(for: state.activeColor)
    }
    
    // MARK: Initializer
    
    /// Starts a live game from `start` (the standard starting position by
    /// default — the only case v1 triggers on). A custom start gets an empty
    /// piece tracker, since identities can't be inferred from a bare position.
    internal init(
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
        
        Self.logger.info(
            "Started live game: \(roster.white, privacy: .public) vs \(roster.black, privacy: .public)"
        )
    }
    
    // MARK: Recording
    
    /// Records a reconstructed move. Returns `false` (and changes nothing) if
    /// the game is already finished or the move isn't legal in the current
    /// state — the resolver should never hand over an illegal move, so a
    /// rejection here means a logic error upstream, logged accordingly.
    @discardableResult
    internal func commit(_ move: Move) -> Bool {
        guard !isFinished else {
            Self.logger.debug("commit ignored: game already finished")
            return false
        }
        
        let state = currentState
        guard state.legalMoves().contains(move) else {
            Self.logger.error(
                "commit rejected: \(move.from)→\(move.to) not legal in current state"
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
        
        // The move line precedes result detection so the log reads in event
        // order (Recorded Qd2# → Checkmate — 0-1); updateResult()'s own line
        // would otherwise print before the move that caused it.
        Self.logger.info("Recorded \(san, privacy: .public) [ply \(self.moves.count)]")
        updateResult()
        return true
    }
    
    // MARK: Manual Result
    
    /// Records a resignation by `color` (the other side wins). No-op if the
    /// game is already decided.
    internal func resign(_ color: PieceColor) {
        guard !isFinished else { return }
        result = (color == .white) ? .blackWins : .whiteWins
        Self.logger.info("\(color == .white ? "White" : "Black", privacy: .public) resigned")
    }
    
    /// Records an agreed draw. No-op if the game is already decided.
    internal func agreeDraw() {
        guard !isFinished else { return }
        result = .draw
        Self.logger.info("Draw agreed")
    }
    
    // MARK: Result Detection
    
    /// Auto-sets the result on a terminal position. Checkmate → the side that
    /// just moved wins; stalemate → draw. The other FIDE draw conditions
    /// (50-move, threefold, insufficient material) are deferred for v1 and left
    /// to manual entry.
    private func updateResult() {
        let state = currentState
        guard state.legalMoves().isEmpty else { return }
        
        if state.isInCheck {
            // The side to move is checkmated, so the other side won.
            result = (state.activeColor == .white) ? .blackWins : .whiteWins
            Self.logger.info("Checkmate — \(self.result.rawValue, privacy: .public)")
        } else {
            result = .draw
            Self.logger.info("Stalemate — draw")
        }
    }
}
