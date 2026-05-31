//
//  KnightMoveGenerationTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/05/2026.
//

import Testing
@testable import DGTStudioPro

@Suite("Knight Pseudo-Legal Move Generation")
struct KnightMoveGenerationTests {
    
    // Helpers now live in Support/ChessTestSupport.swift.
    
    // MARK: Mobility
    @Test func centralKnightHasEightMoves() {
        let pos = Position.make { $0[Squares.d4] = .whiteKnight }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.d4)
        
        let targets: Set<Square> = [
            Squares.b3, Squares.b5, Squares.c2, Squares.c6,
            Squares.e2, Squares.e6, Squares.f3, Squares.f5
        ]
        #expect(moves.count == 8)
        #expect(Set(moves.map(\.to)) == targets)
    }
    
    @Test func cornerKnightOnA1HasTwoMoves() {
        let pos = Position.make { $0[Squares.a1] = .whiteKnight }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.a1)
        
        #expect(moves.count == 2)
        #expect(Set(moves.map(\.to)) == [Squares.b3, Squares.c2])
    }
    
    @Test func cornerKnightOnH8HasTwoMoves() {
        let pos = Position.make { $0[Squares.h8] = .whiteKnight }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.h8)
        
        #expect(moves.count == 2)
        #expect(Set(moves.map(\.to)) == [Squares.g6, Squares.f7])
    }
    
    @Test func edgeKnightOnA4HasFourMoves() {
        let pos = Position.make { $0[Squares.a4] = .whiteKnight }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.a4)
        
        #expect(moves.count == 4)
        #expect(Set(moves.map(\.to)) == [Squares.b2, Squares.b6, Squares.c3, Squares.c5])
    }
    
    @Test func edgeKnightOnH4HasFourMoves() {
        let pos = Position.make { $0[Squares.h4] = .whiteKnight }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.h4)
        
        #expect(moves.count == 4)
        #expect(Set(moves.map(\.to)) == [Squares.g2, Squares.g6, Squares.f3, Squares.f5])
    }
    
    // MARK: Wraparound (the dragon for knights)
    @Test func aFileKnightDoesNotWrapToHFile() {
        let pos = Position.make {
            $0[Squares.a1] = .whiteKnight
            // If wrap bug exists, knight would "see" h2 (a1+15) or g1 (a1+6) as targets
            $0[Squares.h2] = .blackPawn
            $0[Squares.g1] = .blackPawn
        }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.a1)
        
        #expect(moves.count == 2)
        #expect(!moves.contains { $0.to == Squares.h2 })
        #expect(!moves.contains { $0.to == Squares.g1 })
    }
    
    @Test func hFileKnightDoesNotWrapToAFile() {
        let pos = Position.make {
            $0[Squares.h1] = .whiteKnight
            // If wrap bug exists, knight would "see" a2 (h1+10) or a3 (h1+17) as targets
            $0[Squares.a2] = .blackPawn
            $0[Squares.a3] = .blackPawn
        }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.h1)
        
        #expect(moves.count == 2)
        #expect(!moves.contains { $0.to == Squares.a2 })
        #expect(!moves.contains { $0.to == Squares.a3 })
    }
    
    // MARK: Captures and Blocking
    @Test func knightCapturesEnemyPiece() {
        let pos = Position.make {
            $0[Squares.d4] = .whiteKnight
            $0[Squares.e6] = .blackRook
            $0[Squares.f5] = .blackPawn
        }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.d4)
        
        #expect(moves.count == 8)
        #expect(moves.contains { $0.to == Squares.e6 && $0.capturedPieceType == .rook })
        #expect(moves.contains { $0.to == Squares.f5 && $0.capturedPieceType == .pawn })
    }
    
    @Test func knightDoesNotCaptureOwnPiece() {
        let pos = Position.make {
            $0[Squares.d4] = .whiteKnight
            $0[Squares.e6] = .whiteRook
            $0[Squares.f5] = .whitePawn
        }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.d4)
        
        #expect(moves.count == 6)
        #expect(!moves.contains { $0.to == Squares.e6 })
        #expect(!moves.contains { $0.to == Squares.f5 })
    }
    
    @Test func knightOnStartingPositionB1HasTwoMoves() {
        let moves = GameState.starting.pseudoLegalMoves(from: Squares.b1)
        
        // a3 and c3 — both empty in starting position. d2 blocked by own pawn.
        #expect(moves.count == 2)
        #expect(Set(moves.map(\.to)) == [Squares.a3, Squares.c3])
    }
    
    @Test func knightOnStartingPositionG1HasTwoMoves() {
        let moves = GameState.starting.pseudoLegalMoves(from: Squares.g1)
        
        #expect(moves.count == 2)
        #expect(Set(moves.map(\.to)) == [Squares.f3, Squares.h3])
    }
    
    // MARK: Black Mirror
    @Test func blackKnightMirrorsWhite() {
        let pos = Position.make { $0[Squares.d5] = .blackKnight }
        let moves = GameState.test(pos, activeColor: .black)
            .pseudoLegalMoves(from: Squares.d5)
        
        let targets: Set<Square> = [
            Squares.b4, Squares.b6, Squares.c3, Squares.c7,
            Squares.e3, Squares.e7, Squares.f4, Squares.f6
        ]
        #expect(moves.count == 8)
        #expect(Set(moves.map(\.to)) == targets)
    }
    
    // MARK: Sanity Total (supersedes pawn file's 16-move test)
    @Test func startingPositionGeneratesTwentyMoves() {
        // 8 pawns × 2 (push + double push) + 2 knights × 2 moves = 20.
        // Superseded by Perft once sliders + king ship.
        #expect(GameState.starting.pseudoLegalMoves().count == 20)
    }
}
