//
//  GameStateApplyingTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 10/05/2026.
//

import Testing
@testable import DGTStudioPro

@Suite("GameState Applying")
struct GameStateApplyingTests {
    
    // MARK: Helpers
    
    private func makeState(
        position: Position,
        activeColor: PieceColor = .white,
        castlingRights: CastlingRights = .none,
        enPassantTarget: Square? = nil,
        halfmoveClock: Int = 0,
        fullmoveNumber: Int = 1
    ) -> GameState {
        GameState(
            position: position,
            activeColor: activeColor,
            castlingRights: castlingRights,
            enPassantTarget: enPassantTarget,
            halfmoveClock: halfmoveClock,
            fullmoveNumber: fullmoveNumber
        )
    }
    
    /// Standard "two kings + pieces under test" position.
    private func minimalPosition(_ extras: (inout Position) -> Void) -> Position {
        var pos = Position.empty
        pos[Squares.e1] = .whiteKing
        pos[Squares.e8] = .blackKing
        extras(&pos)
        return pos
    }
    
    // MARK: Active Color
    
    @Test func activeColorFlipsAfterWhiteMove() {
        let next = GameState.starting.applying(
            .make(from: Squares.e2, to: Squares.e4,
                  pieceType: .pawn, pieceColor: .white,
                  isDoublePawnPush: true)
        )
        #expect(next.activeColor == .black)
    }
    
    @Test func activeColorFlipsAfterBlackMove() {
        let state = makeState(
            position: Position.starting,
            activeColor: .black,
            castlingRights: .all
        )
        let next = state.applying(
            .make(from: Squares.e7, to: Squares.e5,
                  pieceType: .pawn, pieceColor: .black,
                  isDoublePawnPush: true)
        )
        #expect(next.activeColor == .white)
    }
    
    // MARK: En Passant Target
    
    @Test func doublePawnPushSetsEPTarget() {
        let next = GameState.starting.applying(
            .make(from: Squares.e2, to: Squares.e4,
                  pieceType: .pawn, pieceColor: .white,
                  isDoublePawnPush: true)
        )
        #expect(next.enPassantTarget == Squares.e3)
    }
    
    @Test func blackDoublePawnPushSetsEPTarget() {
        let state = makeState(
            position: Position.starting,
            activeColor: .black,
            castlingRights: .all
        )
        let next = state.applying(
            .make(from: Squares.d7, to: Squares.d5,
                  pieceType: .pawn, pieceColor: .black,
                  isDoublePawnPush: true)
        )
        #expect(next.enPassantTarget == Squares.d6)
    }
    
    @Test func nonDoublePushClearsEPTarget() {
        // Start with an EP target set; any move that's not a double push clears it.
        let state = makeState(
            position: Position.starting,
            castlingRights: .all,
            enPassantTarget: Squares.e6
        )
        let next = state.applying(
            .make(from: Squares.g1, to: Squares.f3,
                  pieceType: .knight, pieceColor: .white)
        )
        #expect(next.enPassantTarget == nil)
    }
    
    // MARK: Castling Rights — King Moves
    
    @Test func kingMoveRevokesBothColorRights() {
        let pos = minimalPosition { _ in }
        let state = makeState(position: pos, castlingRights: .all)
        let next = state.applying(
            .make(from: Squares.e1, to: Squares.e2,
                  pieceType: .king, pieceColor: .white)
        )
        // White rights gone, black untouched.
        #expect(!next.castlingRights.whiteKingSide)
        #expect(!next.castlingRights.whiteQueenSide)
        #expect(next.castlingRights.blackKingSide)
        #expect(next.castlingRights.blackQueenSide)
    }
    
    @Test func castlingItselfRevokesBothRights() {
        let pos = minimalPosition { $0[Squares.h1] = .whiteRook }
        let state = makeState(position: pos, castlingRights: .all)
        let next = state.applying(
            .make(from: Squares.e1, to: Squares.g1,
                  pieceType: .king, pieceColor: .white,
                  isCastling: true)
        )
        #expect(!next.castlingRights.whiteKingSide)
        #expect(!next.castlingRights.whiteQueenSide)
    }
    
    // MARK: Castling Rights — Rook Moves
    
    @Test func kingsideRookMoveRevokesKingsideOnly() {
        let pos = minimalPosition { $0[Squares.h1] = .whiteRook }
        let state = makeState(position: pos, castlingRights: .all)
        let next = state.applying(
            .make(from: Squares.h1, to: Squares.h4,
                  pieceType: .rook, pieceColor: .white)
        )
        #expect(!next.castlingRights.whiteKingSide)
        #expect(next.castlingRights.whiteQueenSide)
    }
    
