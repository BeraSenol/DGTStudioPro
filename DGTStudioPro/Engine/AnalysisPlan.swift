/// Which plies an analysis pass will actually search: the classified book prefix is skipped - the
/// table already names those positions - and a ply scored at ≥ the target depth is kept rather than
/// re-searched (D74′). Pure, so the decision is suite-testable without an engine.
///
/// **Two callers, which is the point.** `GameAnalysisDriver` walks the plan; `AnalysisQueueController`
/// counts it for the progress denominator. The queue window's "N plies to search" cannot disagree
/// with what the pass does, because it is the same function answering both.
enum AnalysisPlan {

    struct Plan: Equatable, Sendable {
        /// Ply indices to search, ascending.
        let searchable: [Int]

        /// True when **`evaluations`** does not fit `moveCount` - and it governs that array alone.
        /// `depths` fits or not independently, so `GameAnalysisDriver` re-asks about it separately
        /// and rebuilds it there. That second check is load-bearing, not belt and braces: the
        /// per-ply write is `analysisDepths[index] = depth`, and a legacy game - evaluations
        /// fitting, depths empty - arrives here with `resetsStorage == false`.
        let resetsStorage: Bool
    }

    /// Depths that don't fit are *unknown*, not a reset: legacy games carry evaluations with no
    /// depths, and their scores must survive until each ply is actually re-searched.
    ///
    /// The book prefix is skipped whether or not those plies hold a score, so a fresh game's
    /// opening stays unscored - em dashes in the Analysis Data window, never `0.0`.
    static func plan(
        moveCount: Int,
        evaluations: [Evaluation?],
        depths: [Int?],
        bookPlies: Int,
        targetDepth: Int
    ) -> Plan {
        let evalsFit = evaluations.count == moveCount
        let knownDepths: [Int?] = depths.count == moveCount
            ? depths
            : Array(repeating: nil, count: moveCount)
        // Clamped both ways - and the `min` is also what keeps the range below well-formed.
        let start = min(max(bookPlies, 0), moveCount)
        var searchable: [Int] = []
        for index in start..<moveCount {
            let satisfied = evalsFit
                && evaluations[index] != nil
                && knownDepths[index].map { $0 >= targetDepth } == true
            if !satisfied { searchable.append(index) }
        }
        return Plan(searchable: searchable, resetsStorage: !evalsFit)
    }
}
