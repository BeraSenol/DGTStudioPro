//
//  LegalMoveFilterTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/05/2026.
//

import Testing
@testable import DGTStudioPro

@Suite("Legal Move Filter & Game Status")
struct LegalMoveFilterTests {
    
    // MARK: Helpers
    private func legalMoves(in state: GameState, from square: Square) -> [Move] {
        state.legalMoves().filter { $0.from == square }
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
    
    // MARK: Pins
    @Test func absolutelyPinnedKnightCannotMove() {
        // White king e1, white knight e2, black rook e8 — knight pinned along file.
        var pos = Position.empty
        pos[Squares.e1] = .whiteKing
        pos[Squares.e2] = .whiteKnight
        pos[Squares.e8] = .blackRook
        let state = makeState(position: pos)
        
        let knightMoves = legalMoves(in: state, from: Squares.e2)
        #expect(knightMoves.isEmpty)
    }
    
    @Test func pinnedQueenCanMoveAlongPinLine() {
        // White king e1, white queen e2, black rook e8 — queen pinned but can slide on file.
        var pos = Position.empty
        pos[Squares.e1] = .whiteKing
        pos[Squares.e2] = .whiteQueen
        pos[Squares.e8] = .blackRook
        let state = makeState(position: pos)
        
        let queenMoves = legalMoves(in: state, from: Squares.e2)
        // Allowed: e3..e7 (5 quiet) + e8 capture = 6
        #expect(queenMoves.count == 6)
        #expect(queenMoves.allSatisfy { $0.to.file == 4 })  // file e
        #expect(queenMoves.contains { $0.to == Squares.e8 && $0.capturedPieceType == .rook })
    }
    
    // MARK: Moving While in Check
    @Test func mustEscapeCheck() {
        // White king e1 in check from black rook e8. White rook on b1 is
        // confined to rank 1 / b-file; the friendly king on e1 blocks rank-1
        // access to the e-file, and b-file moves don't intersect the e-file
        // either. So no rook move resolves the check.
        var pos = Position.empty
        pos[Squares.e1] = .whiteKing
        pos[Squares.e8] = .blackRook
        pos[Squares.b1] = .whiteRook
        let state = makeState(position: pos)
        
        #expect(state.isInCheck)
        let allMoves = state.legalMoves()
        // King escapes to d1, d2, f1, f2 (e2 still on the rook's file, illegal)
        let kingMoves = allMoves.filter { $0.from == Squares.e1 }
        #expect(Set(kingMoves.map(\.to)) == [Squares.d1, Squares.d2, Squares.f1, Squares.f2])
        // Rook on b1 has no legal move — none can interpose on the e-file or capture e8
        let rookMoves = allMoves.filter { $0.from == Squares.b1 }
        #expect(rookMoves.isEmpty)
    }
    
    @Test func canBlockCheckByInterposition() {
        // White king e1, black rook e8, white bishop a4. Bishop can interpose on e-file via... a4→e8? No.
        // Use a more direct setup: bishop on h4 can move to e1+? Let's interpose on e2 via a different piece.
        // White king e1, black rook e8, white knight g1. Knight g1 → e2 blocks the check? No, g1→e2 isn't a knight move.
        // Use white rook a2: a2 → e2 blocks the check.
        var pos = Position.empty
        pos[Squares.e1] = .whiteKing
        pos[Squares.e8] = .blackRook
        pos[Squares.a2] = .whiteRook
        let state = makeState(position: pos)
        
        let rookMoves = state.legalMoves().filter { $0.from == Squares.a2 }
        // Only e2 (interposition) is legal; other rook moves leave king in check
        #expect(rookMoves.count == 1)
        #expect(rookMoves.first?.to == Squares.e2)
    }
    
    @Test func canCaptureChecker() {
        // White king e1, black rook e2 (giving check), white queen a2. Queen can capture on e2.
        var pos = Position.empty
        pos[Squares.e1] = .whiteKing
        pos[Squares.e2] = .blackRook
        pos[Squares.a2] = .whiteQueen
        let state = makeState(position: pos)
        
        let queenMoves = state.legalMoves().filter { $0.from == Squares.a2 }
        // Queen on a2 can capture e2; can't move elsewhere because e1 stays in check
        #expect(queenMoves.count == 1)
        #expect(queenMoves.first?.to == Squares.e2)
        #expect(queenMoves.first?.capturedPieceType == .rook)
    }
    
    // MARK: King Safety
    @Test func kingCannotMoveIntoCheck() {
        // White king e1, black rook d8 — king cannot step to d1 or d2.
        var pos = Position.empty
        pos[Squares.e1] = .whiteKing
        pos[Squares.d8] = .blackRook
        let state = makeState(position: pos)
        
        let kingMoves = legalMoves(in: state, from: Squares.e1)
        #expect(!kingMoves.contains { $0.to == Squares.d1 })
        #expect(!kingMoves.contains { $0.to == Squares.d2 })
        #expect(kingMoves.contains { $0.to == Squares.e2 })
        #expect(kingMoves.contains { $0.to == Squares.f1 })
    }
    
    @Test func kingsCannotMoveAdjacentToEachOther() {
        // White king e1, black king e3. Neither king can step to d2/e2/f2 (adjacent to other king).
        var pos = Position.empty
        pos[Squares.e1] = .whiteKing
        pos[Squares.e3] = .blackKing
        let state = makeState(position: pos)
        
        let whiteKing = legalMoves(in: state, from: Squares.e1)
        #expect(!whiteKing.contains { $0.to == Squares.d2 })
        #expect(!whiteKing.contains { $0.to == Squares.e2 })
        #expect(!whiteKing.contains { $0.to == Squares.f2 })
        // d1 and f1 are still legal
        #expect(whiteKing.contains { $0.to == Squares.d1 })
        #expect(whiteKing.contains { $0.to == Squares.f1 })
    }
    
    // MARK: En Passant Discovered Check (the famous edge case)
    @Test func enPassantBlockedByDiscoveredCheckOnRank() {
        // White king a5, white pawn b5, black pawn c5 (just played c7-c5),
        // black rook h5. EP capture b5xc6 would remove both pawns from rank 5,
        // exposing white king to the rook. EP must be filtered out.
        var pos = Position.empty
        pos[Squares.a5] = .whiteKing
        pos[Squares.b5] = .whitePawn
        pos[Squares.c5] = .blackPawn
        pos[Squares.h5] = .blackRook
        let state = makeState(position: pos, enPassantTarget: Squares.c6)
        
        let pawnMoves = state.legalMoves().filter { $0.from == Squares.b5 }
        // b6 push is fine; c6 EP must be illegal
        #expect(pawnMoves.contains { $0.to == Squares.b6 })
        #expect(!pawnMoves.contains { $0.isEnPassant })
    }
    
    // MARK: Game Status — Checkmate
    @Test func backRankMateIsCheckmate() {
        // Classic back-rank mate: black king h8 boxed in by own pawns, white rook a8.
        var pos = Position.empty
        pos[Squares.h8] = .blackKing
        pos[Squares.g7] = .blackPawn
        pos[Squares.h7] = .blackPawn
        pos[Squares.a8] = .whiteRook
        let state = makeState(position: pos, activeColor: .black)
        
        #expect(state.isInCheck)
        #expect(state.isCheckmate)
        #expect(!state.isStalemate)
        #expect(state.legalMoves().isEmpty)
    }
    
    @Test func foolsMateIsCheckmate() {
        // After 1.f3 e5 2.g4?? Qh4#
        // White king e1, white pawns shifted. Easier to construct minimally:
        // White king e1, white pawns f3 and g4, black queen h4.
        var pos = Position.starting
        pos[Squares.f2] = .empty; pos[Squares.f3] = .whitePawn
        pos[Squares.g2] = .empty; pos[Squares.g4] = .whitePawn
        pos[Squares.e7] = .empty; pos[Squares.e5] = .blackPawn
        pos[Squares.d8] = .empty; pos[Squares.h4] = .blackQueen
        let state = makeState(position: pos)
        
        #expect(state.isInCheck)
        #expect(state.isCheckmate)
    }
    
    // MARK: Game Status — Stalemate
    @Test func classicCornerStalemate() {
        // Black king a8, white king c7, white queen b6. Black to move, not in check, no legal moves.
        var pos = Position.empty
        pos[Squares.a8] = .blackKing
        pos[Squares.c7] = .whiteKing
        pos[Squares.b6] = .whiteQueen
        let state = makeState(position: pos, activeColor: .black)
        
        #expect(!state.isInCheck)
        #expect(state.isStalemate)
        #expect(!state.isCheckmate)
        #expect(state.legalMoves().isEmpty)
    }
    
    // MARK: Game Status — Normal
    @Test func startingPositionIsNeitherCheckNorMate() {
        let state: GameState = .starting
        #expect(!state.isInCheck)
        #expect(!state.isCheckmate)
        #expect(!state.isStalemate)
        // Pseudo-legal count was 20; legal count is the same since no white move
        // leaves the white king attacked from the starting position.
        #expect(state.legalMoves().count == 20)
    }
    
    // MARK: FEN Forward
    @Test func fenForwardMatchesGameState() {
        let fen: FEN = .starting
        let viaFen = fen.legalMoves()
        let viaState = GameState(fen).legalMoves()
        #expect(viaFen.count == viaState.count)
    }
}