    @Test func queensideRookMoveRevokesQueensideOnly() {
        let pos = minimalPosition { $0[Squares.a1] = .whiteRook }
        let state = makeState(position: pos, castlingRights: .all)
        let next = state.applying(
            .make(from: Squares.a1, to: Squares.a4,
                  pieceType: .rook, pieceColor: .white)
        )
        #expect(next.castlingRights.whiteKingSide)
        #expect(!next.castlingRights.whiteQueenSide)
    }
    
    @Test func nonHomeRookMoveRevokesNothing() {
        // A rook elsewhere (e.g. h4) doesn't affect home-rook rights.
        let pos = minimalPosition {
            $0[Squares.h1] = .whiteRook
            $0[Squares.h4] = .whiteRook
        }
        let state = makeState(position: pos, castlingRights: .all)
        let next = state.applying(
            .make(from: Squares.h4, to: Squares.h5,
                  pieceType: .rook, pieceColor: .white)
        )
        #expect(next.castlingRights.whiteKingSide)
        #expect(next.castlingRights.whiteQueenSide)
    }
    
    // MARK: Castling Rights — Captures
    
    @Test func capturingOnH8RevokesBlackKingside() {
        let pos = minimalPosition {
            $0[Squares.h8] = .blackRook
            $0[Squares.h1] = .whiteRook
        }
        let state = makeState(position: pos, castlingRights: .all)
        let next = state.applying(
            .make(from: Squares.h1, to: Squares.h8,
                  pieceType: .rook, pieceColor: .white,
                  capturedPieceType: .rook)
        )
        // White's own kingside revoked (rook left h1); black's kingside revoked (rook captured on h8).
        #expect(!next.castlingRights.whiteKingSide)
        #expect(!next.castlingRights.blackKingSide)
    }
    
    @Test func capturingOnA1RevokesWhiteQueenside() {
        let pos = minimalPosition {
            $0[Squares.a1] = .whiteRook
            $0[Squares.a8] = .blackRook
        }
        let state = makeState(
            position: pos,
            activeColor: .black,
            castlingRights: .all
        )
        let next = state.applying(
            .make(from: Squares.a8, to: Squares.a1,
                  pieceType: .rook, pieceColor: .black,
                  capturedPieceType: .rook)
        )
        #expect(!next.castlingRights.whiteQueenSide)
        #expect(!next.castlingRights.blackQueenSide)  // black rook left a8
    }
    
    // MARK: Halfmove Clock
    
    @Test func pawnMoveResetsClock() {
        let pos = minimalPosition { $0[Squares.e2] = .whitePawn }
        let state = makeState(position: pos, halfmoveClock: 17)
        let next = state.applying(
            .make(from: Squares.e2, to: Squares.e3,
                  pieceType: .pawn, pieceColor: .white)
        )
        #expect(next.halfmoveClock == 0)
    }
    
    @Test func captureResetsClock() {
        let pos = minimalPosition {
            $0[Squares.a1] = .whiteRook
            $0[Squares.a7] = .blackPawn
        }
        let state = makeState(position: pos, halfmoveClock: 42)
        let next = state.applying(
            .make(from: Squares.a1, to: Squares.a7,
                  pieceType: .rook, pieceColor: .white,
                  capturedPieceType: .pawn)
        )
        #expect(next.halfmoveClock == 0)
    }
    
    @Test func quietPieceMoveIncrementsClock() {
        let pos = minimalPosition { $0[Squares.b1] = .whiteKnight }
        let state = makeState(position: pos, halfmoveClock: 5)
        let next = state.applying(
            .make(from: Squares.b1, to: Squares.c3,
                  pieceType: .knight, pieceColor: .white)
        )
        #expect(next.halfmoveClock == 6)
    }
    
    // MARK: Fullmove Number
    
    @Test func whiteMoveDoesNotIncrementFullmove() {
        let next = GameState.starting.applying(
            .make(from: Squares.e2, to: Squares.e4,
                  pieceType: .pawn, pieceColor: .white,
                  isDoublePawnPush: true)
        )
        #expect(next.fullmoveNumber == 1)
    }
    
    @Test func blackMoveIncrementsFullmove() {
        let state = makeState(
            position: Position.starting,
            activeColor: .black,
            castlingRights: .all,
            fullmoveNumber: 1
        )
        let next = state.applying(
            .make(from: Squares.e7, to: Squares.e5,
                  pieceType: .pawn, pieceColor: .black,
                  isDoublePawnPush: true)
        )
        #expect(next.fullmoveNumber == 2)
    }
    
    // MARK: Position Transition (sanity check, full coverage in PositionTests)
    
    @Test func positionUpdatesViaPositionApplying() {
        let next = GameState.starting.applying(
            .make(from: Squares.e2, to: Squares.e4,
                  pieceType: .pawn, pieceColor: .white,
                  isDoublePawnPush: true)
        )
        #expect(next.position[Squares.e4] == .whitePawn)
        #expect(next.position[Squares.e2] == .empty)
    }
}
