//
//  SlidingMoveGenerationTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/05/2026.
//

import Testing
@testable import DGTStudioPro

@Suite("Sliding Pseudo-Legal Move Generation")
struct SlidingMoveGenerationTests {
    
    // MARK: Helpers
    private func slidingMoves(in state: GameState, from square: Square) -> [Move] {
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
    
    // MARK: Bishop
    @Test func centralBishopHasThirteenMoves() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteBishop
        let moves = slidingMoves(in: makeState(position: pos), from: Squares.d4)
        
        let expected: Set<Square> = [
            Squares.e5, Squares.f6, Squares.g7, Squares.h8,  // up-right
            Squares.c5, Squares.b6, Squares.a7,              // up-left
            Squares.e3, Squares.f2, Squares.g1,              // down-right
            Squares.c3, Squares.b2, Squares.a1               // down-left
        ]
        #expect(moves.count == 13)
        #expect(Set(moves.map(\.to)) == expected)
    }
    
    @Test func bishopBlockedByOwnPieceStopsBeforeIt() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteBishop
        pos[Squares.f6] = .whitePawn
        let moves = slidingMoves(in: makeState(position: pos), from: Squares.d4)
        
        // Up-right ray now stops at e5; f6/g7/h8 unreachable.
        let upRight = moves.filter {
            [Squares.e5, Squares.f6, Squares.g7, Squares.h8].contains($0.to)
        }
        #expect(upRight.count == 1)
        #expect(upRight.first?.to == Squares.e5)
    }
    
    @Test func bishopCapturesEnemyAndStops() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteBishop
        pos[Squares.f6] = .blackKnight
        let moves = slidingMoves(in: makeState(position: pos), from: Squares.d4)
        
        let upRight = moves.filter {
            [Squares.e5, Squares.f6, Squares.g7, Squares.h8].contains($0.to)
        }
        #expect(upRight.count == 2)
        #expect(upRight.contains { $0.to == Squares.f6 && $0.capturedPieceType == .knight })
        #expect(!upRight.contains { $0.to == Squares.g7 })
    }
    
    @Test func bishopOnA1DoesNotWraparound() {
        var pos = Position.empty
        pos[Squares.a1] = .whiteBishop
        pos[Squares.h2] = .blackPawn  // wraparound bait via the up-left ray a1+7=h1
        pos[Squares.h8] = .blackPawn  // legitimate end of up-right diagonal
        let moves = slidingMoves(in: makeState(position: pos), from: Squares.a1)
        
        // Only the up-right diagonal is reachable: b2..g7..h8 (capture).
        #expect(moves.count == 7)
        #expect(moves.contains { $0.to == Squares.h8 && $0.capturedPieceType == .pawn })
        #expect(!moves.contains { $0.to == Squares.h2 })
    }
    
    // MARK: Rook
    @Test func centralRookHasFourteenMoves() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteRook
        let moves = slidingMoves(in: makeState(position: pos), from: Squares.d4)
        
        #expect(moves.count == 14)
    }
    
    @Test func rookBlockedByOwnPieceStopsBeforeIt() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteRook
        pos[Squares.d7] = .whitePawn
        let moves = slidingMoves(in: makeState(position: pos), from: Squares.d4)
        
        let up = moves.filter {
            [Squares.d5, Squares.d6, Squares.d7, Squares.d8].contains($0.to)
        }
        #expect(Set(up.map(\.to)) == [Squares.d5, Squares.d6])
    }
    
    @Test func rookCapturesEnemyAndStops() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteRook
        pos[Squares.d7] = .blackKnight
        let moves = slidingMoves(in: makeState(position: pos), from: Squares.d4)
        
        let up = moves.filter {
            [Squares.d5, Squares.d6, Squares.d7, Squares.d8].contains($0.to)
        }
        #expect(up.count == 3)
        #expect(up.contains { $0.to == Squares.d7 && $0.capturedPieceType == .knight })
        #expect(!up.contains { $0.to == Squares.d8 })
    }
    
    @Test func rookOnH1DoesNotWraparoundAlongRank() {
        var pos = Position.empty
        pos[Squares.h1] = .whiteRook
        pos[Squares.a2] = .blackPawn  // would be reached via h1+1 wrap if file check failed
        let moves = slidingMoves(in: makeState(position: pos), from: Squares.h1)
        
        #expect(!moves.contains { $0.to == Squares.a2 })
        // 7 along rank 1 (g1..a1) + 7 up file h (h2..h8) = 14
        #expect(moves.count == 14)
    }
    
    // MARK: Queen
    @Test func centralQueenHasTwentySevenMoves() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteQueen
        let moves = slidingMoves(in: makeState(position: pos), from: Squares.d4)
        
        // Bishop 13 + Rook 14
        #expect(moves.count == 27)
    }
    
    @Test func queenStopsIndependentlyOnEachRay() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteQueen
        pos[Squares.d6] = .whitePawn   // blocks "up" ray at d6
        pos[Squares.f6] = .blackKnight // capturable on "up-right" ray
        let moves = slidingMoves(in: makeState(position: pos), from: Squares.d4)
        
        // Up: d5 only (own piece at d6 stops ray, d6 not included)
        #expect(moves.contains { $0.to == Squares.d5 })
        #expect(!moves.contains { $0.to == Squares.d6 })
        #expect(!moves.contains { $0.to == Squares.d7 })
        
        // Up-right: e5 + f6 capture, no g7
        #expect(moves.contains { $0.to == Squares.f6 && $0.capturedPieceType == .knight })
        #expect(!moves.contains { $0.to == Squares.g7 })
        
        // Other rays unaffected
        #expect(moves.contains { $0.to == Squares.h4 })  // right ray reaches h4
        #expect(moves.contains { $0.to == Squares.a1 })  // down-left reaches a1
    }
    
    // MARK: Black Mirror
    @Test func blackBishopMirrorsWhite() {
        var pos = Position.empty
        pos[Squares.d4] = .blackBishop
        let moves = slidingMoves(
            in: makeState(position: pos, activeColor: .black),
            from: Squares.d4
        )
        #expect(moves.count == 13)
    }
    
    @Test func blackRookMirrorsWhite() {
        var pos = Position.empty
        pos[Squares.d4] = .blackRook
        let moves = slidingMoves(
            in: makeState(position: pos, activeColor: .black),
            from: Squares.d4
        )
        #expect(moves.count == 14)
    }
    
    @Test func blackQueenMirrorsWhite() {
        var pos = Position.empty
        pos[Squares.d4] = .blackQueen
        let moves = slidingMoves(
            in: makeState(position: pos, activeColor: .black),
            from: Squares.d4
        )
        #expect(moves.count == 27)
    }
}
