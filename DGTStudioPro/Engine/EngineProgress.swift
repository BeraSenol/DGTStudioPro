/// One `info` line's worth of search state, white-relative — what
/// ``StockfishEngine/analyze(fen:depth:)`` yields.
///
/// **The stream carried a bare ``Evaluation`` until 6 Aug 2026.** That was the
/// only field anything consumed: the driver wrote it per ply and discarded the
/// rest of the line. The queue window wants to *show the search*, which means
/// depth, node count and speed, and those arrive on the same line as the score
/// — so widening the stream costs nothing at the parser (``UCIInfo`` has parsed
/// all four since it was written) and keeps one ordered channel instead of a
/// stream plus a side-band of observable state that could go stale against it.
///
/// **Every field but the evaluation is optional, and that is UCI's fault rather
/// than defensiveness.** An engine may print `info depth 20 … score cp 31` with
/// no `nodes`, or a `score` with no `depth` on an aspiration re-search. The
/// evaluation is non-optional because ``StockfishEngine`` only constructs one of
/// these when a line carried a score — a progress value with nothing to report
/// is a line we drop rather than a case to render.
///
/// `Sendable` and free of I/O, so it crosses the actor hop out of the engine
/// without ceremony — the chess-core purity rule applied to a type that is not
/// in the chess core but wants the same property.
internal struct EngineProgress: Equatable, Sendable {

    // MARK: Stored Properties

    /// The score, already flipped to white's perspective by
    /// ``UCIScore/toEvaluation(sideToMove:)``. The one field every consumer
    /// has always wanted, and the only one the model stores.
    internal let evaluation: Evaluation

    /// Nominal search depth in plies — the iteration this line came from,
    /// counting up to the requested depth.
    internal let depth: Int?

    /// Positions searched so far in this ply's search.
    internal let nodes: Int?

    /// Search speed. Reported by the engine rather than derived from
    /// `nodes / time`: Stockfish computes it over its own interval and
    /// re-deriving here would disagree with what every other UCI front end
    /// shows for the same line.
    internal let nodesPerSecond: Int?

    // MARK: Initializers

    internal init(
        evaluation: Evaluation,
        depth: Int? = nil,
        nodes: Int? = nil,
        nodesPerSecond: Int? = nil
    ) {
        self.evaluation = evaluation
        self.depth = depth
        self.nodes = nodes
        self.nodesPerSecond = nodesPerSecond
    }
}
