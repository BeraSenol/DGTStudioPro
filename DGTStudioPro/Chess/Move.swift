internal struct Move: Equatable, Hashable, Sendable {
    // Packed: bits 0-5 from, 6-11 to, 12-14 piece type, 15-17 captured, 18-20 promotion, 21+ flags.
    
    // MARK: Static Constants
    private static let toShift:            Int = 6
    private static let pieceTypeShift:     Int = 12
    private static let pieceColorShift:    Int = 15
    private static let capturedTypeShift:  Int = 16
    private static let promotionTypeShift: Int = 19
    
    private static let castlingFlag:       UInt32 = 1 << 22
    private static let enPassantFlag:      UInt32 = 1 << 23
    private static let doublePawnPushFlag: UInt32 = 1 << 24
    
    // MARK: Stored Properties
    internal let rawValue: UInt32
    
    // MARK: Computed Properties
    internal var from: Square {
        Int(rawValue) & 0x3F
    }
    
    internal var to: Square {
        Int(rawValue >> Self.toShift) & 0x3F
    }
    
    internal var pieceType: PieceType {
        PieceType(rawValue: UInt8((rawValue >> Self.pieceTypeShift) & 0x07))!
    }
    
    internal var pieceColor: PieceColor {
        PieceColor(rawValue: UInt8((rawValue >> Self.pieceColorShift) & 0x01))!
    }
    
    internal var capturedPieceType: PieceType? {
        let raw = UInt8((rawValue >> Self.capturedTypeShift) & 0x07)
        return PieceType(rawValue: raw)
    }
    
    internal var promotionType: PieceType? {
        let raw = UInt8((rawValue >> Self.promotionTypeShift) & 0x07)
        return PieceType(rawValue: raw)
    }
    
    internal var isCastling: Bool {
        rawValue & Self.castlingFlag != 0
    }
    
    internal var isEnPassant: Bool {
        rawValue & Self.enPassantFlag != 0
    }
    
    internal var isDoublePawnPush: Bool {
        rawValue & Self.doublePawnPushFlag != 0
    }
    
    /// A bit test, not an enum construction: the captured field is 0 (none) or
    /// a valid 1–6, so "any bit set" and "decodes to non-nil" are the same
    /// question. Called once per generated move by the castling-rights update.
    internal var isCapture: Bool {
        rawValue & (0x07 << Self.capturedTypeShift) != 0
    }
    
    internal var capturedSquare: Square? {
        guard isCapture else { return nil }
        if isEnPassant {
            return pieceColor == .white ? to - 8 : to + 8
        }
        return to
    }
    
    /// Which side this castling move is, read off the king's destination file.
    internal var castlingSide: CastlingSide? {
        guard isCastling else { return nil }
        return to.file == CastlingSide.kingSide.kingDestinationFile ? .kingSide : .queenSide
    }
    
    internal var rookFrom: Square? {
        guard let castlingSide else { return nil }
        return castlingSide == .kingSide ? to + 1 : to - 2
    }
    
    internal var rookTo: Square? {
        guard let castlingSide else { return nil }
        return castlingSide == .kingSide ? to - 1 : to + 1
    }
    
    // MARK: Initializers
    private init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    // MARK: Static Methods
    internal static func make(
        from: Square,
        to: Square,
        pieceType: PieceType,
        pieceColor: PieceColor,
        capturedPieceType: PieceType? = nil,
        promotionType: PieceType? = nil,
        isCastling: Bool = false,
        isEnPassant: Bool = false,
        isDoublePawnPush: Bool = false
    ) -> Move {
        var raw: UInt32 = 0
        raw |= UInt32(from) & 0x3F
        raw |= (UInt32(to) & 0x3F) << toShift
        raw |= (UInt32(pieceType.rawValue) & 0x07) << pieceTypeShift
        raw |= (UInt32(pieceColor.rawValue) & 0x01) << pieceColorShift
        
        if let capturedPieceType {
            raw |= (UInt32(capturedPieceType.rawValue) & 0x07) << capturedTypeShift
        }
        if let promotionType {
            raw |= (UInt32(promotionType.rawValue) & 0x07) << promotionTypeShift
        }
        
        if isCastling       { raw |= castlingFlag }
        if isEnPassant      { raw |= enPassantFlag }
        if isDoublePawnPush { raw |= doublePawnPushFlag }

        return Move(rawValue: raw)
    }
}

// MARK: - Last Move

/// The two squares a board highlights after a move. **Deliberately not a `Move`** — the mirror
/// must highlight without claiming move-level knowledge it doesn't have.
internal struct LastMove: Equatable, Sendable {
    internal let from: Square
    internal let to: Square
}
