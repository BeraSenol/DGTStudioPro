//
//  PieceID.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 10/04/2026.
//

internal struct PieceID: Equatable, Hashable, Sendable {
    
    // MARK: Stored Properties
    internal let rawValue: UInt8

    // MARK: Computed Properties
    internal var isValid: Bool { rawValue < 32 }
}
