//
//  CastlingRights.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 30/03/2026.
//

// MARK: Castling Side
internal enum CastlingSide: Sendable {
    case kingSide
    case queenSide
}

// MARK: Castling Rights
internal struct CastlingRights: Codable, Equatable, Hashable, Sendable {
    
    // MARK: Static Constants
    private static let whiteKingSideMask: UInt8  = 0b0001
    private static let whiteQueenSideMask: UInt8 = 0b0010
    private static let blackKingSideMask: UInt8  = 0b0100
    private static let blackQueenSideMask: UInt8 = 0b1000
    
    internal static let none = CastlingRights(rawValue: 0b0000)
    internal static let all  = CastlingRights(rawValue: 0b1111)
    
    // MARK: Stored Properties
    internal private(set) var rawValue: UInt8
    
    // MARK: Computed Properties
    internal var whiteKingSide:  Bool { rawValue & Self.whiteKingSideMask  != 0 }
    internal var whiteQueenSide: Bool { rawValue & Self.whiteQueenSideMask != 0 }
    internal var blackKingSide:  Bool { rawValue & Self.blackKingSideMask  != 0 }
    internal var blackQueenSide: Bool { rawValue & Self.blackQueenSideMask != 0 }
    
    internal var fen: String {
        guard rawValue != 0 else { return "-" }
        var result = ""
        if whiteKingSide  { result.append("K") }
        if whiteQueenSide { result.append("Q") }
        if blackKingSide  { result.append("k") }
        if blackQueenSide { result.append("q") }
        return result
    }
    
    // MARK: Initializers
    internal init() {
        rawValue = Self.all.rawValue
    }
    
    internal init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    // MARK: Instance Methods
    internal func has(_ color: PieceColor, _ side: CastlingSide) -> Bool {
        rawValue & Self.mask(for: color, side).rawValue != 0
    }
    
    internal mutating func revoke(_ rights: CastlingRights) {
        rawValue &= ~rights.rawValue
    }
    
    internal mutating func revokeAll(for color: PieceColor) {
        revoke(
            color == .white
            ? CastlingRights(rawValue: Self.whiteKingSideMask | Self.whiteQueenSideMask)
            : CastlingRights(rawValue: Self.blackKingSideMask | Self.blackQueenSideMask)
        )
    }
    
    // MARK: Static Methods
    internal static func mask(for color: PieceColor, _ side: CastlingSide) -> CastlingRights {
        switch (color, side) {
        case (.white, .kingSide):  return CastlingRights(rawValue: whiteKingSideMask)
        case (.white, .queenSide): return CastlingRights(rawValue: whiteQueenSideMask)
        case (.black, .kingSide):  return CastlingRights(rawValue: blackKingSideMask)
        case (.black, .queenSide): return CastlingRights(rawValue: blackQueenSideMask)
        }
    }
}
