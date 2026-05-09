//
//  CastlingMoveGenerationTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/05/2026.
//

import Testing
@testable import DGTStudioPro

@Suite("Castling Move Generation")
struct CastlingMoveGenerationTests {
    
    // MARK: Helpers
    
    /// Builds a minimal castling test position with both kings + both white rooks
    /// on their home squares. Add additional pieces via the `extras` closure.
    private func castlingPosition(
        extras: (inout Position) -> Void = { _ in }
    ) -> Position {
        var pos = Position.empty
        pos[Squares.e1] = .whiteKing
        pos[Squares.h1] = .whiteRook
        pos[Squares.a1] = .whiteRook
        pos[Squares.e8] = .blackKing
        extras(&pos)
        return pos
    }
    
    private func makeState(
        position: Position,
        activeColor: PieceColor = .white,
        castlingRights: CastlingRights = .all
    ) -> GameState {
        GameState(
            position: position,
            activeColor: activeColor,
            castlingRights: castlingRights,
            enPassantTarget: nil,
            halfmoveClock: 0,
            fullmoveNumber: 1
        )
    }
    
    private func castlingMoves(in state: GameState) -> [Move] {
        state.legalMoves().filter { $0.isCastling }
    }
    
    // MARK: Both Sides Available
    @Test func bothSidesLegalEmitsTwoCastlingMoves() {
        let state = makeState(position: castlingPosition())
        let moves = castlingMoves(in: state)
        
        #expect(moves.count == 2)
        #expect(moves.contains { $0.to == Squares.g1 })
        #expect(moves.contains { $0.to == Squares.c1 })
    }
    
    @Test func castlingMoveCarriesCastlingFlagAndCorrectRookSquares() throws {
        let state = makeState(position: castlingPosition())
        let kingside = try #require(castlingMoves(in: state).first { $0.to == Squares.g1 })
        
        #expect(kingside.isCastling)
        #expect(kingside.from == Squares.e1)
        #expect(kingside.rookFrom == Squares.h1)
        #expect(kingside.rookTo == Squares.f1)
        
        let queenside = try #require(castlingMoves(in: state).first { $0.to == Squares.c1 })
        #expect(queenside.rookFrom == Squares.a1)
        #expect(queenside.rookTo == Squares.d1)
    }
    
    // MARK: Rights Gating
    @Test func noRightsMeansNoCastling() {
        let state = makeState(position: castlingPosition(), castlingRights: .none)
        #expect(castlingMoves(in: state).isEmpty)
    }
    
    @Test func onlyKingsideRights() {
        // 0b0001 = white kingside only
        let state = makeState(
            position: castlingPosition(),
            castlingRights: CastlingRights(rawValue: 0b0001)
        )
        let moves = castlingMoves(in: state)
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.g1)
    }
    
    @Test func onlyQueensideRights() {
        // 0b0010 = white queenside only
        let state = makeState(
            position: castlingPosition(),
            castlingRights: CastlingRights(rawValue: 0b0010)
        )
        let moves = castlingMoves(in: state)
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.c1)
    }
    
    // MARK: Path Blocked
    @Test func pieceBetweenBlocksKingside() {
        let pos = castlingPosition { p in p[Squares.f1] = .whiteBishop }
        let state = makeState(position: pos)
        let moves = castlingMoves(in: state)
        
        // Queenside still legal
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.c1)
    }
    
    @Test func pieceBetweenBlocksQueenside() {
        let pos = castlingPosition { p in p[Squares.d1] = .whiteQueen }
        let state = makeState(position: pos)
        let moves = castlingMoves(in: state)
        
        // Kingside still legal
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.g1)
    }
    
    @Test func pieceOnBSquareBlocksQueensideEvenThoughKingDoesntPassThroughIt() {
        // The b1 square isn't part of the king's path but the rook traverses it,
        // so castling is illegal if it's occupied.
        let pos = castlingPosition { p in p[Squares.b1] = .whiteKnight }
        let state = makeState(position: pos)
        let moves = castlingMoves(in: state)
        
        // Kingside legal; queenside blocked
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.g1)
    }
    
    // MARK: Attack Gating
    @Test func cannotCastleOutOfCheck() {
        // Black rook on e2 attacks the white king on e1
        let pos = castlingPosition { p in p[Squares.e2] = .blackRook }
        let state = makeState(position: pos)
        
        #expect(state.isInCheck)
        #expect(castlingMoves(in: state).isEmpty)
    }
    
    @Test func cannotCastleThroughAttackedSquareKingside() {
        // Black rook on f4 attacks the king's kingside transit square f1
        let pos = castlingPosition { p in p[Squares.f4] = .blackRook }
        let state = makeState(position: pos)
        let moves = castlingMoves(in: state)
        
        // Queenside still legal (transit d1 not attacked)
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.c1)
    }
    
    @Test func cannotCastleThroughAttackedSquareQueenside() {
        // Black rook on d4 attacks the queenside transit d1
        let pos = castlingPosition { p in p[Squares.d4] = .blackRook }
        let state = makeState(position: pos)
        let moves = castlingMoves(in: state)
        
        // Kingside legal
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.g1)
    }
    
    @Test func cannotCastleIntoAttackedDestination() {
        // Black rook on g4 attacks the kingside destination g1 but NOT the transit f1.
        // Pseudo-legal generation emits the move; legal filter rejects it.
        let pos = castlingPosition { p in p[Squares.g4] = .blackRook }
        let state = makeState(position: pos)
        let moves = castlingMoves(in: state)
        
        // Queenside still legal
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.c1)
    }
    
    // MARK: Black Mirror
    @Test func blackKingsideCastling() {
        var pos = Position.empty
        pos[Squares.e1] = .whiteKing
        pos[Squares.e8] = .blackKing
        pos[Squares.h8] = .blackRook
        pos[Squares.a8] = .blackRook
        let state = makeState(position: pos, activeColor: .black, castlingRights: .all)
        
        let moves = castlingMoves(in: state)
        #expect(moves.contains { $0.to == Squares.g8 })
        #expect(moves.contains { $0.to == Squares.c8 })
    }
    
    // MARK: Starting Position Sanity
    @Test func startingPositionGeneratesNoCastling() {
        // All between-squares occupied by knights/bishops/queen.
        let moves = castlingMoves(in: .starting)
        #expect(moves.isEmpty)
    }
}
