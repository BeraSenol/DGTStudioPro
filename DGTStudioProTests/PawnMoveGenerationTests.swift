//
//  PawnMoveGenerationTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/05/2026.
//

//
//  PawnMoveGenerationTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/05/2026.
//

import Testing
@testable import DGTStudioPro

@Suite("Pawn Pseudo-Legal Move Generation")
struct PawnMoveGenerationTests {
    
    // MARK: Helpers
    private func pawnMoves(in state: GameState, from square: Square) -> [Move] {
        state.pseudoLegalMoves().filter { $0.from == square }
    }
    
    private func makeState(
        position: Position,
        activeColor: PieceColor = .white,
        enPassantTarget: Square? = nil
    ) -> GameState {
        GameState(
            position: position,
            activeColor: activeColor,
            castlingRights: .none,
            enPassantTarget: enPassantTarget,
            halfmoveClock: 0,
            fullmoveNumber: 1
        )
    }
    
    // MARK: Single & Double Push
    @Test func whitePawnOnStartRankHasSingleAndDoublePush() {
        let moves = pawnMoves(in: .starting, from: Squares.e2)
        
        #expect(moves.count == 2)
        #expect(moves.contains { $0.to == Squares.e3 && !$0.isDoublePawnPush })
        #expect(moves.contains { $0.to == Squares.e4 &&  $0.isDoublePawnPush })
    }
    
