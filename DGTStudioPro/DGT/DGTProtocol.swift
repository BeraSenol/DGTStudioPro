// The DGT wire vocabulary: outbound command bytes, inbound message IDs, the board's piece codes.
// Transcribed from the protocol document - the compiler cannot check a byte, so `DGTProtocolTests`
// pins every raw value below and is the only witness they are right.

/// Everything the app can say to the board. `DGTSerialPort.send` writes `rawValue` and nothing
/// else, so a command is always one byte with no payload.
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

/// Everything the board says back.
///
/// **Bit 7 is set on every value, and that is load-bearing** - `DGTFramer` finds frame starts by
/// scanning for a byte with the MSB set, so a constant below `0x80` is a frame it never opens.
enum DGTMessage: UInt8, Sendable {
    case boardDump        = 0x86
    case fieldUpdate      = 0x8E
    case serialNumber     = 0x91
    case trademark        = 0x92
    case version          = 0x93
    case hardwareVersion  = 0x96
    case longSerialNumber = 0xA2
}

/// The board's piece numbering, which is **not** the app's. DGT counts pawn, rook, knight, bishop,
/// king, queen with black at +6; `Piece` counts pawn, knight, bishop, rook, queen, king with colour
/// in bit 3, so black is at +8.
///
/// **The ranges overlap, so `Piece(rawValue: wireByte)` compiles and mostly succeeds** - nine of the
/// twelve occupied codes yield an occupied piece of the wrong type. Only 0 and 1 survive, empty and
/// white pawn, which are the two anyone checks by eye. `piece` is the one conversion.
enum DGTPiece: UInt8, Sendable {
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
    
    /// A `switch`, not a table indexed by raw value: a new DGT case is then a build error here
    /// rather than an out-of-range trap at the decode boundary.
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
