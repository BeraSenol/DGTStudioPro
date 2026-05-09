//
//  PositionAttackTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/05/2026.
//

import Testing
@testable import DGTStudioPro

@Suite("Position Attack Detection")
struct PositionAttackTests {
    
    // MARK: Pawn Attacks
    @Test func whitePawnAttacksUpDiagonals() {
        var pos = Position.empty
        pos[Squares.e4] = .whitePawn
        
        #expect(pos.isSquareAttacked(Squares.d5, by: .white))
        #expect(pos.isSquareAttacked(Squares.f5, by: .white))
        // Pawns do NOT attack forward
        #expect(!pos.isSquareAttacked(Squares.e5, by: .white))
        // Pawns do NOT attack backward
        #expect(!pos.isSquareAttacked(Squares.d3, by: .white))
        #expect(!pos.isSquareAttacked(Squares.f3, by: .white))
    }
    
    @Test func blackPawnAttacksDownDiagonals() {
        var pos = Position.empty
        pos[Squares.e5] = .blackPawn
        
        #expect(pos.isSquareAttacked(Squares.d4, by: .black))
        #expect(pos.isSquareAttacked(Squares.f4, by: .black))
        #expect(!pos.isSquareAttacked(Squares.e4, by: .black))
        #expect(!pos.isSquareAttacked(Squares.d6, by: .black))
    }
    
    @Test func pawnAttackDoesNotWraparound() {
        var pos = Position.empty
        pos[Squares.a4] = .whitePawn
        // h5 is not attacked despite a4 - 9 = h2 arithmetic; file diff catches the wrap.
        #expect(!pos.isSquareAttacked(Squares.h5, by: .white))
        // Legitimate attack: b5
        #expect(pos.isSquareAttacked(Squares.b5, by: .white))
    }
    
    // MARK: Knight Attacks
    @Test func knightAttacksAllEightSquares() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteKnight
        
