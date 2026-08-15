enum DGTCommand: UInt8, Sendable {
    case sendReset              = 0x40
    case sendBoard              = 0x42
    case sendUpdateBoard        = 0x44
    case returnSerialNumber     = 0x45
    case sendTrademark          = 0x47
    case sendHardwareVersion    = 0x48
    case sendVersion            = 0x4D
    case returnLongSerialNumber = 0x55
}

enum DGTMessage: UInt8, Sendable {
    case boardDump        = 0x86
    case fieldUpdate      = 0x8E
    case serialNumber     = 0x91
    case trademark        = 0x92
    case version          = 0x93
    case hardwareVersion  = 0x96
    case longSerialNumber = 0xA2
}

enum DGTPiece: UInt8, Sendable {
    // The DGT piece ordering differs from the app's `PieceType`:
    // Use the `piece` property to convert to the app's `Piece` type at
    // the protocol boundary.
    case empty       = 0
    case whitePawn   = 1
    case whiteRook   = 2
    case whiteKnight = 3
    case whiteBishop = 4
    case whiteKing   = 5
    case whiteQueen  = 6
    case blackPawn   = 7
    case blackRook   = 8
    case blackKnight = 9
    case blackBishop = 10
    case blackKing   = 11
    case blackQueen  = 12
    
    // MARK: Computed Properties
    /// Converts this DGT piece to the app's `Piece` type. A `switch`, not a
    /// raw-value-indexed table: a new DGT case would have compiled against the
    /// table and trapped out of range at the decode boundary — here it's a
    /// build error, which is the only witness a wire enum can rely on.
    var piece: Piece {
        switch self {
        case .empty:       .empty
        case .whitePawn:   .whitePawn
        case .whiteRook:   .whiteRook
        case .whiteKnight: .whiteKnight
        case .whiteBishop: .whiteBishop
        case .whiteKing:   .whiteKing
        case .whiteQueen:  .whiteQueen
        case .blackPawn:   .blackPawn
        case .blackRook:   .blackRook
        case .blackKnight: .blackKnight
        case .blackBishop: .blackBishop
        case .blackKing:   .blackKing
        case .blackQueen:  .blackQueen
        }
    }
}
