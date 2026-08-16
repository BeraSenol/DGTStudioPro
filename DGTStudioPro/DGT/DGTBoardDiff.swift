/// The difference between two positions: squares that lost a piece, squares that now hold one.
struct DGTBoardDiff: Equatable {
    
    /// Squares that went from occupied to empty. Value = the piece that was
    /// lifted (a pure removal - a capture *destination* is in `placed`, since
    /// it ends up occupied).
    let vacated: [Square: Piece]
    
    /// Squares that are now occupied and differ from before. Value = the piece
    /// now there. Covers plain placements (empty → piece) and capture
    /// destinations (enemy → mover).
    let placed: [Square: Piece]
    
    var isEmpty: Bool { vacated.isEmpty && placed.isEmpty }
    
    /// Every disagreeing square. The two maps are disjoint by construction (decided by end
    /// occupancy) - asserted by the suite; this accessor is test-only by decision.
    var changedSquares: Set<Square> {
        Set(vacated.keys).union(placed.keys)
    }
    
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
