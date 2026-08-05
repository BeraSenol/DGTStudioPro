/// The difference between two board positions, expressed as the squares that
/// lost a piece and the squares that now hold one. Pure value type.
///
/// This is the substrate the reconstruction engine reads to identify a move,
/// and the same shape `RecoveryGuidance` reads to compute its remove / place /
/// replace checklist and the board's attention/target highlights. It says
/// nothing about legality — it is a literal before/after delta.
internal struct DGTBoardDiff: Equatable {
    
    /// Squares that went from occupied to empty. Value = the piece that was
    /// lifted (a pure removal — a capture *destination* is in `placed`, since
    /// it ends up occupied).
    internal let vacated: [Square: Piece]
    
    /// Squares that are now occupied and differ from before. Value = the piece
    /// now there. Covers plain placements (empty → piece) and capture
    /// destinations (enemy → mover).
    internal let placed: [Square: Piece]
    
    internal var isEmpty: Bool { vacated.isEmpty && placed.isEmpty }
    
    /// Every square the two positions disagree about. The two maps are
    /// disjoint by construction — each differing square lands in exactly one
    /// of them, decided by whether it ends up occupied — so this is a
    /// concatenation wearing a union's clothes, and `changedSquares.count`
    /// always equals `vacated.count + placed.count`.
    ///
    /// No production caller: `DGTReconstructor`, `RecoveryGuidance` and
    /// `DGTDebugFormat` each read the two maps directly, because every one of
    /// them needs to know *which* side a square fell on. Kept as the accessor
    /// that states the disjointness invariant they all depend on and none of
    /// them asserts — the `FEN.legalMoves()` category, test-only by decision.
    internal var changedSquares: Set<Square> {
        Set(vacated.keys).union(placed.keys)
    }
    
    internal init(from before: Position, to after: Position) {
        var vacated: [Square: Piece] = [:]
        var placed: [Square: Piece] = [:]
        for square in Square.all {
            let old = before[square]
            let new = after[square]
            guard old != new else { continue }
            if new.isOccupied {
                placed[square] = new
            } else {
                vacated[square] = old
            }
        }
        self.vacated = vacated
        self.placed = placed
    }
}
