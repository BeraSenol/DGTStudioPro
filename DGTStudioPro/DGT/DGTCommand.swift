//
//  DGTCommand.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 13/04/2026.
//

internal enum DGTCommand: UInt8, Sendable {
    case sendReset              = 0x40
    case sendBoard              = 0x42
    case sendUpdateBoard        = 0x44
    case returnSerialNumber     = 0x45
    case sendTrademark          = 0x47
    case sendHardwareVersion    = 0x48
    case sendVersion            = 0x4D
    case returnLongSerialNumber = 0x55
}

internal enum DGTMessage: UInt8, Sendable {
    case boardDump        = 0x86
    case fieldUpdate      = 0x8E
    case serialNumber     = 0x91
    case trademark        = 0x92
    case version          = 0x93
    case hardwareVersion  = 0x96
    case longSerialNumber = 0xA2
}

internal enum DGTPiece: UInt8, Sendable {
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
    /// Converts this DGT piece to the app's `Piece` type.
    internal var piece: Piece {
        Self.pieceLookup[Int(rawValue)]
    }

    // MARK: Static Constants
    private static let pieceLookup: [Piece] = [
        .empty,        // 0
        .whitePawn,    // 1
        .whiteRook,    // 2
        .whiteKnight,  // 3
        .whiteBishop,  // 4
        .whiteKing,    // 5
        .whiteQueen,   // 6
        .blackPawn,    // 7
        .blackRook,    // 8
        .blackKnight,  // 9
        .blackBishop,  // 10
        .blackKing,    // 11
        .blackQueen,   // 12
    ]
}
