//
//  FEN.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 30/03/2026.
//

internal struct FEN: Equatable, Sendable {
    
    // MARK: - Static Constants
    internal static let starting = FEN(
        position: .starting,
        activeColor: .white,
        castlingRights: .all,
        enPassantTarget: nil,
        halfmoveClock: 0,
        fullmoveNumber: 1
    )
    
    internal static let startingString = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    
    // MARK: - Stored Properties
    internal let position: Position
    internal let activeColor: PieceColor
    internal let castlingRights: CastlingRights
    internal let enPassantTarget: Square?
    internal let halfmoveClock: Int
    internal let fullmoveNumber: Int
    
    // MARK: - Computed Properties
    internal var string: String {
        let placement: String = piecePlacement
        let color: Character = activeColor == .white ? "w" : "b"
        let castling: String = castlingRights.fen
        let enPassant: String = enPassantTarget?.algebraicNotation ?? "-"
        return "\(placement) \(color) \(castling) \(enPassant) \(halfmoveClock) \(fullmoveNumber)"
    }
    
    internal var positionKey: String {
        let placement: String = piecePlacement
        let color: Character = activeColor == .white ? "w" : "b"
        let castling: String = castlingRights.fen
        let ep: String = enPassantTarget?.algebraicNotation ?? "-"
        return "\(placement) \(color) \(castling) \(ep)"
    }
    
    private var piecePlacement: String {
        var result = ""
        result.reserveCapacity(72)
        
        for rank in stride(from: 7, through: 0, by: -1) {
            if rank < 7 { result.append("/") }
            var emptyRun = 0
            
            for file in 0..<8 {
                let piece = position[rank &* 8 &+ file]
                
                if piece.isOccupied {
                    if emptyRun > 0 {
                        result.append(emptyRun.asciiDigit)
                        emptyRun = 0
                    }
                    result.append(piece.fenCharacter)
                } else {
                    emptyRun += 1
                }
            }
            
            if emptyRun > 0 {
                result.append(emptyRun.asciiDigit)
            }
        }
        
        return result
    }
    
    // MARK: - Initializers
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
}
