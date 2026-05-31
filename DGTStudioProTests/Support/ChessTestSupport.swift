//
//  ChessTestSupport.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 27/05/2026.
//

import Testing
@testable import DGTStudioPro

// MARK: - GameState Construction & Per-Square Move Filters

extension GameState {
    
    /// A bare game state for move-generation tests: a position with no castling
    /// rights and the clock at the start, parameterised only on the axes the
    /// move-gen suites actually vary (active color, en passant target, and —
    /// occasionally — castling rights). Replaces the private `makeState`
    /// helper duplicated across the Pawn / Knight / King / Sliding / Castling
    /// suites.
    static func test(
        _ position: Position,
        activeColor: PieceColor = .white,
        castlingRights: CastlingRights = .none,
        enPassantTarget: Square? = nil
    ) -> GameState {
        GameState(
            position: position,
            activeColor: activeColor,
            castlingRights: castlingRights,
            enPassantTarget: enPassantTarget,
            halfmoveClock: 0,
            fullmoveNumber: 1
        )
    }
    
    /// Throwing convenience: a state parsed from a FEN string. Replaces the
    /// `GameState(try FEN(parsing:))` pair repeated in the DGT, SAN, and
    /// applying/replay suites.
    static func parsing(_ fen: String) throws -> GameState {
        GameState(try FEN(parsing: fen))
    }
    
    /// Pseudo-legal moves originating from a single square — the per-piece
    /// filter every move-generation suite applies. Overloads the no-argument
    /// `pseudoLegalMoves()` rather than introducing a new name, so call sites
    /// read naturally: `state.pseudoLegalMoves(from: Squares.e4)`.
    func pseudoLegalMoves(from square: Square) -> [Move] {
        pseudoLegalMoves().filter { $0.from == square }
    }
    
    /// Legal (check-filtered) moves originating from a single square. The
    /// legality analogue of `pseudoLegalMoves(from:)`, for suites that assert
    /// against fully filtered moves.
    func legalMoves(from square: Square) -> [Move] {
        legalMoves().filter { $0.from == square }
    }
}

// MARK: - Position Building

extension Position {
    
    /// Builds a position from `.empty` via an in-out closure, tidying the
    /// `var pos = Position.empty; pos[…] = …; …` dance the move-gen suites
    /// repeat in nearly every test:
    ///
    /// ```swift
    /// let pos = Position.make {
    ///     $0[Squares.e4] = .whitePawn
    ///     $0[Squares.d5] = .blackPawn
    /// }
    /// ```
    static func make(_ build: (inout Position) -> Void) -> Position {
        var pos = Position.empty
        build(&pos)
        return pos
    }
}

// MARK: - Perft & Canonical Reference Positions

/// Shared chess-core fixtures: the canonical perft reference positions and the
/// recursive perft counter, used by `PerftTests` and any other suite that wants
/// a known-good position.
///
/// Note: `PerftDeepTests` deliberately keeps its **own** private copy of these
/// FENs (see the explanatory comment in that file) so the slow depth-5
/// re-certification can't silently drift away from the canonical source by
/// accident. That intentional duplication is preserved — only the shallow
/// suites read their positions from here.
enum Chess {
    
    // The six canonical perft positions (chessprogramming.org).
    static let kiwipete =
    "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -"
    static let position3 =
    "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -"
    static let position4 =
    "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq -"
    static let position5 =
    "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ -"
    static let position6 =
    "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - -"
    
    /// Counts legal-move leaf nodes at `depth` reachable from `state`.
    /// Standard recursive perft; at depth 1 returns the legal-move count
    /// directly (a depth-0 multiply would be wasted work).
    static func perft(_ state: GameState, depth: Int) -> Int {
        if depth == 0 { return 1 }
        let moves = state.legalMoves()
        if depth == 1 { return moves.count }
        
        var total = 0
        for move in moves {
            total += perft(state.applying(move), depth: depth - 1)
        }
        return total
    }
}
