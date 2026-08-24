import Foundation

/// A decoded DGT board event - the only DGT-shaped value the rest of the app sees. Coordinates are
/// already app `Square`s and occupants already app `Piece`s; no field index or wire byte gets past
/// here.
enum DGTEvent: Equatable, Sendable {
    /// Full 64-square snapshot (`DGT_MSG_BOARD_DUMP`).
    case boardDump(Position)
    /// A single field changed (`DGT_MSG_FIELD_UPDATE`). One physical move is **two or more** of
    /// these, ordered by the player's hands: a quiet move lifts then places, a capture lifts twice,
    /// castling is four. Pairing them into a move is `DGTReconstructor`'s concern.
    case fieldUpdate(square: Square, piece: Piece)
    /// Board serial number (`DGT_MSG_SERIALNR`).
    case serialNumber(String)
    /// Board long serial number (`DGT_MSG_LONG_SERIALNR`).
    case longSerialNumber(String)
    /// Manufacturer trademark / firmware banner (`DGT_MSG_TRADEMARK`).
    case trademark(String)
    /// Firmware version (`DGT_MSG_VERSION`).
    case version(major: Int, minor: Int)
    /// Hardware version (`DGT_MSG_HARDWARE_VERSION`).
    case hardwareVersion(major: Int, minor: Int)
}

/// Decodes a framed DGT message. Pure and **total**: every input yields a well-formed event or
/// `nil` - unknown message ID, or a known ID whose payload fails its length or range contract.
/// Malformed bytes are a wire fact, not a programmer error, so nothing here traps.
///
/// This is where hardware indexing is erased: `Square(dgtField:)` for the a8 ↔ a1 transform,
/// `DGTPiece.piece` for the code remap.
enum DGTDecoder {
    
    // MARK: Entry Point
    
    static func decode(_ frame: DGTFrame) -> DGTEvent? {
        guard let message = DGTMessage(rawValue: frame.message) else {
            return nil // Unknown ID - `DGTSerialPort` logs the raw byte.
        }
        
        switch message {
        case .boardDump:        return decodeBoardDump(frame.data)
        case .fieldUpdate:      return decodeFieldUpdate(frame.data)
        case .version:          return decodeVersion(frame.data, hardware: false)
        case .hardwareVersion:  return decodeVersion(frame.data, hardware: true)
        case .serialNumber:     return decodeText(frame.data, as: DGTEvent.serialNumber)
        case .longSerialNumber: return decodeText(frame.data, as: DGTEvent.longSerialNumber)
        case .trademark:        return decodeText(frame.data, as: DGTEvent.trademark)
        }
    }
    
    // MARK: Board Dump (0x86)
    
    /// 64 payload bytes, one DGT piece code per field, in DGT field order (a8 = 0 … h1 = 63). One
    /// out-of-range code fails the whole dump rather than placing a wrong piece.
    ///
    /// The `Square(dgtField:)` guard is **unreachable here** - `field` is loop-bounded to 0..<64,
    /// exactly that initializer's accepting range. The live one is in `decodeFieldUpdate`, where
    /// the index arrives off the wire.
    private static func decodeBoardDump(_ data: [UInt8]) -> DGTEvent? {
        guard data.count == Square.count else { return nil }
        
        var position = Position.empty
        for field in 0..<Square.count {
            guard let dgtPiece = DGTPiece(rawValue: data[field]),
                  let square = Square(dgtField: field) else {
                return nil
            }
            position[square] = dgtPiece.piece
        }
        return .boardDump(position)
    }
    
    // MARK: Field Update (0x8E)
    
    /// 2 payload bytes: field number, then the piece code. The second is a full `DGTPiece` rather
    /// than a bare occupied flag, because this board reports piece type - which is what lets the
    /// mirror render the physical board without consulting the game.
    private static func decodeFieldUpdate(_ data: [UInt8]) -> DGTEvent? {
        guard data.count == 2,
              let square = Square(dgtField: Int(data[0])),
              let dgtPiece = DGTPiece(rawValue: data[1]) else {
            return nil
        }
        return .fieldUpdate(square: square, piece: dgtPiece.piece)
    }
    
    // MARK: Version (0x93 / 0x96)
    
    /// 2 payload bytes, each 7-bit: main version then sub version. The mask trusts rather than
    /// validates - an MSB-set byte yields a wrong number, not `nil`.
    private static func decodeVersion(_ data: [UInt8], hardware: Bool) -> DGTEvent? {
        guard data.count == 2 else { return nil }
        let major = Int(data[0] & 0x7F)
        let minor = Int(data[1] & 0x7F)
        return hardware
        ? .hardwareVersion(major: major, minor: minor)
        : .version(major: major, minor: minor)
    }
    
    // MARK: Text Info Messages (0x91 / 0x92 / 0xA2)
    
    /// ASCII payload (serial / long serial / trademark). NULs and whitespace are trimmed from
    /// **both** ends; empty after trimming is `nil`.
    ///
    /// `String(decoding:)` cannot fail, so a non-ASCII byte survives as U+FFFD and ships a garbled
    /// string - the range contract the other decoders enforce has no analogue here.
    private static func decodeText(
        _ data: [UInt8],
        as make: (String) -> DGTEvent
    ) -> DGTEvent? {
        let text = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0")
                .union(.whitespacesAndNewlines))
        guard !text.isEmpty else { return nil }
        return make(text)
    }
}
