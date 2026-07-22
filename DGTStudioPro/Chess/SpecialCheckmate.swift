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
           allNeighboursAreFriendly(of: king, color: mated, in: position) {
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
    
    /// King-neighbour index offsets (shared with the move generator and attack
    /// scanner); each use pairs it with a `≤ 1` file-distance guard to reject
    /// board-edge wraparound.
    private static let neighbourOffsets = [1, 7, 8, 9, -1, -7, -8, -9]
    
    private static func knightGivesCheck(
        at king: Square, by attacker: PieceColor, in position: Position
    ) -> Bool {
        let knight = Piece(attacker, .knight)
        for offset in [17, 15, 10, 6, -6, -10, -15, -17] {
            let from = king + offset
            guard from.isOnBoard, abs(from.file - king.file) <= 2 else { continue }
            if position[from] == knight { return true }
        }
        return false
    }
    
    /// A rook or queen checking *along the king's rank* — rays left and right,
    /// stopping at the first occupied square (which checks only if it's an
    /// enemy rook/queen). The file-distance guard stops a ray from wrapping
    /// past the h/a file onto the next rank.
    private static func rankSliderGivesCheck(
        at king: Square, by attacker: PieceColor, in position: Position
    ) -> Bool {
        for direction in [1, -1] {
            var previous = king
            var target = king + direction
            while target.isOnBoard, abs(target.file - previous.file) <= 1 {
                let piece = position[target]
                if let type = piece.type {
                    if piece.color == attacker, type == .rook || type == .queen {
                        return true
                    }
                    break   // any piece blocks the rest of this ray
                }
                previous = target
                target += direction
            }
        }
        return false
    }
    
    /// Every on-board neighbour of the king holds a friendly piece. Off-board
    /// neighbours (edge or corner) are walls and don't disqualify — a corner
    /// king boxed by two pawns is still smothered.
    private static func allNeighboursAreFriendly(
        of king: Square, color: PieceColor, in position: Position
    ) -> Bool {
        for offset in neighbourOffsets {
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
        let forwardOffsets = color == .white ? [7, 8, 9] : [-9, -8, -7]
        for offset in forwardOffsets {
            let square = king + offset
            guard square.isOnBoard, abs(square.file - king.file) <= 1 else { continue }
            guard position[square].isColor(color) else { return false }
        }
        return true
    }
    
    /// White's back rank is rank 0 (the 1st rank); Black's is rank 7.
    private static func backRank(for color: PieceColor) -> Int {
        color == .white ? 0 : 7
    }
}
