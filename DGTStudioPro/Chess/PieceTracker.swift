/// A stable identity for one of the 32 starting pieces - and the key piece animation glides on
/// (D47′). `PieceIdentity` resolves a square to `.tracked(PieceID)`, and a vacate is paired with a
/// place only when both carry the same one; anything else can merely fade.
///
/// White holds IDs 0-15 and Black 16-31, assigned once in `.starting` and never reissued. That
/// range is a fact about construction, not an enforced bound - `PieceID(rawValue:)` accepts any
/// `UInt8`.
struct PieceID: Equatable, Hashable, Sendable {

    // MARK: Stored Properties
    let rawValue: UInt8
}

/// One identity per occupied square. `Game` and `LiveGame` keep a tracker per ply, so stepping
/// through a game carries identities with it rather than re-deriving them.
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

    /// **The same load-bearing step order as `Position.applying`**: for an ordinary capture
    /// `capturedSquare == to`, so the clear must precede the copy or the mover arrives with no
    /// identity. Promotion needs no case of its own - the ID simply moves, and `promotionType` is
    /// never read here.
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
