/// The difference between two positions: squares that lost a piece, squares that now hold one.
///
/// **A capture is invisible as a capture.** exd5 gives `vacated[e4]` and `placed[d5]`; the taken
/// black pawn appears nowhere, because d5 ends up occupied. So this reports *what changed*, never
/// *what happened* - pairing a vacate with a place is inference, and that has one home,
/// `DGTReconstructor`, which verifies against a whole position rather than reasoning from here.
struct DGTBoardDiff: Equatable {
    
    /// Squares that went from occupied to empty; the value is the piece that was **lifted**. Pure
    /// removals only - a capture destination lives in `placed`, since it ends up occupied.
    let vacated: [Square: Piece]
    
    /// Squares that are now occupied and differ from before; the value is the piece **now there**.
    /// Covers plain placements (empty → piece) and capture destinations (enemy → mover).
    let placed: [Square: Piece]
    
    var isEmpty: Bool { vacated.isEmpty && placed.isEmpty }
    
    /// Every disagreeing square. **Test-only by decision** (waiver register).
    var changedSquares: Set<Square> {
        Set(vacated.keys).union(placed.keys)
    }
    
    /// The two maps are disjoint **by construction**: one branch per changed square, decided by end
    /// occupancy, so no square can reach both.
    init(from before: Position, to after: Position) {
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
