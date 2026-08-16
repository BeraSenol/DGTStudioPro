/// What a landed move sounds like. Pure, nonisolated, `GameState`-typed - the classification is
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

    /// The cue `move` earns, given the position it lands in. `landing` is the state *after* the
    /// move, so `isInCheck` is asked of the side receiving it - which is what "check" means.
    ///
    /// Ordering is deliberate: `isInCheck` is one attack scan, `legalMoves()` a full generation,
    /// so the expensive question runs only where `checkmate` is possible (`GameState+SAN`'s own
    /// optimisation - `isCheckmate` would pay the scan twice). Filenames are
    /// `BoardSoundSet.resourceName(for:)`'s job; `rawValue` is half of one, which is why the
    /// cases are pinned on literals in the suite. Stalemate deliberately has no cue and falls
    /// through to `move`/`capture`: the position is drawn, the move was ordinary, no sample.
    static func cue(for move: Move, landing: GameState) -> BoardCue {
        if landing.isInCheck {
            return landing.legalMoves().isEmpty ? .checkmate : .check
        }
        // En passant included: movegen stamps `capturedPieceType: .pawn` on it, so the bit test
        // covers the one capture whose destination square was empty.
        return move.isCapture ? .capture : .move
    }
}
