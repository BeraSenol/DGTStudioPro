/// A stable identity for one of the 32 starting pieces — the currency
/// `PieceTracker` assigns, and the one `SquareView` would key piece animation
/// on. It doesn't yet: the parameter is threaded and unread, waiting on the
/// tracker-parity work that would make the physical mirror safe to animate.
/// Lives with the tracker because the `< 32` bound *is* the tracker's slot
/// design: White holds IDs 0–15 and Black 16–31, assigned once in
/// `.starting` and never reissued (promotion reuses the pawn's identity).
struct PieceID: Equatable, Hashable, Sendable {
    
    // MARK: Stored Properties
    let rawValue: UInt8
}

struct PieceTracker: Equatable, Sendable {
    
    // MARK: Static Constants
    static let empty = PieceTracker()
    
    static let starting: PieceTracker = {
        var tracker = PieceTracker()
        
        // White's pieces take IDs 0–15 on a1–h2; Black's take 16–31 on a7–h8.
        // The ID tracks the square index exactly, so no separate counter.
        for square in 0 ..< 16 {
            tracker.pieceIdentities[square]      = PieceID(rawValue: UInt8(square))
            tracker.pieceIdentities[square + 48] = PieceID(rawValue: UInt8(square) + 16)
        }
        
        return tracker
    }()
    
    // MARK: Stored Properties
    private var pieceIdentities: [PieceID?]
    
    // MARK: Initializers
    init() {
        pieceIdentities = [PieceID?](repeating: nil, count: Square.count)
    }
    
    // MARK: Subscripts
    subscript(square: Square) -> PieceID? {
        get { pieceIdentities[square] }
        set { pieceIdentities[square] = newValue }
    }
    
    // MARK: Instance Methods
    
    /// Promotion reuses the pawn's identity on its new square.
    mutating func applyMove(_ move: Move) {
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
