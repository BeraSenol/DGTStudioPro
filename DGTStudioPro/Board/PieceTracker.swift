//
//  PieceTracker.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 03/04/2026.
//

// MARK: Piece Tracker
internal struct PieceTracker: Equatable, Sendable {

    // MARK: Static Constants
    internal static let empty = PieceTracker()

    internal static let starting: PieceTracker = {
        var tracker = PieceTracker()
        var id: UInt8 = 0

        // IDs 0–15: white pieces on ranks 1–2
        for square in 0..<16 {
            tracker.pieceIdentities[square] = PieceID(rawValue: id)
            id &+= 1
        }

        // IDs 16–31: black pieces on ranks 7–8
        for square in 48..<64 {
            tracker.pieceIdentities[square] = PieceID(rawValue: id)
            id &+= 1
        }

        return tracker
    }()

    // MARK: Stored Properties
    private var pieceIdentities: [PieceID?]

    // MARK: Initializers
    internal init() {
        pieceIdentities = [PieceID?](repeating: nil, count: Square.count)
    }

    // MARK: Subscripts
    internal subscript(square: Square) -> PieceID? {
        get { pieceIdentities[square] }
        set { pieceIdentities[square] = newValue }
    }

    // MARK: - Instance Methods
    internal mutating func applyMove(_ move: Move) {
        if let captured = move.capturedSquare {
            pieceIdentities[captured] = PieceID.none
        }

        pieceIdentities[move.to] = pieceIdentities[move.from]
        pieceIdentities[move.from] = PieceID.none

        if move.isCastling, let rookFrom = move.rookFrom, let rookTo = move.rookTo {
            pieceIdentities[rookTo] = pieceIdentities[rookFrom]
            pieceIdentities[rookFrom] = PieceID.none
        }
    }
}
