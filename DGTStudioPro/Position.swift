//
//  Position.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 30/03/2026.
//

struct Position: Codable, Equatable, Sendable {
    private var squares: [Piece]

    init() {
        squares = [Piece](repeating: .empty, count: Square.count)
    }

    func kingSquare(for color: PieceColor) -> Square? {
        let king = Piece(color, .king)

        for square in Square.all {
            if squares[square] == king { return square }
        }

        return nil
    }

    subscript(square: Square) -> Piece {
        get { squares[square] }
        set { squares[square] = newValue }
    }

    static let starting: Position = {
        var position = Position()
        let backRank: [PieceType] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]

        for file in 0..<8 {
            position[Squares.a1 + file] = Piece(.white, backRank[file])
            position[Squares.a2 + file] = .whitePawn
            position[Squares.a7 + file] = .blackPawn
            position[Squares.a8 + file] = Piece(.black, backRank[file])
        }

        return position
    }()
}
