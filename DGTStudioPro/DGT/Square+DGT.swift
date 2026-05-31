//
//  Square+DGT.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 25/05/2026.
//

// The DGT board numbers its fields a8 = 0 … h1 = 63 — "row by row, in normal
// reading sequence, counting from the top-left square when the connector is on
// the left hand" (DGT Chessboard Communication Protocol). The app's `Square`
// uses a1 = 0 … h8 = 63.
//
// This conversion lives at the protocol decode boundary, on `Square` itself,
// so that **nothing downstream of the decoder ever sees a DGT field index**.
// The chess core (perft/FEN/SAN) stays a1-indexed; adopting the board's
// a8-indexing into the core — as the predecessor did — would silently break
// all of it.
//
// The map is `(7 − rank)*8 + file` in both directions: it only mirrors the
// rank, so it is its own inverse. The tests pin the bijection and the
// round-trip explicitly rather than trusting that symmetry by eye.
extension Square {
    
    /// Converts a DGT field index (a8 = 0 … h1 = 63) to an app `Square`
    /// (a1 = 0 … h8 = 63). Returns `nil` for out-of-range input so a corrupt
    /// field byte off the wire surfaces as a decode failure, not a crash.
    internal init?(dgtField field: Int) {
        guard UInt(bitPattern: field) < Square.count else { return nil }
        self = (7 - field / 8) * 8 + (field % 8)
    }
    
    /// The DGT field index (a8 = 0 … h1 = 63) for this app `Square`. The
    /// inverse of `init(dgtField:)`; used when encoding outbound coordinates.
    internal var dgtField: Int {
        assert(isOnBoard, "dgtField called on off-board square \(self)")
        return (7 - rank) * 8 + file
    }
}
