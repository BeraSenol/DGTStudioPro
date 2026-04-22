//
//  Move.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 03/04/2026.
//

internal struct Move: Equatable, Hashable, Sendable {
    // Bits  0-5:  from square
    // Bits  6-11: to square
    // Bits 12-14: piece type (1-6)
    // Bit  15:    piece color (0=white, 1=black)
    // Bits 16-18: captured piece type (0=none, 1-6)
    // Bits 19-21: promotion type (0=none, 1-6)
    // Bit  22:    castling flag
    // Bit  23:    en passant flag
    // Bit  24:    double pawn push flag
    // Bits 25-31: unused
    
    // MARK: Static Constants
    private static let toShift:            Int = 6
    private static let pieceTypeShift:     Int = 12
    private static let pieceColorShift:    Int = 15
    private static let capturedTypeShift:  Int = 16
    private static let promotionTypeShift: Int = 19
    
    private static let castlingFlag:       UInt32 = 1 << 22
    private static let enPassantFlag:      UInt32 = 1 << 23
    private static let doublePawnPushFlag: UInt32 = 1 << 24

    private static let kingSideKingFile: Int = 6

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
    
    internal var isCapture: Bool {
        capturedPieceType != nil
    }
    
    internal var capturedSquare: Square? {
        guard isCapture else { return nil }
        if isEnPassant {
            return pieceColor == .white ? to - 8 : to + 8
        }
        return to
    }
    
    internal var rookFrom: Square? {
        guard isCastling else { return nil }
        return to.file == Self.kingSideKingFile ? to + 1 : to - 2
    }
    
    internal var rookTo: Square? {
        guard isCastling else { return nil }
        return to.file == Self.kingSideKingFile ? to - 1 : to + 1
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
