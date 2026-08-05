import Testing
@testable import DGTStudioPro

@Suite("King Pseudo-Legal Move Generation")
struct KingMoveGenerationTests {
    
    // Helpers (`GameState.test`, `pseudoLegalMoves(from:)`, `Position.make`)
    // live in Support/ChessTestSupport.swift, shared across the move-gen
    // suites.
    
    // MARK: Mobility
    @Test func centralKingHasEightMoves() {
        let pos = Position.make { $0[Squares.d4] = .whiteKing }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.d4)
        
        let expected: Set<Square> = [
            Squares.c3, Squares.c4, Squares.c5,
            Squares.d3,             Squares.d5,
            Squares.e3, Squares.e4, Squares.e5
        ]
        #expect(moves.count == 8)
        #expect(Set(moves.map(\.to)) == expected)
    }
    
    @Test func cornerKingOnA1HasThreeMoves() {
        let pos = Position.make { $0[Squares.a1] = .whiteKing }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.a1)
        
        #expect(moves.count == 3)
        #expect(Set(moves.map(\.to)) == [Squares.a2, Squares.b1, Squares.b2])
    }
    
    @Test func cornerKingOnH8HasThreeMoves() {
        let pos = Position.make { $0[Squares.h8] = .whiteKing }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.h8)
        
        #expect(moves.count == 3)
        #expect(Set(moves.map(\.to)) == [Squares.h7, Squares.g8, Squares.g7])
    }
    
    @Test func edgeKingOnA4HasFiveMoves() {
        let pos = Position.make { $0[Squares.a4] = .whiteKing }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.a4)
        
        #expect(moves.count == 5)
        #expect(Set(moves.map(\.to)) == [
            Squares.a3, Squares.a5, Squares.b3, Squares.b4, Squares.b5
        ])
    }
    
    // MARK: Wraparound
    @Test func aFileKingDoesNotWrapToHFile() {
        let pos = Position.make {
            $0[Squares.a4] = .whiteKing
            // Bait pawns on the h-file. With a1 = 0 rank-major indexing,
            // a4 − 1 = h3 and a4 + 7 = h4 are exactly the raw-offset targets a
            // missing file check would produce; h5 is a belt-and-braces extra.
            $0[Squares.h3] = .blackPawn
            $0[Squares.h4] = .blackPawn
            $0[Squares.h5] = .blackPawn
        }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.a4)
        
        #expect(moves.count == 5)
        #expect(!moves.contains { $0.to == Squares.h3 })
        #expect(!moves.contains { $0.to == Squares.h4 })
        #expect(!moves.contains { $0.to == Squares.h5 })
    }
    
    @Test func hFileKingDoesNotWrapToAFile() {
        let pos = Position.make {
            $0[Squares.h4] = .whiteKing
            // Mirror baits on the a-file: h4 − 7 = a4 and h4 + 1 = a5 are the
            // raw-offset wrap targets; a3 is a belt-and-braces extra.
            $0[Squares.a4] = .blackPawn
            $0[Squares.a5] = .blackPawn
            $0[Squares.a3] = .blackPawn
        }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.h4)
        
        #expect(moves.count == 5)
        #expect(!moves.contains { $0.to == Squares.a4 })
        #expect(!moves.contains { $0.to == Squares.a5 })
        #expect(!moves.contains { $0.to == Squares.a3 })
    }
    
    // MARK: Captures and Blocking
    @Test func kingCapturesEnemyPieces() {
        let pos = Position.make {
            $0[Squares.d4] = .whiteKing
            $0[Squares.e5] = .blackPawn
            $0[Squares.d3] = .blackKnight
        }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.d4)
        
        #expect(moves.count == 8)
        #expect(moves.contains { $0.to == Squares.e5 && $0.capturedPieceType == .pawn })
        #expect(moves.contains { $0.to == Squares.d3 && $0.capturedPieceType == .knight })
    }
    
    @Test func kingDoesNotCaptureOwnPiece() {
        let pos = Position.make {
            $0[Squares.d4] = .whiteKing
            $0[Squares.e5] = .whitePawn
            $0[Squares.d3] = .whiteKnight
        }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.d4)
        
        #expect(moves.count == 6)
        #expect(!moves.contains { $0.to == Squares.e5 })
        #expect(!moves.contains { $0.to == Squares.d3 })
    }
    
    @Test func kingOnStartingPositionHasNoMoves() {
        // e1 king is surrounded entirely by own pieces (d1 queen, f1 bishop,
        // d2/e2/f2 pawns). Pseudo-legal generation excludes castling for now.
        let moves = GameState.starting.pseudoLegalMoves(from: Squares.e1)
        #expect(moves.isEmpty)
    }
    
    // MARK: Black Mirror
    @Test func blackKingMirrorsWhite() {
        let pos = Position.make { $0[Squares.d5] = .blackKing }
        let moves = GameState.test(pos, activeColor: .black)
            .pseudoLegalMoves(from: Squares.d5)
        #expect(moves.count == 8)
    }
}
