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
    
    // MARK: Helpers
    private func knightMoves(in state: GameState, from square: Square) -> [Move] {
        state.pseudoLegalMoves().filter { $0.from == square }
    }
    
    private func makeState(
        position: Position,
        activeColor: PieceColor = .white
    ) -> GameState {
        GameState(
            position: position,
            activeColor: activeColor,
            castlingRights: .none,
            enPassantTarget: nil,
            halfmoveClock: 0,
            fullmoveNumber: 1
        )
    }
    
    // MARK: Mobility
    @Test func centralKnightHasEightMoves() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteKnight
        let moves = knightMoves(in: makeState(position: pos), from: Squares.d4)
        
        let targets: Set<Square> = [
            Squares.b3, Squares.b5, Squares.c2, Squares.c6,
            Squares.e2, Squares.e6, Squares.f3, Squares.f5
        ]
        #expect(moves.count == 8)
        #expect(Set(moves.map(\.to)) == targets)
    }
    
    @Test func cornerKnightOnA1HasTwoMoves() {
        var pos = Position.empty
        pos[Squares.a1] = .whiteKnight
        let moves = knightMoves(in: makeState(position: pos), from: Squares.a1)
        
        #expect(moves.count == 2)
        #expect(Set(moves.map(\.to)) == [Squares.b3, Squares.c2])
    }
    
    @Test func cornerKnightOnH8HasTwoMoves() {
        var pos = Position.empty
        pos[Squares.h8] = .whiteKnight
        let moves = knightMoves(in: makeState(position: pos), from: Squares.h8)
        
        #expect(moves.count == 2)
        #expect(Set(moves.map(\.to)) == [Squares.g6, Squares.f7])
    }
    
    @Test func edgeKnightOnA4HasFourMoves() {
        var pos = Position.empty
        pos[Squares.a4] = .whiteKnight
        let moves = knightMoves(in: makeState(position: pos), from: Squares.a4)
        
        #expect(moves.count == 4)
        #expect(Set(moves.map(\.to)) == [Squares.b2, Squares.b6, Squares.c3, Squares.c5])
    }
    
    @Test func edgeKnightOnH4HasFourMoves() {
        var pos = Position.empty
        pos[Squares.h4] = .whiteKnight
        let moves = knightMoves(in: makeState(position: pos), from: Squares.h4)
        
        #expect(moves.count == 4)
        #expect(Set(moves.map(\.to)) == [Squares.g2, Squares.g6, Squares.f3, Squares.f5])
    }
    
    // MARK: Wraparound (the dragon for knights)
    @Test func aFileKnightDoesNotWrapToHFile() {
        var pos = Position.empty
        pos[Squares.a1] = .whiteKnight
        // If wrap bug exists, knight would "see" h2 (a1+15) or g1 (a1+6) as targets
        pos[Squares.h2] = .blackPawn
        pos[Squares.g1] = .blackPawn
        let moves = knightMoves(in: makeState(position: pos), from: Squares.a1)
        
        #expect(moves.count == 2)
        #expect(!moves.contains { $0.to == Squares.h2 })
        #expect(!moves.contains { $0.to == Squares.g1 })
    }
    
    @Test func hFileKnightDoesNotWrapToAFile() {
        var pos = Position.empty
        pos[Squares.h1] = .whiteKnight
        // If wrap bug exists, knight would "see" a2 (h1+10) or b1 (h1-6 invalid, +17→a3)
        pos[Squares.a2] = .blackPawn
        pos[Squares.a3] = .blackPawn
        let moves = knightMoves(in: makeState(position: pos), from: Squares.h1)
        
        #expect(moves.count == 2)
        #expect(!moves.contains { $0.to == Squares.a2 })
        #expect(!moves.contains { $0.to == Squares.a3 })
    }
    
    // MARK: Captures and Blocking
    @Test func knightCapturesEnemyPiece() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteKnight
        pos[Squares.e6] = .blackRook
        pos[Squares.f5] = .blackPawn
        let moves = knightMoves(in: makeState(position: pos), from: Squares.d4)
        
        #expect(moves.count == 8)
        #expect(moves.contains { $0.to == Squares.e6 && $0.capturedPieceType == .rook })
        #expect(moves.contains { $0.to == Squares.f5 && $0.capturedPieceType == .pawn })
    }
    
    @Test func knightDoesNotCaptureOwnPiece() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteKnight
        pos[Squares.e6] = .whiteRook
        pos[Squares.f5] = .whitePawn
        let moves = knightMoves(in: makeState(position: pos), from: Squares.d4)
        
        #expect(moves.count == 6)
        #expect(!moves.contains { $0.to == Squares.e6 })
        #expect(!moves.contains { $0.to == Squares.f5 })
    }
    
    @Test func knightOnStartingPositionB1HasTwoMoves() {
        let moves = knightMoves(in: .starting, from: Squares.b1)
        
        // a3 and c3 — both empty in starting position. d2 blocked by own pawn.
        #expect(moves.count == 2)
        #expect(Set(moves.map(\.to)) == [Squares.a3, Squares.c3])
    }
    
    @Test func knightOnStartingPositionG1HasTwoMoves() {
        let moves = knightMoves(in: .starting, from: Squares.g1)
        
        #expect(moves.count == 2)
        #expect(Set(moves.map(\.to)) == [Squares.f3, Squares.h3])
    }
    
    // MARK: Black Mirror
    @Test func blackKnightMirrorsWhite() {
        var pos = Position.empty
        pos[Squares.d5] = .blackKnight
        let moves = knightMoves(
            in: makeState(position: pos, activeColor: .black),
            from: Squares.d5
        )
        
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
        // Will be superseded by Perft once sliders + king ship.
        #expect(GameState.starting.pseudoLegalMoves().count == 20)
    }
}
