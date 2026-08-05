import Testing
@testable import DGTStudioPro

@Suite("Pawn Pseudo-Legal Move Generation")
struct PawnMoveGenerationTests {
    
    // Helpers (`GameState.test`, `pseudoLegalMoves(from:)`, `Position.make`)
    // now live in Support/ChessTestSupport.swift, shared across the move-gen
    // suites.
    
    // MARK: Single & Double Push
    @Test func whitePawnOnStartRankHasSingleAndDoublePush() {
        let moves = GameState.starting.pseudoLegalMoves(from: Squares.e2)
        
        #expect(moves.count == 2)
        #expect(moves.contains { $0.to == Squares.e3 && !$0.isDoublePawnPush })
        #expect(moves.contains { $0.to == Squares.e4 &&  $0.isDoublePawnPush })
    }
    
    @Test func whitePawnOffStartRankHasOnlySinglePush() {
        let pos = Position.make { $0[Squares.e3] = .whitePawn }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.e3)
        
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.e4)
        #expect(moves.first?.isDoublePawnPush == false)
    }
    
    @Test func whitePawnSinglePushBlockedHasNoMoves() {
        let pos = Position.make {
            $0[Squares.e2] = .whitePawn
            $0[Squares.e3] = .blackPawn
        }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.e2)
        
        #expect(moves.isEmpty)
    }
    
    @Test func whitePawnDoublePushBlockedAtTwoStep() {
        let pos = Position.make {
            $0[Squares.e2] = .whitePawn
            $0[Squares.e4] = .blackPawn
        }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.e2)
        
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.e3)
    }
    
    @Test func blackPawnOnStartRankHasSingleAndDoublePush() {
        let pos = Position.make { $0[Squares.e7] = .blackPawn }
        let moves = GameState.test(pos, activeColor: .black)
            .pseudoLegalMoves(from: Squares.e7)
        
        #expect(moves.count == 2)
        #expect(moves.contains { $0.to == Squares.e6 && !$0.isDoublePawnPush })
        #expect(moves.contains { $0.to == Squares.e5 &&  $0.isDoublePawnPush })
    }
    
    // MARK: Captures
    @Test func whitePawnDiagonalCaptures() {
        let pos = Position.make {
            $0[Squares.e4] = .whitePawn
            $0[Squares.d5] = .blackPawn
            $0[Squares.f5] = .blackKnight
        }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.e4)
        
        // e5 push, dxc5 (pawn), fxe5 (knight)
        #expect(moves.count == 3)
        #expect(moves.contains { $0.to == Squares.d5 && $0.capturedPieceType == .pawn })
        #expect(moves.contains { $0.to == Squares.f5 && $0.capturedPieceType == .knight })
    }
    
    @Test func pawnDoesNotCaptureOwnPiece() {
        let pos = Position.make {
            $0[Squares.e4] = .whitePawn
            $0[Squares.d5] = .whitePawn
            $0[Squares.f5] = .whiteRook
        }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.e4)
        
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.e5)
    }
    
    @Test func aFilePawnDoesNotWrapToHFile() {
        let pos = Position.make {
            $0[Squares.a4] = .whitePawn
            $0[Squares.h5] = .blackPawn  // Phantom "left capture" target if wrap bug exists
        }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.a4)
        
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.a5)
    }
    
    @Test func hFilePawnDoesNotWrapToAFile() {
        let pos = Position.make {
            $0[Squares.h4] = .whitePawn
            $0[Squares.a5] = .blackPawn  // Phantom "right capture" target if wrap bug exists
        }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.h4)
        
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.h5)
    }
    
    // MARK: En Passant
    @Test func enPassantCaptureGenerated() throws {
        let pos = Position.make {
            $0[Squares.e5] = .whitePawn
            $0[Squares.d5] = .blackPawn  // Just moved d7-d5
        }
        let state = GameState.test(pos, enPassantTarget: Squares.d6)
        let moves = state.pseudoLegalMoves(from: Squares.e5)
        
        // e6 push + d6 EP capture
        #expect(moves.count == 2)
        let ep = try #require(moves.first { $0.isEnPassant })
        #expect(ep.to == Squares.d6)
        #expect(ep.capturedPieceType == .pawn)
        #expect(ep.capturedSquare == Squares.d5)
    }
    
    @Test func noEnPassantWhenTargetIsNil() {
        let pos = Position.make {
            $0[Squares.e5] = .whitePawn
            $0[Squares.d5] = .blackPawn
        }
        let moves = GameState.test(pos, enPassantTarget: nil)
            .pseudoLegalMoves(from: Squares.e5)
        
        // d6 is empty but not EP target — must not produce a phantom EP move
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.e6)
        #expect(!moves.contains { $0.isEnPassant })
    }
    
    @Test func blackEnPassantCaptureGenerated() throws {
        let pos = Position.make {
            $0[Squares.d4] = .blackPawn
            $0[Squares.e4] = .whitePawn  // Just moved e2-e4
        }
        let state = GameState.test(
            pos,
            activeColor: .black,
            enPassantTarget: Squares.e3
        )
        let moves = state.pseudoLegalMoves(from: Squares.d4)
        
        #expect(moves.count == 2)
        let ep = try #require(moves.first { $0.isEnPassant })
        #expect(ep.to == Squares.e3)
        #expect(ep.capturedSquare == Squares.e4)
    }
    
    // MARK: Promotion
    @Test func whitePawnPushPromotionEmitsFourMoves() {
        let pos = Position.make { $0[Squares.e7] = .whitePawn }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.e7)
        
        #expect(moves.count == 4)
        #expect(moves.allSatisfy { $0.to == Squares.e8 })
        let promotions = Set(moves.compactMap { $0.promotionType })
        #expect(promotions == Set([.queen, .rook, .bishop, .knight]))
    }
    
    @Test func whitePawnCapturePromotionEmitsFourMoves() {
        let pos = Position.make {
            $0[Squares.e7] = .whitePawn
            $0[Squares.e8] = .blackBishop  // Blocks push
            $0[Squares.d8] = .blackRook    // Capture target
        }
        let moves = GameState.test(pos).pseudoLegalMoves(from: Squares.e7)
        
        // 4 capture-promotions to d8; no push promotion (e8 blocked); no f8 (empty, not EP)
        #expect(moves.count == 4)
        #expect(moves.allSatisfy {
            $0.to == Squares.d8 && $0.capturedPieceType == .rook
        })
        let promotions = Set(moves.compactMap { $0.promotionType })
        #expect(promotions == Set([.queen, .rook, .bishop, .knight]))
    }
    
    @Test func blackPawnPromotionOnRankOne() {
        let pos = Position.make { $0[Squares.e2] = .blackPawn }
        let moves = GameState.test(pos, activeColor: .black)
            .pseudoLegalMoves(from: Squares.e2)
        
        #expect(moves.count == 4)
        #expect(moves.allSatisfy { $0.to == Squares.e1 })
    }
    
    // MARK: Total Count
    @Test func startingPositionGeneratesTwentyPseudoLegalMoves() {
        // 16 pawn moves (8 single push + 8 double push) + 4 knight moves
        // (Nb1 → a3/c3, Ng1 → f3/h3). Superseded by the Perft suite, which
        // exercises all six piece types across multiple positions.
        let count = GameState.starting.pseudoLegalMoves().count
        #expect(count == 20)
    }
}
