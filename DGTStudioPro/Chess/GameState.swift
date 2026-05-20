//
//  GameState.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/05/2026.
//

internal struct GameState: Equatable, Sendable {
    
    // MARK: Static Constants
    internal static let starting = GameState(
        position: .starting,
        activeColor: .white,
        castlingRights: .all,
        enPassantTarget: nil,
        halfmoveClock: 0,
        fullmoveNumber: 1
    )
    
    // MARK: Stored Properties
    internal let position: Position
    internal let activeColor: PieceColor
    internal let castlingRights: CastlingRights
    internal let enPassantTarget: Square?
    internal let halfmoveClock: Int
    internal let fullmoveNumber: Int
    
    // MARK: Initializers
    internal init(
        position: Position,
        activeColor: PieceColor,
        castlingRights: CastlingRights,
        enPassantTarget: Square?,
        halfmoveClock: Int,
        fullmoveNumber: Int
    ) {
        self.position = position
        self.activeColor = activeColor
        self.castlingRights = castlingRights
        self.enPassantTarget = enPassantTarget
        self.halfmoveClock = halfmoveClock
        self.fullmoveNumber = fullmoveNumber
    }
    
    internal init(_ fen: FEN) {
        self.init(
            position: fen.position,
            activeColor: fen.activeColor,
            castlingRights: fen.castlingRights,
            enPassantTarget: fen.enPassantTarget,
            halfmoveClock: fen.halfmoveClock,
            fullmoveNumber: fen.fullmoveNumber
        )
    }
}

extension FEN {
    internal init(_ state: GameState) {
        self.init(
            position: state.position,
            activeColor: state.activeColor,
            castlingRights: state.castlingRights,
            enPassantTarget: state.enPassantTarget,
            halfmoveClock: state.halfmoveClock,
            fullmoveNumber: state.fullmoveNumber
        )
    }
}
