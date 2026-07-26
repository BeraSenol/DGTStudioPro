//
//  GameTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/05/2026.
//

import Testing
@testable import DGTStudioPro

@Suite("Game — Construction and Navigation")
@MainActor
struct GameTests {
    
    // MARK: Helpers
    
    /// Minimal PGN with the given SAN move list. Tags are placeholders;
    /// `Game` doesn't read them, so test fidelity comes from `moves`.
    private static func makePGN(
        moves: [String],
        evaluations: [Evaluation?] = []
    ) -> PGN {
        PGN(
            event: "Test",
            site: "Test",
            white: "A",
            black: "B",
            moves: moves,
            evaluations: evaluations,
            result: .ongoing
        )
    }
    
    // MARK: Construction
    
    @Test func emptyGameStartsAndEndsAtZero() throws {
        let game = try Game(pgn: Self.makePGN(moves: []))
        #expect(game.currentPly == 0)
        #expect(game.states.count == 1)
        #expect(game.moves.isEmpty)
        #expect(!game.canAdvance)
        #expect(!game.canRetreat)
    }
    
    @Test func twoMoveGameOpensAtEnd() throws {
        let game = try Game(pgn: Self.makePGN(moves: ["e4", "e5"]))
        #expect(game.currentPly == 2)
        #expect(game.states.count == 3)
        #expect(game.moves.count == 2)
        #expect(game.canRetreat)
        #expect(!game.canAdvance)
    }
    
    @Test func stateArraysAreParallelAndCorrectlySized() throws {
        let game = try Game(pgn: Self.makePGN(
            moves: ["e4", "e5", "Nf3", "Nc6"]
        ))
        #expect(game.states.count == game.moves.count + 1)
        #expect(game.trackers.count == game.moves.count + 1)
    }
    
    @Test func malformedSANThrowsWithIndex() throws {
        let pgn = Self.makePGN(moves: ["e4", "garbage"])
        do {
            _ = try Game(pgn: pgn)
            Issue.record("Expected throw on malformed SAN")
        } catch let Game.BuildError.invalidMove(index, san, _) {
            #expect(index == 1)
            #expect(san == "garbage")
        } catch {
            Issue.record("Expected Game.BuildError.invalidMove, got \(error)")
        }
    }
    
    // MARK: Navigation
    
    @Test func advanceAndRetreatRespectBounds() throws {
        let game = try Game(pgn: Self.makePGN(moves: ["e4", "e5"]))
        // Open at end (ply 2). Advance should no-op.
        game.advance()
        #expect(game.currentPly == 2)
        
        game.retreat()
        game.retreat()
        #expect(game.currentPly == 0)
        
        // At start, retreat should no-op.
        game.retreat()
        #expect(game.currentPly == 0)
    }
    
    @Test func jumpClampsOutOfRangeValues() throws {
        let game = try Game(pgn: Self.makePGN(moves: ["e4", "e5"]))
        game.jump(to: -5)
        #expect(game.currentPly == 0)
        game.jump(to: 100)
        #expect(game.currentPly == 2)
        game.jump(to: 1)
        #expect(game.currentPly == 1)
    }
    
    @Test func toStartAndToEndShortcuts() throws {
        let game = try Game(pgn: Self.makePGN(moves: ["e4", "e5", "Nf3"]))
        game.toStart()
        #expect(game.currentPly == 0)
        game.toEnd()
        #expect(game.currentPly == 3)
    }
    
    // MARK: Derived State
    
    @Test func lastMoveAtPlyZeroIsNil() throws {
        let game = try Game(pgn: Self.makePGN(moves: ["e4"]))
        game.toStart()
        #expect(game.lastMove == nil)
    }
    
    @Test func lastMoveReflectsCurrentPly() throws {
        let game = try Game(pgn: Self.makePGN(moves: ["e4", "e5"]))
        game.jump(to: 1)
        #expect(game.lastMove == LastMove(from: Squares.e2, to: Squares.e4))
        game.jump(to: 2)
        #expect(game.lastMove == LastMove(from: Squares.e7, to: Squares.e5))
    }
    
    @Test func checkSquareReportedOnMatePosition() throws {
        // Scholar's mate — black king on e8 is mated by Qxf7.
        let game = try Game(pgn: Self.makePGN(
            moves: ["e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#"]
        ))
        game.toEnd()
        #expect(game.checkSquare == Squares.e8)
    }
    
    @Test func checkSquareIsNilWhenNotInCheck() throws {
        let game = try Game(pgn: Self.makePGN(moves: ["e4", "e5"]))
        #expect(game.checkSquare == nil)
    }
    
    @Test func currentFENMatchesStartingPositionAtPlyZero() throws {
        let game = try Game(pgn: Self.makePGN(moves: ["e4"]))
        game.toStart()
        #expect(game.currentFEN.string == FEN.startingString)
    }
    
    // MARK: Evaluation Pass-Through
    
    @Test func currentEvaluationIsNilAtPlyZero() throws {
        let game = try Game(pgn: Self.makePGN(
            moves: ["e4", "e5"],
            evaluations: [.centipawns(20), .centipawns(15)]
        ))
        game.toStart()
        #expect(game.currentEvaluation == nil)
    }
    
    @Test func currentEvaluationReflectsPGNAtPly() throws {
        let game = try Game(pgn: Self.makePGN(
            moves: ["e4", "e5"],
            evaluations: [.centipawns(20), .centipawns(15)]
        ))
        game.jump(to: 1)
        #expect(game.currentEvaluation == .centipawns(20))
        game.jump(to: 2)
        #expect(game.currentEvaluation == .centipawns(15))
    }
    
    @Test func currentEvaluationIsNilWhenGameNotAnalyzed() throws {
        let game = try Game(pgn: Self.makePGN(moves: ["e4", "e5"]))
        game.jump(to: 1)
        #expect(game.currentEvaluation == nil)
    }
}
