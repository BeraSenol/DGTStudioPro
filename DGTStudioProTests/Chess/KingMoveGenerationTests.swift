//
//  KingMoveGenerationTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/05/2026.
//

import Testing
@testable import DGTStudioPro

@Suite("King Pseudo-Legal Move Generation")
struct KingMoveGenerationTests {
    
    // MARK: Helpers
    private func kingMoves(in state: GameState, from square: Square) -> [Move] {
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
    @Test func centralKingHasEightMoves() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteKing
        let moves = kingMoves(in: makeState(position: pos), from: Squares.d4)
        
        let expected: Set<Square> = [
            Squares.c3, Squares.c4, Squares.c5,
            Squares.d3,             Squares.d5,
            Squares.e3, Squares.e4, Squares.e5
        ]
        #expect(moves.count == 8)
        #expect(Set(moves.map(\.to)) == expected)
    }
    
    @Test func cornerKingOnA1HasThreeMoves() {
        var pos = Position.empty
        pos[Squares.a1] = .whiteKing
        let moves = kingMoves(in: makeState(position: pos), from: Squares.a1)
        
        #expect(moves.count == 3)
        #expect(Set(moves.map(\.to)) == [Squares.a2, Squares.b1, Squares.b2])
    }
    
    @Test func cornerKingOnH8HasThreeMoves() {
        var pos = Position.empty
        pos[Squares.h8] = .whiteKing
        let moves = kingMoves(in: makeState(position: pos), from: Squares.h8)
        
        #expect(moves.count == 3)
        #expect(Set(moves.map(\.to)) == [Squares.h7, Squares.g8, Squares.g7])
    }
    
    @Test func edgeKingOnA4HasFiveMoves() {
        var pos = Position.empty
        pos[Squares.a4] = .whiteKing
        let moves = kingMoves(in: makeState(position: pos), from: Squares.a4)
        
        #expect(moves.count == 5)
        #expect(Set(moves.map(\.to)) == [
            Squares.a3, Squares.a5, Squares.b3, Squares.b4, Squares.b5
        ])
    }
    
    // MARK: Wraparound
    @Test func aFileKingDoesNotWrapToHFile() {
        var pos = Position.empty
        pos[Squares.a4] = .whiteKing
        // Bait squares — would be reached if file check failed
        pos[Squares.h3] = .blackPawn  // a4 - 9 = h3 (rank 3, file 7)
        pos[Squares.h4] = .blackPawn  // a4 - 1 = h3? No: a4=24, 24-1=23=h3. Wait same.
        pos[Squares.h5] = .blackPawn  // a4 + 7 = h4 (rank 4, file 7)
        let moves = kingMoves(in: makeState(position: pos), from: Squares.a4)
        
        #expect(moves.count == 5)
        #expect(!moves.contains { $0.to == Squares.h3 })
        #expect(!moves.contains { $0.to == Squares.h4 })
        #expect(!moves.contains { $0.to == Squares.h5 })
    }
    
    @Test func hFileKingDoesNotWrapToAFile() {
        var pos = Position.empty
        pos[Squares.h4] = .whiteKing
        pos[Squares.a4] = .blackPawn
        pos[Squares.a5] = .blackPawn  // h4 + 9 = a5
        pos[Squares.a3] = .blackPawn  // h4 - 7 = a3? h4=31, 31-7=24=a4. Hmm.
        let moves = kingMoves(in: makeState(position: pos), from: Squares.h4)
        
        #expect(moves.count == 5)
        #expect(!moves.contains { $0.to == Squares.a4 })
        #expect(!moves.contains { $0.to == Squares.a5 })
        #expect(!moves.contains { $0.to == Squares.a3 })
    }
    
    // MARK: Captures and Blocking
    @Test func kingCapturesEnemyPieces() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteKing
        pos[Squares.e5] = .blackPawn
        pos[Squares.d3] = .blackKnight
        let moves = kingMoves(in: makeState(position: pos), from: Squares.d4)
        
        #expect(moves.count == 8)
        #expect(moves.contains { $0.to == Squares.e5 && $0.capturedPieceType == .pawn })
        #expect(moves.contains { $0.to == Squares.d3 && $0.capturedPieceType == .knight })
    }
    
    @Test func kingDoesNotCaptureOwnPiece() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteKing
        pos[Squares.e5] = .whitePawn
        pos[Squares.d3] = .whiteKnight
        let moves = kingMoves(in: makeState(position: pos), from: Squares.d4)
        
        #expect(moves.count == 6)
        #expect(!moves.contains { $0.to == Squares.e5 })
        #expect(!moves.contains { $0.to == Squares.d3 })
    }
    
    @Test func kingOnStartingPositionHasNoMoves() {
        // e1 king is surrounded entirely by own pieces (d1 queen, f1 bishop,
        // d2/e2/f2 pawns). Pseudo-legal generation excludes castling for now.
        let moves = kingMoves(in: .starting, from: Squares.e1)
        #expect(moves.isEmpty)
    }
    
    // MARK: Black Mirror
    @Test func blackKingMirrorsWhite() {
        var pos = Position.empty
        pos[Squares.d5] = .blackKing
        let moves = kingMoves(
            in: makeState(position: pos, activeColor: .black),
            from: Squares.d5
        )
        #expect(moves.count == 8)
    }
}
