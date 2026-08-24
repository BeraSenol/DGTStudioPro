/// One `info` line's search state, white-relative - what `analyze` yields. `evaluation` is
/// non-optional because the engine only constructs one from a scored line (the scoreless-chatter guard).
struct EngineProgress: Equatable, Sendable {

    // MARK: Stored Properties

    /// The score, already flipped to white's perspective by
    /// ``UCIScore/toEvaluation(sideToMove:)``. The one field the model stores; the three below are
    /// the queue window's live read-out and never reach a `PGN` (D71′).
    let evaluation: Evaluation

    /// Nominal search depth in plies - the iteration this line came from,
    /// counting up to the requested depth.
    let depth: Int?

    /// Positions searched so far in this ply's search.
    let nodes: Int?

    /// Search speed. Reported by the engine rather than derived from
    /// `nodes / time`: Stockfish computes it over its own interval and
    /// re-deriving here would disagree with what every other UCI front end
    /// shows for the same line.
    let nodesPerSecond: Int?

    // The synthesized memberwise init is the only one, deliberately. A hand-written twin stood here
    // until 24 Aug 2026 adding `= nil` defaults that nothing used - the single construction site
    // (`StockfishEngine`) passes all four - while suppressing the init it was copying.
}
