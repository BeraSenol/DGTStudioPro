import Testing
@testable import DGTStudioPro

/// `PieceTracker` — the per-square identity map (same rook through a castle, promoted pawn's
/// identity on the queen). Legality-agnostic; not @MainActor — pure `Sendable` values.
@Suite("Piece Tracker")
struct PieceTrackerTests {
    
    // MARK: Constants
    
    @Test func emptyTrackerHasNoIdentities() {
        let tracker = PieceTracker.empty
        for square in Square.all {
            #expect(tracker[square] == nil)
        }
    }
    
    /// The starting layout: White's 16 pieces take IDs 0–15 on squares a1–h2,
    /// Black's take IDs 16–31 on a7–h8, and the four empty middle ranks hold
    /// nothing. Pinned both at the corners of each block and as a whole — every
    /// ID 0–31 present exactly once.
    @Test func startingTrackerMatchesStandardLayout() {
        let tracker = PieceTracker.starting
        
        // Block corners: white back rank + pawns, black pawns + back rank.
        #expect(tracker[Squares.a1] == PieceID(rawValue: 0))
        #expect(tracker[Squares.h1] == PieceID(rawValue: 7))
        #expect(tracker[Squares.a2] == PieceID(rawValue: 8))
        #expect(tracker[Squares.h2] == PieceID(rawValue: 15))
        #expect(tracker[Squares.a7] == PieceID(rawValue: 16))
        #expect(tracker[Squares.h7] == PieceID(rawValue: 23))
        #expect(tracker[Squares.a8] == PieceID(rawValue: 24))
        #expect(tracker[Squares.h8] == PieceID(rawValue: 31))
        
        // The middle four ranks (3–6) are empty.
        for square in Squares.a3...Squares.h6 {
            #expect(tracker[square] == nil)
        }
        
        // Every identity 0–31 appears on exactly one square.
        var seen: [PieceID: Square] = [:]
        for square in Square.all {
            guard let id = tracker[square] else { continue }
            #expect(seen[id] == nil, "Identity \(id.rawValue) appears on two squares")
            seen[id] = square
        }
        #expect(seen.count == 32)
        #expect(Set(seen.keys.map { Int($0.rawValue) }) == Set(0..<32))
    }
    
    // MARK: Subscript
    
    @Test func subscriptSetsAndClears() {
        var tracker = PieceTracker.empty
        tracker[Squares.e4] = PieceID(rawValue: 5)
        #expect(tracker[Squares.e4] == PieceID(rawValue: 5))
        tracker[Squares.e4] = nil
        #expect(tracker[Squares.e4] == nil)
    }
    
    // MARK: applyMove — Quiet Move
    
    /// A plain push moves the identity from the origin to the destination and
    /// leaves every other square untouched. From the starting tracker, e2's
    /// identity is 12 (a2=8 … e2=12).
    @Test func quietMoveRelocatesIdentity() {
        var tracker = PieceTracker.starting
        let move = Move.make(
            from: Squares.e2, to: Squares.e4,
            pieceType: .pawn, pieceColor: .white,
            isDoublePawnPush: true
        )
        tracker.applyMove(move)
        
        #expect(tracker[Squares.e4] == PieceID(rawValue: 12))
        #expect(tracker[Squares.e2] == nil)
        #expect(tracker[Squares.a1] == PieceID(rawValue: 0))   // untouched
    }
    
    // MARK: applyMove — Capture
    
    /// A capture clears the victim's identity, then lands the mover. Geometrically artificial on
    /// purpose — the tracker is legality-agnostic.
    @Test func captureReplacesVictimIdentity() {
        var tracker = PieceTracker.starting
        let capture = Move.make(
            from: Squares.a1, to: Squares.a7,
            pieceType: .rook, pieceColor: .white,
            capturedPieceType: .pawn
        )
        tracker.applyMove(capture)
        
        #expect(tracker[Squares.a7] == PieceID(rawValue: 0))
        #expect(tracker[Squares.a1] == nil)
        #expect(Square.all.contains { tracker[$0] == PieceID(rawValue: 16) } == false)
    }
    
    // MARK: applyMove — En Passant
    
