/// White is 0 and black is 1, which `PieceType.fenCharacter(for:)` multiplies by 32 to pick ASCII
/// case. Renumbering these would silently lowercase the wrong side.
enum PieceColor: UInt8, CaseIterable, Codable, Sendable {
    case white = 0
    case black = 1
    
    // MARK: Computed Properties
    var opponent: PieceColor {
        self == .white ? .black : .white
    }
}

/// Raw values start at 1 so that 0 can mean "none" in `Move`'s packed captured and promotion
/// fields, and so `fenBytes` can index directly.
enum PieceType: UInt8, CaseIterable, Codable, Sendable {
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
    
    /// The four pieces a pawn may become, in SAN's conventional order - best first - which is also
    /// the order `appendPromotions` emits.
    ///
    /// **Nothing pins that order.** Perft counts leaves, so it is order-blind, and both promotion
    /// tests compare a `Set`. A reorder here is invisible to the whole suite.
    static let promotionTypes: [PieceType] = [.queen, .rook, .bishop, .knight]
    
    var notation: String {
        switch self {
        case .pawn:   ""
        case .knight: "N"
        case .bishop: "B"
        case .rook:   "R"
        case .queen:  "Q"
        case .king:   "K"
        }
    }
    
    /// The uppercase FEN byte - 80 for `P`, and so on.
    var fenByte: UInt8 {
        Self.fenBytes[Int(rawValue)]
    }
    
    // MARK: Instance Methods
    func fenCharacter(for color: PieceColor) -> Character {
        // +32 (0x20) is uppercase ASCII → lowercase, and black's raw value is exactly 1.
        let byte = fenByte + (color.rawValue * 32)
        return Character(UnicodeScalar(byte))
    }
}

/// A piece packed into one `UInt8`: bits 0-2 the `PieceType` raw value, bit 3 the colour, 0 for an
/// empty square. So the occupied values are 1-6 (white) and 9-14 (black).
struct Piece: Codable, Equatable, Hashable, Sendable {
    
    // MARK: Static Constants
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
    
    /// Sized to the packing's whole 4-bit range, not to the twelve real pieces - which is what lets
    /// `imageName` subscript without a bounds check.
    private static let imageNames: [String?] = {
        let typeNames = ["", "Pawn", "Knight", "Bishop", "Rook", "Queen", "King"]
        var table = [String?](repeating: nil, count: 16)
        for color in PieceColor.allCases {
            for type in PieceType.allCases {
                let prefix = color == .white ? "White" : "Black"
                table[Int(Piece(color, type).rawValue)] = prefix + typeNames[Int(type.rawValue)]
            }
        }
        return table
    }()
    
    // MARK: Stored Properties
    let rawValue: UInt8
    
    // MARK: Computed Properties
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
    
    var imageName: String? {
        Self.imageNames[Int(rawValue)]
    }
    
    // MARK: Initializers
    init(_ color: PieceColor, _ type: PieceType) {
        self.rawValue = (color.rawValue << 3) | type.rawValue
    }
    
    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    // MARK: Instance Methods
    func isColor(_ color: PieceColor) -> Bool {
        self.color == color
    }
}
