//
//  SpecialCheckmateTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 22/07/2026.
//

import Testing
@testable import DGTStudioPro

/// The D19′ mate-pattern classifier: smothered (knight check, king boxed by
/// its own men), back-rank (king on its own rank, rook/queen along it, walled
/// forward by its own pieces), and `nil` for an ordinary mate or a non-mate.
/// Pure over `GameState` — nonisolated, one FEN fixture per pattern.
@Suite("Special Checkmate — Classification")
struct SpecialCheckmateTests {
    
    private static func state(_ fen: String) throws -> GameState {
        try GameState(FEN(parsing: fen))
    }
    
    // MARK: Smothered
    
    @Test func cornerSmotheredMate() throws {
        // Kh8 boxed by Rg8, g7/h7 pawns; Nf7#. Two sides are board-edge walls.
        let state = try Self.state("6rk/5Npp/8/8/8/8/8/6K1 b - - 0 1")
        #expect(SpecialCheckmate.classify(state) == .smothered)
    }
    
    @Test func centralSmotheredMate() throws {
        // Ke4 walled on all eight sides by its own pawns; Nd6#.
        let state = try Self.state("8/8/3N4/3ppp2/3pkp2/3ppp2/8/K7 b - - 0 1")
        #expect(SpecialCheckmate.classify(state) == .smothered)
    }
    
    // MARK: Back Rank
    
    @Test func rookBackRankMate() throws {
        // Kg8 behind f7/g7/h7 pawns; Re8#.
        let state = try Self.state("4R1k1/5ppp/8/8/8/8/8/6K1 b - - 0 1")
        #expect(SpecialCheckmate.classify(state) == .backRank)
    }
    
    @Test func queenBackRankMate() throws {
        // Same wall, delivered along the rank by the queen.
        let state = try Self.state("4Q1k1/5ppp/8/8/8/8/8/6K1 b - - 0 1")
        #expect(SpecialCheckmate.classify(state) == .backRank)
    }
    
    // MARK: Ordinary mates and non-mates
    
    @Test func foolsMateIsNotSpecial() throws {
        // A diagonal queen mate — not a knight (so not smothered), and the
        // check isn't along the king's rank (so not back-rank).
        let state = try GameState.starting.replay(["f3", "e5", "g4", "Qh4#"])
        #expect(SpecialCheckmate.classify(state) == nil)
    }
    
    @Test func startingPositionIsNotAMate() {
        #expect(SpecialCheckmate.classify(.starting) == nil)
    }
    
    @Test func backRankShapeThatIsNotMateIsNil() throws {
        // Re8 checks, but with h7 empty the king escapes to h7 — not mate, so
        // no classification despite the back-rank shape (the `isCheckmate`
        // guard earns its keep).
        let state = try Self.state("4R1k1/5pp1/8/8/8/8/8/6K1 b - - 0 1")
        #expect(SpecialCheckmate.classify(state) == nil)
    }
}
