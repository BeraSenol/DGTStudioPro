//
//  DGTDecoder.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 25/05/2026.
//

import Foundation

/// A decoded, semantically-meaningful DGT board event. This is the output of
/// the D1 decode layer and the only DGT-shaped value the rest of the app sees:
/// coordinates are already app `Square`s, occupants are already app `Piece`s,
/// and no DGT field index or raw byte leaks past this boundary.
internal enum DGTEvent: Equatable, Sendable {
    /// Full 64-square snapshot (`DGT_MSG_BOARD_DUMP`, `0x86`).
    case boardDump(Position)
    /// A single field changed (`DGT_MSG_FIELD_UPDATE`, `0x8E`). A physical move
    /// produces two of these (lift then place) — pairing them into a move is
    /// D4's reconstruction concern, not the decoder's.
    case fieldUpdate(square: Square, piece: Piece)
    /// Board serial number (`DGT_MSG_SERIALNR`, `0x91`).
    case serialNumber(String)
    /// Board long serial number (`DGT_MSG_LONG_SERIALNR`, `0xA2`).
    case longSerialNumber(String)
    /// Manufacturer trademark / firmware banner (`DGT_MSG_TRADEMARK`, `0x92`).
    case trademark(String)
    /// Firmware version (`DGT_MSG_VERSION`, `0x93`).
    case version(major: Int, minor: Int)
    /// Hardware version (`DGT_MSG_HARDWARE_VERSION`, `0x96`).
    case hardwareVersion(major: Int, minor: Int)
}

/// Decodes a framed DGT message into a `DGTEvent`. Pure and total: every input
/// either yields a well-formed event or `nil` (unknown message ID, or a known
/// ID whose payload fails its length/range contract). It never traps on
/// malformed input — that's a wire concern, not a programmer error.
///
/// The `a8 ↔ a1` coordinate transform happens here, via `Square(dgtField:)`,
/// and the `DGTPiece → Piece` remap happens here, via `DGTPiece.piece`. Both
/// are the documented boundary at which hardware indexing is erased.
internal enum DGTDecoder {
    
    // MARK: Entry Point
    
    internal static func decode(_ frame: DGTFrame) -> DGTEvent? {
        guard let message = DGTMessage(rawValue: frame.message) else {
            return nil // Unknown/unhandled message ID — let the caller log raw.
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
    
    /// 64 payload bytes, one DGT piece code per field, in DGT field order
    /// (a8 = 0 … h1 = 63). Both the length and every piece code are validated;
    /// a single out-of-range byte fails the whole dump rather than silently
    /// placing a wrong piece.
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
    
    /// 2 payload bytes: field number (0–63), then the full piece code. (On a
    /// piece-detecting board byte 4 carries the piece, not a bare occupied
    /// flag — see the roadmap's target-hardware decision.)
    private static func decodeFieldUpdate(_ data: [UInt8]) -> DGTEvent? {
        guard data.count == 2,
              let square = Square(dgtField: Int(data[0])),
              let dgtPiece = DGTPiece(rawValue: data[1]) else {
            return nil
        }
        return .fieldUpdate(square: square, piece: dgtPiece.piece)
    }
    
    // MARK: Version (0x93 / 0x96)
    
    /// 2 payload bytes, each a 7-bit value: main version then sub version.
    private static func decodeVersion(_ data: [UInt8], hardware: Bool) -> DGTEvent? {
        guard data.count == 2 else { return nil }
        let major = Int(data[0] & 0x7F)
        let minor = Int(data[1] & 0x7F)
        return hardware
        ? .hardwareVersion(major: major, minor: minor)
        : .version(major: major, minor: minor)
    }
    
    // MARK: Text Info Messages (0x91 / 0x92 / 0xA2)
    
    /// ASCII payload (serial / long-serial / trademark). Trailing NULs and
    /// surrounding whitespace are stripped. Empty after trimming → `nil`.
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
