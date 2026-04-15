//
//  Piece.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 27/03/2026.
//

internal enum PieceColor: UInt8, CaseIterable, Codable, Sendable {
    case white = 0
    case black = 1

    // MARK: Computed Properties
    internal var opponent: PieceColor {
        self == .white ? .black : .white
    }
}

internal enum PieceType: UInt8, CaseIterable, Codable, Sendable {
    case pawn   = 1
    case knight = 2
    case bishop = 3
    case rook   = 4
    case queen  = 5
    case king   = 6

    // MARK: Static Constants
    private static let fenBytes: [UInt8] = [
        0,                 // 0: Unused padding, raw values 1-6 map directly.
        UInt8(ascii: "P"), // 1: Pawn
        UInt8(ascii: "N"), // 2: Knight
        UInt8(ascii: "B"), // 3: Bishop
        UInt8(ascii: "R"), // 4: Rook
        UInt8(ascii: "Q"), // 5: Queen
        UInt8(ascii: "K"), // 6: King
    ]

    // MARK: Computed Properties
    internal var materialValue: Int {
        switch self {
        case .pawn:   return 1
        case .knight: return 3
        case .bishop: return 3
        case .rook:   return 5
        case .queen:  return 9
        case .king:   return 0
        }
    }

    internal var notation: String {
        switch self {
        case .pawn:   return ""
        case .knight: return "N"
        case .bishop: return "B"
        case .rook:   return "R"
        case .queen:  return "Q"
        case .king:   return "K"
        }
    }

    internal var fenByte: UInt8 {
        // Uppercase FEN byte for this piece type (e.g. 80 for 'P').
        Self.fenBytes[Int(rawValue)]
    }

    // MARK: Instance Methods
    internal func fenCharacter(for color: PieceColor) -> Character {
        // Adding 32 (0x20) converts uppercase ASCII to lowercase.
        let byte = fenByte &+ (color.rawValue &* 32)
        return Character(UnicodeScalar(byte))
    }
}

internal struct Piece: Codable, Equatable, Hashable, Sendable {

    // MARK: Static Constants
    private static let typeNames: [String] = [
        "",       // 0: Unused padding, raw values 1-6 map directly.
        "Pawn",   // 1
        "Knight", // 2
        "Bishop", // 3
        "Rook",   // 4
        "Queen",  // 5
        "King",   // 6
    ]

    internal static let empty = Piece(rawValue: 0)

    internal static let whitePawn   = Piece(.white, .pawn)
    internal static let whiteKnight = Piece(.white, .knight)
    internal static let whiteBishop = Piece(.white, .bishop)
    internal static let whiteRook   = Piece(.white, .rook)
    internal static let whiteQueen  = Piece(.white, .queen)
    internal static let whiteKing   = Piece(.white, .king)

    internal static let blackPawn   = Piece(.black, .pawn)
    internal static let blackKnight = Piece(.black, .knight)
    internal static let blackBishop = Piece(.black, .bishop)
    internal static let blackRook   = Piece(.black, .rook)
    internal static let blackQueen  = Piece(.black, .queen)
    internal static let blackKing   = Piece(.black, .king)

    // MARK: Stored Properties
    internal let rawValue: UInt8

    // MARK: Computed Properties
    internal var isOccupied: Bool { rawValue != 0 }

    internal var color: PieceColor? {
        guard isOccupied else { return nil }
        return PieceColor(rawValue: (rawValue >> 3) & 1)
    }

    internal var type: PieceType? {
        guard isOccupied else { return nil }
        return PieceType(rawValue: rawValue & 0b111)
    }

    internal var fenCharacter: Character {
        guard let type, let color else { return "." }
        return type.fenCharacter(for: color)
    }

    internal var imageName: String? {
        guard let color, let type else { return nil }
        let prefix = color == .white ? "White" : "Black"
        return prefix + Self.typeNames[Int(type.rawValue)]
    }

    // MARK: Initializers
    internal init(_ color: PieceColor, _ type: PieceType) {
        self.rawValue = (color.rawValue << 3) | type.rawValue
    }

    internal init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    // MARK: Instance Methods
    internal func isColor(_ color: PieceColor) -> Bool {
        self.color == color
    }
}
