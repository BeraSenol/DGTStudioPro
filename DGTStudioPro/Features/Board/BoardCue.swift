/// What a landed move sounds like. Pure, nonisolated, `GameState`-typed — the classification is
/// the part worth pinning, and it is a value question with no I/O in it (the shape, applied to
/// a presentation concern rather than a fold).
///
/// **One cue per move, most specific wins.** A capture that gives check plays `check`, not both:
/// two samples fired at one instant is mush, and the more informative fact is the one worth
/// hearing. Stated here because "capture+check plays capture" is the equally defensible rule and
/// a future reader will wonder which was chosen.
enum BoardCue: String, CaseIterable, Sendable {
    case move
    case capture
    case check
    case checkmate

    /// Naming the sample is `BoardSoundSet.resourceName(for:)`'s job, not this type's — a
    /// cue is one of four fixed questions and a set is a growing list, so the convention lives
    /// with the axis that varies. What stays here is that `rawValue` is half of that filename,
    /// which is why these cases are pinned on literals in the suite: renaming one renames a
    /// bundled resource in three sets at once, and the symptom is silence.
    ///
    /// The cue `move` earns, given the position it lands in.
    ///
    /// `landing` is the state *after* the move, so `isInCheck` is asked of the side receiving the
    /// move — which is what "check" means. Ordering is deliberate: `isInCheck` is a single attack
    /// scan and `legalMoves()` is a full generation, so the expensive question is asked only in
    /// the positions that could answer `checkmate` at all. That is `GameState+SAN`'s own
    /// optimisation, not a new one — `isCheckmate` would pay the scan twice.
    ///
    /// Stalemate deliberately has no cue and falls through to `move`/`capture`: the position is
    /// drawn, the *move* was ordinary, and there is no sample for it. Named so the omission reads
    /// as a decision.
    static func cue(for move: Move, landing: GameState) -> BoardCue {
        if landing.isInCheck {
            return landing.legalMoves().isEmpty ? .checkmate : .check
        }
        // En passant included: movegen stamps `capturedPieceType: .pawn` on it, so the bit test
        // covers the one capture whose destination square was empty.
        return move.isCapture ? .capture : .move
    }
}
