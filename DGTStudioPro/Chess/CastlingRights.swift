//
//  CastlingRights.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 30/03/2026.
//

enum CastlingSide: Sendable {
    case kingSide
    case queenSide
}

struct CastlingRights: Codable, Equatable, Hashable, Sendable {
    
    // bit 0 — white kingside
    // bit 1 — white queenside
    // bit 2 — black kingside
    // bit 3 — black queenside
    private(set) var rawValue: UInt8
    
    static let whiteKingSideMask: UInt8 = 0b0001
    static let whiteQueenSideMask: UInt8 = 0b0010
    static let blackKingSideMask: UInt8 = 0b0100
    static let blackQueenSideMask: UInt8 = 0b1000
    
    static let none = CastlingRights(rawValue: 0b0000)
    static let all = CastlingRights(rawValue: 0b1111)
    
    var whiteKingSide: Bool { rawValue & Self.whiteKingSideMask != 0 }
    var whiteQueenSide: Bool { rawValue & Self.whiteQueenSideMask != 0 }
    var blackKingSide: Bool { rawValue & Self.blackKingSideMask != 0 }
    var blackQueenSide: Bool { rawValue & Self.blackQueenSideMask != 0 }
    
    init() {
        rawValue = Self.all.rawValue
    }
    
    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    func has(_ color: PieceColor, _ side: CastlingSide) -> Bool {
        rawValue & Self.mask(for: color, side).rawValue != 0
    }
    
    mutating func revoke(_ rights: CastlingRights) {
        rawValue &= ~rights.rawValue
    }
    
    mutating func revokeAll(for color: PieceColor) {
        revoke(
            color == .white
            ? CastlingRights(rawValue: Self.whiteKingSideMask | Self.whiteQueenSideMask)
            : CastlingRights(rawValue: Self.blackKingSideMask | Self.blackQueenSideMask)
        )
    }
    
    static func mask(for color: PieceColor, _ side: CastlingSide) -> CastlingRights {
        switch (color, side) {
        case (.white, .kingSide): return CastlingRights(rawValue: whiteKingSideMask)
        case (.white, .queenSide): return CastlingRights(rawValue: whiteQueenSideMask)
        case (.black, .kingSide): return CastlingRights(rawValue: blackKingSideMask)
        case (.black, .queenSide): return CastlingRights(rawValue: blackQueenSideMask)
        }
    }
    
    var fen: String {
        guard rawValue != 0 else { return "-" }
        var result = ""
        if whiteKingSide  { result.append("K") }
        if whiteQueenSide { result.append("Q") }
        if blackKingSide  { result.append("k") }
        if blackQueenSide { result.append("q") }
        return result
    }
}
