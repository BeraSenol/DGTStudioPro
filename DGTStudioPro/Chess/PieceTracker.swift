//
//  PieceTracker.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 03/04/2026.
//

/// A stable identity for one of the 32 starting pieces — the currency
/// `PieceTracker` assigns and `SquareView` keys its piece animation on.
/// Lives with the tracker because the `< 32` bound *is* the tracker's slot
/// design: White holds IDs 0–15 and Black 16–31, assigned once in
/// `.starting` and never reissued (promotion reuses the pawn's identity).
internal struct PieceID: Equatable, Hashable, Sendable {

    // MARK: Stored Properties
    internal let rawValue: UInt8

    // MARK: Computed Properties
    internal var isValid: Bool { rawValue < 32 }
}

internal struct PieceTracker: Equatable, Sendable {

    // MARK: Static Constants
    internal static let empty = PieceTracker()

    internal static let starting: PieceTracker = {
        var tracker = PieceTracker()
        var id: UInt8 = 0

        // White's Pieces: IDs 0–15
        // Black's Pieces: IDs 16–31
        for square in 0..<16 {
            tracker.pieceIdentities[square] = PieceID(rawValue: id)
            tracker.pieceIdentities[square + 48] = PieceID(rawValue: id + 16)
            id += 1
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

    // MARK: Instance Methods

    // Promotion reuses the pawn's identity on its new square.
    internal mutating func applyMove(_ move: Move) {
        if let captured = move.capturedSquare {
            pieceIdentities[captured] = nil
        }

        pieceIdentities[move.to] = pieceIdentities[move.from]
        pieceIdentities[move.from] = nil

        if move.isCastling, let rookFrom = move.rookFrom, let rookTo = move.rookTo {
            pieceIdentities[rookTo] = pieceIdentities[rookFrom]
            pieceIdentities[rookFrom] = nil
        }
    }
}