    /// En passant is the case a destination-keyed tracker gets wrong: the
    /// captured pawn leaves a square *other* than the mover's destination. White
    /// pawn e5→d6 must clear d5 (the victim) and leave d6 holding the mover —
    /// d5 must end empty.
    @Test func enPassantClearsTheOffsetSquare() {
        var tracker = PieceTracker.empty
        tracker[Squares.e5] = PieceID(rawValue: 4)    // the mover
        tracker[Squares.d5] = PieceID(rawValue: 20)   // the en-passant victim
        let ep = Move.make(
            from: Squares.e5, to: Squares.d6,
            pieceType: .pawn, pieceColor: .white,
            capturedPieceType: .pawn,
            isEnPassant: true
        )
        tracker.applyMove(ep)
        
        #expect(tracker[Squares.d6] == PieceID(rawValue: 4))
        #expect(tracker[Squares.e5] == nil)
        #expect(tracker[Squares.d5] == nil)   // victim left the offset square, not `to`
    }
    
    // MARK: applyMove — Castling
    
    /// Castling moves two identities: the king e1→g1 and, crucially, the rook
    /// h1→f1. The rook keeps its own identity on its new square.
    @Test func kingsideCastlingRelocatesBothIdentities() {
        var tracker = PieceTracker.empty
        tracker[Squares.e1] = PieceID(rawValue: 4)    // king
        tracker[Squares.h1] = PieceID(rawValue: 7)    // rook
        let castle = Move.make(
            from: Squares.e1, to: Squares.g1,
            pieceType: .king, pieceColor: .white,
            isCastling: true
        )
        tracker.applyMove(castle)
        
        #expect(tracker[Squares.g1] == PieceID(rawValue: 4))
        #expect(tracker[Squares.e1] == nil)
        #expect(tracker[Squares.f1] == PieceID(rawValue: 7))   // rook identity moved too
        #expect(tracker[Squares.h1] == nil)
    }
    
    /// Queenside mirror: king e1→c1, rook a1→d1.
    @Test func queensideCastlingRelocatesBothIdentities() {
        var tracker = PieceTracker.empty
        tracker[Squares.e1] = PieceID(rawValue: 4)
        tracker[Squares.a1] = PieceID(rawValue: 0)
        let castle = Move.make(
            from: Squares.e1, to: Squares.c1,
            pieceType: .king, pieceColor: .white,
            isCastling: true
        )
        tracker.applyMove(castle)
        
        #expect(tracker[Squares.c1] == PieceID(rawValue: 4))
        #expect(tracker[Squares.e1] == nil)
        #expect(tracker[Squares.d1] == PieceID(rawValue: 0))
        #expect(tracker[Squares.a1] == nil)
    }
    
    // MARK: applyMove — Promotion
    
    /// Promotion reuses the pawn's identity on its new square — the physical
    /// piece is the same one the player pushed, now standing in as a queen.
    @Test func promotionPreservesPawnIdentity() {
        var tracker = PieceTracker.empty
        tracker[Squares.a7] = PieceID(rawValue: 0)
        let promotion = Move.make(
            from: Squares.a7, to: Squares.a8,
            pieceType: .pawn, pieceColor: .white,
            promotionType: .queen
        )
        tracker.applyMove(promotion)
        
        #expect(tracker[Squares.a8] == PieceID(rawValue: 0))
        #expect(tracker[Squares.a7] == nil)
    }
    
    /// Capture-promotion combines both: the victim's identity is cleared from
    /// the destination and the promoting pawn keeps its identity there.
    @Test func capturePromotionClearsVictimAndKeepsMover() {
        var tracker = PieceTracker.empty
        tracker[Squares.a7] = PieceID(rawValue: 0)    // promoting pawn
        tracker[Squares.b8] = PieceID(rawValue: 20)   // victim on the promotion square
        let capturePromotion = Move.make(
            from: Squares.a7, to: Squares.b8,
            pieceType: .pawn, pieceColor: .white,
            capturedPieceType: .rook,
            promotionType: .queen
        )
        tracker.applyMove(capturePromotion)
        
        #expect(tracker[Squares.b8] == PieceID(rawValue: 0))
        #expect(tracker[Squares.a7] == nil)
    }
}
