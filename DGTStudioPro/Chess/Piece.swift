//
//  Piece.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 27/03/2026.
//

enum PieceColor: UInt8, CaseIterable, Codable, Sendable {
    case white = 0
    case black = 1
    
    // MARK: - Computed Properties
    var opponent: PieceColor {
        self == .white ? .black : .white
    }
}

enum PieceType: UInt8, CaseIterable, Codable, Sendable {
    case pawn   = 1
    case knight = 2
    case bishop = 3
    case rook   = 4
    case queen  = 5
    case king   = 6
    
    // MARK: - Static Constants
    private static let fenBytes: [UInt8] = [
        0,                 // 0: Unused padding, raw values 1-6 map directly.
        UInt8(ascii: "P"), // 1: Pawn
        UInt8(ascii: "N"), // 2: Knight
        UInt8(ascii: "B"), // 3: Bishop
        UInt8(ascii: "R"), // 4: Rook
        UInt8(ascii: "Q"), // 5: Queen
        UInt8(ascii: "K"), // 6: King
    ]
    
    // MARK: - Computed Properties
    var materialValue: Int {
        switch self {
        case .pawn:   return 1
        case .knight: return 3
        case .bishop: return 3
        case .rook:   return 5
        case .queen:  return 9
        case .king:   return 0
        }
    }
    
    var notation: String {
        switch self {
        case .pawn:   return ""
        case .knight: return "N"
        case .bishop: return "B"
        case .rook:   return "R"
        case .queen:  return "Q"
        case .king:   return "K"
        }
    }
    
    var fenByte: UInt8 {
        // Uppercase FEN byte for this piece type (e.g. 80 for 'P').
        Self.fenBytes[Int(rawValue)]
    }
    
    // MARK: - Instance Methods
    func fenCharacter(for color: PieceColor) -> Character {
        // Adding 32 (0x20) converts uppercase ASCII to lowercase.
        let byte = fenByte &+ (color.rawValue &* 32)
        return Character(UnicodeScalar(byte))
    }
}

struct Piece: Codable, Equatable, Hashable, Sendable {
    
    // MARK: - Static Constants
    static let empty = Piece(rawValue: 0)
    
    static let whitePawn   = Piece(.white, .pawn)
    static let whiteKnight = Piece(.white, .knight)
    static let whiteBishop = Piece(.white, .bishop)
    static let whiteRook   = Piece(.white, .rook)
    static let whiteQueen  = Piece(.white, .queen)
    static let whiteKing   = Piece(.white, .king)
    
    static let blackPawn   = Piece(.black, .pawn)
    static let blackKnight = Piece(.black, .knight)
    static let blackBishop = Piece(.black, .bishop)
    static let blackRook   = Piece(.black, .rook)
    static let blackQueen  = Piece(.black, .queen)
    static let blackKing   = Piece(.black, .king)
    
    // MARK: - Stored Properties
    let rawValue: UInt8
    
    // MARK: - Computed Properties
    var isOccupied: Bool { rawValue != 0 }
    
    var color: PieceColor? {
        guard isOccupied else { return nil }
        return PieceColor(rawValue: (rawValue >> 3) & 1)
    }
    
    var type: PieceType? {
        guard isOccupied else { return nil }
        return PieceType(rawValue: rawValue & 0b111)
    }
    
    var fenCharacter: Character {
        guard let type, let color else { return "." }
        return type.fenCharacter(for: color)
    }
    
    // MARK: - Initializers
    init(_ color: PieceColor, _ type: PieceType) {
        self.rawValue = (color.rawValue << 3) | type.rawValue
    }
    
    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    // MARK: - Instance Methods
    func isColor(_ color: PieceColor) -> Bool {
        self.color == color
    }
}
