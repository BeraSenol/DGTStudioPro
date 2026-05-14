//
//  PerftTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 14/05/2026.
//

import Testing
@testable import DGTStudioPro

/// Perft (performance test) is the standard integrity check for chess
/// move generators: count the number of leaf nodes reachable through
/// legal moves at a fixed depth and compare against published reference
/// values. A mismatch points at a specific class of bug — Kiwipete
/// exercises castling and pins; Position 3 exercises EP and discovered
/// attacks; Position 4 exercises promotion edge cases under both
/// kingside-and-queenside castling rights; Position 5 stresses
/// promotion-with-capture; Position 6 stresses high branching factor
/// and middlegame positional complexity.
///
/// Reference values are the canonical Perft-suite numbers (chess-
/// programming.org), used by virtually every open-source engine to
/// certify move generation. The suite must run green before Phase 7's
/// move-generator portion is considered complete.
@Suite("Perft Move Generation Integrity")
struct PerftTests {
    
    // MARK: Perft Implementation
    
    /// Counts legal-move leaf nodes at `depth` reachable from `state`.
    /// Standard recursive Perft; at depth 1 returns the legal-move count
    /// directly (a depth-0 multiply would be wasted work).
    private func perft(_ state: GameState, depth: Int) -> Int {
        if depth == 0 { return 1 }
        let moves = state.legalMoves()
        if depth == 1 { return moves.count }
        
        var total = 0
        for move in moves {
            total += perft(state.applying(move), depth: depth - 1)
        }
        return total
    }
    
    // MARK: Reference Position FENs
    
    private static let kiwipete =
    "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -"
    private static let position3 =
    "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -"
    private static let position4 =
    "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2pP/R2Q1RK1 w kq -"
    private static let position5 =
    "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ -"
    private static let position6 =
    "r4rk1/1pp1qppp/p1np1n2/2b1p1b1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - -"
    
    // MARK: Depth-1 Smoke Test
    
    /// Quick sanity check across all six positions: depth-1 counts must
    /// match. Runs in milliseconds and catches direct generation bugs
    /// (missing castling moves, EP fan-out wrong, pawn promotion fan-out
    /// wrong, etc.) before the slower depth-4 tests are reached. A
    /// depth-1 failure here is much faster to diagnose than a depth-4
    /// failure deep in a sub-tree.
    @Test func allPositionsAtDepth1() throws {
        let cases: [(name: String, fen: String, expected: Int)] = [
            ("Starting",   FEN.startingString, 20),
            ("Kiwipete",   Self.kiwipete,      48),
            ("Position 3", Self.position3,     14),
            ("Position 4", Self.position4,      6),
            ("Position 5", Self.position5,     44),
            ("Position 6", Self.position6,     46),
        ]
        
        for testCase in cases {
            let state = GameState(try FEN(parsing: testCase.fen))
            let count = perft(state, depth: 1)
            #expect(
                count == testCase.expected,
                "\(testCase.name) depth-1: expected \(testCase.expected), got \(count)"
            )
        }
    }
    
    // MARK: Depth-4 Reference Counts
    
    /// Starting position — the most-cited reference value. Touches every
    /// piece type but exercises no edge cases directly (no captures, no
    /// castling, no EP, no promotion in the first four plies).
    @Test func startingPositionDepth4() {
        #expect(perft(.starting, depth: 4) == 197_281)
    }
    
    /// Kiwipete (the canonical "exercises everything" middlegame). Both
    /// sides retain castling rights, bishop pin diagonals are live, and
    /// the queen/knight have capture options — historically the position
    /// that catches the most common move-generator bugs.
    @Test func kiwipeteDepth4() throws {
        let state = GameState(try FEN(parsing: Self.kiwipete))
        #expect(perft(state, depth: 4) == 4_085_603)
    }
    
    /// Position 3 — sparse endgame on a near-empty board, chosen to
    /// exercise en passant capture and discovered attacks (the b-file
    /// rook battery and the kings on a5/h4 are geometrically arranged to
    /// produce many pinned-piece situations).
    @Test func position3Depth4() throws {
        let state = GameState(try FEN(parsing: Self.position3))
        #expect(perft(state, depth: 4) == 43_238)
    }
    
    /// Position 4 — promotion-heavy. White has a passed a7 pawn and black
    /// has passed pawns on b2 and g2 all racing to promote. Castling
    /// rights remain only for black. Exercises all four promotion targets
    /// across both colors interleaved with captures.
    @Test func position4Depth4() throws {
        let state = GameState(try FEN(parsing: Self.position4))
        #expect(perft(state, depth: 4) == 422_333)
    }
    
    /// Position 5 — white pawn on d7 ready to promote with capture
    /// possibilities to c8 or e8, plus a black knight on f2 creating
    /// discovered-attack threats against the white king's home square.
    /// Stresses promotion-with-capture interactions.
    @Test func position5Depth4() throws {
        let state = GameState(try FEN(parsing: Self.position5))
        #expect(perft(state, depth: 4) == 2_103_487)
    }
    
    /// Position 6 — dense middlegame with both sides castled kingside,
    /// no remaining castling rights, and both bishop pairs active. High
    /// branching factor (~46 moves per node) makes this the slowest
    /// position to run but also the broadest exerciser of central-piece
    /// interactions.
    @Test func position6Depth4() throws {
        let state = GameState(try FEN(parsing: Self.position6))
        #expect(perft(state, depth: 4) == 3_894_594)
    }
}