        let attacked: [Square] = [
            Squares.b3, Squares.b5, Squares.c2, Squares.c6,
            Squares.e2, Squares.e6, Squares.f3, Squares.f5
        ]
        for sq in attacked {
            #expect(pos.isSquareAttacked(sq, by: .white), "expected \(sq.algebraicNotation) attacked")
        }
    }
    
    @Test func knightAttackDoesNotWraparound() {
        var pos = Position.empty
        pos[Squares.a1] = .whiteKnight
        // Wraparound bait: file-7 squares should not be reported as attacked
        #expect(!pos.isSquareAttacked(Squares.h2, by: .white))
        #expect(!pos.isSquareAttacked(Squares.g1, by: .white))
        // Legitimate: b3, c2
        #expect(pos.isSquareAttacked(Squares.b3, by: .white))
        #expect(pos.isSquareAttacked(Squares.c2, by: .white))
    }
    
    // MARK: King Attacks
    @Test func kingAttacksAllEightNeighbors() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteKing
        
        let attacked: [Square] = [
            Squares.c3, Squares.c4, Squares.c5,
            Squares.d3,             Squares.d5,
            Squares.e3, Squares.e4, Squares.e5
        ]
        for sq in attacked {
            #expect(pos.isSquareAttacked(sq, by: .white))
        }
        // Two squares away: not attacked
        #expect(!pos.isSquareAttacked(Squares.d6, by: .white))
        #expect(!pos.isSquareAttacked(Squares.f4, by: .white))
    }
    
    @Test func kingAttackDoesNotWraparound() {
        var pos = Position.empty
        pos[Squares.a4] = .whiteKing
        #expect(!pos.isSquareAttacked(Squares.h3, by: .white))
        #expect(!pos.isSquareAttacked(Squares.h4, by: .white))
        #expect(!pos.isSquareAttacked(Squares.h5, by: .white))
    }
    
    // MARK: Sliding Attacks — Rook
    @Test func rookAttacksAlongRankAndFile() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteRook
        
        #expect(pos.isSquareAttacked(Squares.d8, by: .white))
        #expect(pos.isSquareAttacked(Squares.d1, by: .white))
        #expect(pos.isSquareAttacked(Squares.a4, by: .white))
        #expect(pos.isSquareAttacked(Squares.h4, by: .white))
        // Diagonal: not attacked by rook
        #expect(!pos.isSquareAttacked(Squares.e5, by: .white))
    }
    
    @Test func rookAttackBlockedByPiece() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteRook
        pos[Squares.d6] = .whitePawn  // blocks ray
        // d6 itself: blocked by own piece — ray returns false on friendly type-mismatch
        #expect(!pos.isSquareAttacked(Squares.d6, by: .white))
        // d7 / d8: behind the blocker, unattacked
        #expect(!pos.isSquareAttacked(Squares.d7, by: .white))
        #expect(!pos.isSquareAttacked(Squares.d8, by: .white))
        // d5: in front of the blocker, still attacked
        #expect(pos.isSquareAttacked(Squares.d5, by: .white))
    }
    
    @Test func rookAttackBlockedByEnemyNonSlider() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteRook
        pos[Squares.d6] = .blackKnight
        // d6 itself: attacked (capturable)
        #expect(pos.isSquareAttacked(Squares.d6, by: .white))
        // d7: knight blocks the ray, so not attacked
        #expect(!pos.isSquareAttacked(Squares.d7, by: .white))
    }
    
    @Test func rookAttackDoesNotWraparoundAlongRank() {
        var pos = Position.empty
        pos[Squares.h1] = .whiteRook
        // h1+1 wraps to a2 if file check fails
        #expect(!pos.isSquareAttacked(Squares.a2, by: .white))
        // Legitimate: g1 along rank 1
        #expect(pos.isSquareAttacked(Squares.g1, by: .white))
    }
    
    // MARK: Sliding Attacks — Bishop
    @Test func bishopAttacksAlongDiagonals() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteBishop
        
        #expect(pos.isSquareAttacked(Squares.h8, by: .white))
        #expect(pos.isSquareAttacked(Squares.a1, by: .white))
        #expect(pos.isSquareAttacked(Squares.a7, by: .white))
        #expect(pos.isSquareAttacked(Squares.g1, by: .white))
        // Orthogonal: not attacked by bishop
        #expect(!pos.isSquareAttacked(Squares.d8, by: .white))
        #expect(!pos.isSquareAttacked(Squares.h4, by: .white))
    }
    
    @Test func bishopAttackBlocked() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteBishop
        pos[Squares.f6] = .whitePawn  // blocks up-right diagonal
        #expect(!pos.isSquareAttacked(Squares.g7, by: .white))
        #expect(!pos.isSquareAttacked(Squares.h8, by: .white))
        #expect(pos.isSquareAttacked(Squares.e5, by: .white))
    }
    
    // MARK: Sliding Attacks — Queen
    @Test func queenAttacksOrthogonalAndDiagonal() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteQueen
        
        #expect(pos.isSquareAttacked(Squares.d8, by: .white))   // file
        #expect(pos.isSquareAttacked(Squares.h4, by: .white))   // rank
        #expect(pos.isSquareAttacked(Squares.h8, by: .white))   // diagonal
        #expect(pos.isSquareAttacked(Squares.a1, by: .white))   // diagonal
        // Knight-jump squares (not queen lines): unattacked
        #expect(!pos.isSquareAttacked(Squares.f5, by: .white))
        #expect(!pos.isSquareAttacked(Squares.e6, by: .white))
    }
    
    // MARK: Color Discrimination
    @Test func attackerColorIsRespected() {
        var pos = Position.empty
        pos[Squares.d4] = .whiteRook
        // d8 is attacked by white but NOT by black (no black piece exists)
        #expect(pos.isSquareAttacked(Squares.d8, by: .white))
        #expect(!pos.isSquareAttacked(Squares.d8, by: .black))
    }
    
    @Test func emptyBoardHasNoAttacks() {
        let pos = Position.empty
        #expect(!pos.isSquareAttacked(Squares.e4, by: .white))
        #expect(!pos.isSquareAttacked(Squares.e4, by: .black))
    }
    
    // MARK: Real-World Sanity
    @Test func startingPositionAttackProfile() {
        let pos = Position.starting
        // White attacks rank 3 squares via pawns (b3, c3, d3, ..., g3)
        // and via knights from b1/g1 (a3, c3, f3, h3)
        #expect(pos.isSquareAttacked(Squares.a3, by: .white))   // knight from b1
        #expect(pos.isSquareAttacked(Squares.c3, by: .white))   // knight b1 + pawns b2/d2
        #expect(pos.isSquareAttacked(Squares.f3, by: .white))   // knight g1 + pawns e2/g2
        // Black mirror: rank 6 attacked by black
        #expect(pos.isSquareAttacked(Squares.a6, by: .black))
        #expect(pos.isSquareAttacked(Squares.c6, by: .black))
        // White's own back rank: not attacked by white (pawns block, sliders don't reach)
        #expect(!pos.isSquareAttacked(Squares.e1, by: .white))
        // White's e4/e5: e4 not attacked by either side; e5 not attacked by white pawns
        #expect(!pos.isSquareAttacked(Squares.e4, by: .white))
        #expect(!pos.isSquareAttacked(Squares.e4, by: .black))
    }
}
