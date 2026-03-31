//
//  FEN.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 30/03/2026.
//

struct FEN: Equatable, Sendable {
    let position: Position
    let activeColor: PieceColor
    let castlingRights: CastlingRights
    let enPassantTarget: Square?
    let halfmoveClock: Int
    let fullmoveNumber: Int
    
    init(
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
    
    var string: String {
        let placement: String = piecePlacement
        let color: Character = activeColor == .white ? "w" : "b"
        let castling: String = castlingRights.fen
        let enPassant: String = enPassantTarget?.algebraicNotation ?? "-"
        return "\(placement) \(color) \(castling) \(enPassant) \(halfmoveClock) \(fullmoveNumber)"
    }
    
    var positionKey: String {
        let placement: String = piecePlacement
        let color: Character = activeColor == .white ? "w" : "b"
        let castling: String = castlingRights.fen
        let ep: String = enPassantTarget?.algebraicNotation ?? "-"
        return "\(placement) \(color) \(castling) \(ep)"
    }
    
    static let starting = FEN(
        position: .starting,
        activeColor: .white,
        castlingRights: .all,
        enPassantTarget: nil,
        halfmoveClock: 0,
        fullmoveNumber: 1
    )
    
    static let startingString = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    
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
}

private extension Square {
    var asciiDigit: Character {
        Character(UnicodeScalar(UInt8(ascii: "0") &+ UInt8(self)))
    }
}
