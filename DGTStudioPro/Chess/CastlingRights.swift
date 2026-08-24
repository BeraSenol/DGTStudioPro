enum CastlingSide: Sendable {
    case kingSide
    case queenSide

    /// The king's destination file - g (6) kingside, c (2) queenside.
    var kingDestinationFile: Int {
        self == .kingSide ? 6 : 2
    }
}

/// The four castling rights as one `UInt8`. `Codable`'s only consumer is the round-trip test;
/// nothing in the app persists these.
struct CastlingRights: Codable, Equatable, Hashable, Sendable {

    // MARK: Static Constants
    private static let whiteKingSideMask: UInt8  = 0b0001
    private static let whiteQueenSideMask: UInt8 = 0b0010
    private static let blackKingSideMask: UInt8  = 0b0100
    private static let blackQueenSideMask: UInt8 = 0b1000

    static let none = CastlingRights(rawValue: 0b0000)
    static let all  = CastlingRights(rawValue: 0b1111)

    // MARK: Stored Properties
    private(set) var rawValue: UInt8

    // MARK: Computed Properties
    var whiteKingSide:  Bool { rawValue & Self.whiteKingSideMask  != 0 }
    var whiteQueenSide: Bool { rawValue & Self.whiteQueenSideMask != 0 }
    var blackKingSide:  Bool { rawValue & Self.blackKingSideMask  != 0 }
    var blackQueenSide: Bool { rawValue & Self.blackQueenSideMask != 0 }

    /// KQkq, in that order - the FEN field's own ordering.
    var fen: String {
        guard rawValue != 0 else { return "-" }

        var result = ""

        if whiteKingSide  { result.append("K") }
        if whiteQueenSide { result.append("Q") }
        if blackKingSide  { result.append("k") }
        if blackQueenSide { result.append("q") }

        return result
    }

    // MARK: Initializers
    /// **Test-only by decision**, per the waiver register: production builds rights through
    /// `.all`, `.none` or `init(rawValue:)`.
    init() {
        rawValue = Self.all.rawValue
    }

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    // MARK: Instance Methods
    /// The readable accessor over a private mask; production-called from `appendCastlingMoves`.
    func has(_ color: PieceColor, _ side: CastlingSide) -> Bool {
        rawValue & Self.mask(for: color, side).rawValue != 0
    }

    mutating func revoke(_ rights: CastlingRights) {
        rawValue &= ~rights.rawValue
    }

    mutating func revokeAll(for color: PieceColor) {
        let mask = color == .white
        ? Self.whiteKingSideMask | Self.whiteQueenSideMask
        : Self.blackKingSideMask | Self.blackQueenSideMask
        rawValue &= ~mask
    }

    // MARK: Static Methods
    static func mask(for color: PieceColor, _ side: CastlingSide) -> CastlingRights {
        switch (color, side) {
        case (.white, .kingSide):  return CastlingRights(rawValue: whiteKingSideMask)
        case (.white, .queenSide): return CastlingRights(rawValue: whiteQueenSideMask)
        case (.black, .kingSide):  return CastlingRights(rawValue: blackKingSideMask)
        case (.black, .queenSide): return CastlingRights(rawValue: blackQueenSideMask)
        }
    }
}
