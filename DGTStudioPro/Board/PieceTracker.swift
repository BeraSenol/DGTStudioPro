//
//  PieceTracker.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 03/04/2026.
//

// MARK: - Piece ID
internal struct PieceID: Equatable, Hashable, Sendable {
    internal let rawValue: UInt8
}

// MARK: - Piece Tracker
internal struct PieceTracker: Equatable, Sendable {

    // MARK: - Stored Properties
    internal var identities: [PieceID?]

    // MARK: - Initializers
    private init() {
        identities = [PieceID?](repeating: nil, count: Square.count)
    }

    // MARK: - Subscripts
    internal subscript (square: Square) -> PieceID? {
        identities[square]
    }
}
