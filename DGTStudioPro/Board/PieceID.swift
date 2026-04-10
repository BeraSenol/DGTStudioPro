//
//  PieceID.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 10/04/2026.
//

// MARK: Piece ID
internal struct PieceID: Equatable, Hashable, Sendable {

    // MARK: Static Constants
    internal static let none = PieceID(rawValue: 0xFF)

    // MARK: Stored Properties
    internal let rawValue: UInt8

    // MARK: Computed Properties
    internal var isValid: Bool { rawValue < 32 }
}
