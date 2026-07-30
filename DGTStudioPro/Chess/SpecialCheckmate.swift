//
//  SpecialCheckmate.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 22/07/2026.
//

/// A recognised checkmate *pattern*, computed at analysis time and stored on
/// the game (M-lib.4, D19′). Pure `Position`/`GameState` predicates over the
/// final position — no engine, and no last move needed (the recognised
/// patterns are positional; a case that ever needs the mating move gets it
/// threaded then, not speculatively now).
///
/// Case list (D19′'s deferred "exact case list is a delivery decision",
/// recorded here). Deliberately small and *tight* — each case is the iconic
/// motif, defined so it can't false-positive on an unrelated mate:
/// - **`smothered`** — a knight gives check and every on-board square around
///   the king holds the king's *own* piece (the board edge counts as a wall).
///   The checker is a knight by definition, so this never overlaps `backRank`.
/// - **`backRank`** — the king stands on its own back rank, a rook or queen
///   checks *along* that rank, and the squares directly in front of the king
///   are walled by its own pieces. Specifically the "trapped behind its own
///   pawns" motif: a back-rank major-piece mate whose escape squares are
///   covered by the *enemy* instead is a different motif and returns `nil`.
/// An ordinary mate (and any non-mate) classifies as `nil` — the enum carries
/// only real patterns, so a stored value always means something.
///
/// Rejected (for now): the broader "any mate delivered on the back rank"
/// reading (too loose), and enumerating the long tail (Anastasia's, Boden's,
/// Arabian, …) before a surface shows them — each is one fixture away.
internal enum SpecialCheckmate: String, Codable, Sendable, CaseIterable {
    case smothered
    case backRank

    // MARK: Display

    /// The enum's one user-facing rendering. Consumed by the smart-tag
    /// editor's motif picker — the seeded "Smothered Mates" tag carries a
    /// literal name, so this is not what keeps the two in step and shouldn't
    /// be documented as if it were.
    ///
    /// Deliberately unlocalized, matching the PGN tag labels' recorded
    /// stance, and deliberately *not* `rawValue.capitalized`, which renders
    /// `backRank` as "Backrank". That substitution looks like a
    /// simplification and is the reason this has a pin.
    internal var displayName: String {
        switch self {
        case .smothered: return "Smothered"
        case .backRank:  return "Back rank"
        }
    }

    // MARK: Classification
    
    /// Recognises the mate pattern in `state`, or `nil` when the position is
    /// not checkmate or is an ordinary mate. Self-checking (`isCheckmate`
    /// guarded) so it is total and testable without the analysis driver.
    internal static func classify(_ state: GameState) -> SpecialCheckmate? {
        guard state.isCheckmate else { return nil }
        
        let mated = state.activeColor          // the side to move is the mated side
        let attacker = mated.opponent
        let position = state.position
        guard let king = position.kingSquare(for: mated) else { return nil }
        
        if knightGivesCheck(at: king, by: attacker, in: position),
           squaresAreFriendly(Square.kingOffsets, of: king, color: mated, in: position) {
            return .smothered
        }
        
        if king.rank == backRank(for: mated),
           rankSliderGivesCheck(at: king, by: attacker, in: position),
           forwardSquaresAreFriendly(of: king, color: mated, in: position) {
            return .backRank
        }
        
        return nil
    }
    
    // MARK: Predicates
    
    /// `Position.hasPiece` is the shared step-and-compare walk — the same
    /// primitive `isSquareAttacked`'s three arms use. This carried a fourth
    /// copy of it.
    private static func knightGivesCheck(
        at king: Square, by attacker: PieceColor, in position: Position
    ) -> Bool {
        position.hasPiece(
            Piece(attacker, .knight),
            steppingFrom: king, offsets: Square.knightOffsets, maxFileDistance: 2
        )
    }
    
    /// A rook or queen checking *along the king's rank* — rays left and right,
    /// stopping at the first occupied square (which checks only if it's an
    /// enemy rook/queen). The file-distance guard stops a ray from wrapping
    /// past the h/a file onto the next rank.
    private static func rankSliderGivesCheck(
        at king: Square, by attacker: PieceColor, in position: Position
    ) -> Bool {
        // `rayHitsSlider` stops at the first occupied square and reports
        // whether it's an enemy rook/queen — exactly the per-direction `break`
        // this used to hand-roll.
        [1, -1].contains {
            position.rayHitsSlider(
                from: king, direction: $0,
                slider1: .rook, slider2: .queen,
                attacker: attacker
            )
        }
    }
    
    /// Every on-board neighbour of the king holds a friendly piece. Off-board
    /// neighbours (edge or corner) are walls and don't disqualify — a corner
    /// king boxed by two pawns is still smothered.
    private static func squaresAreFriendly(
        _ offsets: [Int], of king: Square, color: PieceColor, in position: Position
    ) -> Bool {
        for offset in offsets {
            let square = king + offset
            guard square.isOnBoard, abs(square.file - king.file) <= 1 else { continue }
            guard position[square].isColor(color) else { return false }
        }
        return true
    }
    
    /// The three squares one rank ahead of the king (toward the centre) all
    /// hold friendly pieces — the "walled in by its own men" half of a
    /// back-rank mate. On-board forward squares only; a wrap/edge is skipped.
    private static func forwardSquaresAreFriendly(
        of king: Square, color: PieceColor, in position: Position
    ) -> Bool {
        squaresAreFriendly(
            color == .white ? [7, 8, 9] : [-9, -8, -7],
            of: king, color: color, in: position
        )
    }
    
    /// White's back rank is rank 0 (the 1st rank); Black's is rank 7.
    private static func backRank(for color: PieceColor) -> Int {
        color == .white ? 0 : 7
    }
}
