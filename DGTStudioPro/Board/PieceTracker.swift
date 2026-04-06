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
    
    // MARK: - Static Constants
    internal static let empty = PieceTracker()
    
    // MARK: - Stored Properties
    private var pieceIdentities: [PieceID?]
    
    // MARK: - Initializers
    internal init() {
        pieceIdentities = [PieceID?](repeating: nil, count: Square.count)
    }
    
    // MARK: - Subscripts
    internal subscript (square: Square) -> PieceID? {
        pieceIdentities[square]
    }
}
