//
//  Position.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 30/03/2026.
//

internal struct Position: Codable, Equatable, Sendable {
    
    // MARK: - Static Properties
    internal static let empty: Position = .init()
    
    // MARK: - Static Constants
    internal static let starting: Position = {
        var position = Position()
        let backRank: [PieceType] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        
        for file in Square.sides {
            position[Squares.a1 + file] = Piece(.white, backRank[file])
            position[Squares.a2 + file] = .whitePawn
            position[Squares.a7 + file] = .blackPawn
            position[Squares.a8 + file] = Piece(.black, backRank[file])
        }
        
        return position
    }()
    
    // MARK: - Stored Properties
    private var squares: [Piece]
    
    // MARK: - Initializers
    private init() {
        squares = [Piece](repeating: .empty, count: Square.count)
    }
    
    // MARK: - Subscripts
    internal subscript(square: Square) -> Piece {
        get { squares[square] }
        set { squares[square] = newValue }
    }
    
    // MARK: - Instance Methods
    internal func kingSquare(for color: PieceColor) -> Square? {
        let king = Piece(color, .king)
        
        for square in Square.all {
            if squares[square] == king { return square }
        }
        
        return nil
    }
}