    @Test func whitePawnOffStartRankHasOnlySinglePush() {
        var pos = Position.empty
        pos[Squares.e3] = .whitePawn
        let moves = pawnMoves(in: makeState(position: pos), from: Squares.e3)
        
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.e4)
        #expect(moves.first?.isDoublePawnPush == false)
    }
    
    @Test func whitePawnSinglePushBlockedHasNoMoves() {
        var pos = Position.empty
        pos[Squares.e2] = .whitePawn
        pos[Squares.e3] = .blackPawn
        let moves = pawnMoves(in: makeState(position: pos), from: Squares.e2)
        
        #expect(moves.isEmpty)
    }
    
    @Test func whitePawnDoublePushBlockedAtTwoStep() {
        var pos = Position.empty
        pos[Squares.e2] = .whitePawn
        pos[Squares.e4] = .blackPawn
        let moves = pawnMoves(in: makeState(position: pos), from: Squares.e2)
        
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.e3)
    }
    
    @Test func blackPawnOnStartRankHasSingleAndDoublePush() {
        var pos = Position.empty
        pos[Squares.e7] = .blackPawn
        let moves = pawnMoves(
            in: makeState(position: pos, activeColor: .black),
            from: Squares.e7
        )
        
        #expect(moves.count == 2)
        #expect(moves.contains { $0.to == Squares.e6 && !$0.isDoublePawnPush })
        #expect(moves.contains { $0.to == Squares.e5 &&  $0.isDoublePawnPush })
    }
    
    // MARK: Captures
    @Test func whitePawnDiagonalCaptures() {
        var pos = Position.empty
        pos[Squares.e4] = .whitePawn
        pos[Squares.d5] = .blackPawn
        pos[Squares.f5] = .blackKnight
        let moves = pawnMoves(in: makeState(position: pos), from: Squares.e4)
        
        // e5 push, dxc5 (pawn), fxe5 (knight)
        #expect(moves.count == 3)
        #expect(moves.contains { $0.to == Squares.d5 && $0.capturedPieceType == .pawn })
        #expect(moves.contains { $0.to == Squares.f5 && $0.capturedPieceType == .knight })
    }
    
    @Test func pawnDoesNotCaptureOwnPiece() {
        var pos = Position.empty
        pos[Squares.e4] = .whitePawn
        pos[Squares.d5] = .whitePawn
        pos[Squares.f5] = .whiteRook
        let moves = pawnMoves(in: makeState(position: pos), from: Squares.e4)
        
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.e5)
    }
    
    @Test func aFilePawnDoesNotWrapToHFile() {
        var pos = Position.empty
        pos[Squares.a4] = .whitePawn
        pos[Squares.h5] = .blackPawn  // Phantom "left capture" target if wrap bug exists
        let moves = pawnMoves(in: makeState(position: pos), from: Squares.a4)
        
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.a5)
    }
    
    @Test func hFilePawnDoesNotWrapToAFile() {
        var pos = Position.empty
        pos[Squares.h4] = .whitePawn
        pos[Squares.a5] = .blackPawn  // Phantom "right capture" target if wrap bug exists
        let moves = pawnMoves(in: makeState(position: pos), from: Squares.h4)
        
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.h5)
    }
    
    // MARK: En Passant
    @Test func enPassantCaptureGenerated() throws {
        var pos = Position.empty
        pos[Squares.e5] = .whitePawn
        pos[Squares.d5] = .blackPawn  // Just moved d7-d5
        let state = makeState(position: pos, enPassantTarget: Squares.d6)
        let moves = pawnMoves(in: state, from: Squares.e5)
        
        // e6 push + d6 EP capture
        #expect(moves.count == 2)
        let ep = try #require(moves.first { $0.isEnPassant })
        #expect(ep.to == Squares.d6)
        #expect(ep.capturedPieceType == .pawn)
        #expect(ep.capturedSquare == Squares.d5)
    }
    
    @Test func noEnPassantWhenTargetIsNil() {
        var pos = Position.empty
        pos[Squares.e5] = .whitePawn
        pos[Squares.d5] = .blackPawn
        let moves = pawnMoves(
            in: makeState(position: pos, enPassantTarget: nil),
            from: Squares.e5
        )
        
        // d6 is empty but not EP target — must not produce a phantom EP move
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.e6)
        #expect(!moves.contains { $0.isEnPassant })
    }
    
    @Test func blackEnPassantCaptureGenerated() throws {
        var pos = Position.empty
        pos[Squares.d4] = .blackPawn
        pos[Squares.e4] = .whitePawn  // Just moved e2-e4
        let state = makeState(
            position: pos,
            activeColor: .black,
            enPassantTarget: Squares.e3
        )
        let moves = pawnMoves(in: state, from: Squares.d4)
        
        #expect(moves.count == 2)
        let ep = try #require(moves.first { $0.isEnPassant })
        #expect(ep.to == Squares.e3)
        #expect(ep.capturedSquare == Squares.e4)
    }
    
    // MARK: Promotion
    @Test func whitePawnPushPromotionEmitsFourMoves() {
        var pos = Position.empty
        pos[Squares.e7] = .whitePawn
        let moves = pawnMoves(in: makeState(position: pos), from: Squares.e7)
        
        #expect(moves.count == 4)
        #expect(moves.allSatisfy { $0.to == Squares.e8 })
        let promotions = Set(moves.compactMap { $0.promotionType })
        #expect(promotions == Set([.queen, .rook, .bishop, .knight]))
    }
    
    @Test func whitePawnCapturePromotionEmitsFourMoves() {
        var pos = Position.empty
        pos[Squares.e7] = .whitePawn
        pos[Squares.e8] = .blackBishop  // Blocks push
        pos[Squares.d8] = .blackRook    // Capture target
        let moves = pawnMoves(in: makeState(position: pos), from: Squares.e7)
        
        // 4 capture-promotions to d8; no push promotion (e8 blocked); no f8 (empty, not EP)
        #expect(moves.count == 4)
        #expect(moves.allSatisfy {
            $0.to == Squares.d8 && $0.capturedPieceType == .rook
        })
        let promotions = Set(moves.compactMap { $0.promotionType })
        #expect(promotions == Set([.queen, .rook, .bishop, .knight]))
    }
    
    @Test func blackPawnPromotionOnRankOne() {
        var pos = Position.empty
        pos[Squares.e2] = .blackPawn
        let moves = pawnMoves(
            in: makeState(position: pos, activeColor: .black),
            from: Squares.e2
        )
        
        #expect(moves.count == 4)
        #expect(moves.allSatisfy { $0.to == Squares.e1 })
    }
    
    // MARK: Total Count
    @Test func startingPositionGeneratesSixteenWhitePawnMoves() {
        // Phase 7a only emits pawn moves. Other pieces will add to this in subsequent
        // deliverables; this test will be superseded by the Perft suite once the
        // generator is complete.
        let count = GameState.starting.pseudoLegalMoves().count
        #expect(count == 16)  // 8 pawns × 2 (single + double push)
    }
}
