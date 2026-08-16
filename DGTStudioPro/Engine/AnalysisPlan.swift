/// Which plies an analysis pass will actually search: the classified book prefix is
/// skipped - the table already names those positions - and a ply scored at ≥ the target depth is
/// kept rather than re-searched. Pure, so the decision is suite-testable without an engine -
/// the `AnalysisQueue` extraction's reason, one layer down.
enum AnalysisPlan {

    struct Plan: Equatable, Sendable {
        /// Ply indices to search, ascending.
        let searchable: [Int]
        /// True when `evaluations` does not fit `moveCount` and both arrays rebuild all-nil.
        let resetsStorage: Bool
    }

    /// Depths that don't fit are *unknown*, not a reset: legacy games carry evaluations with no
    /// depths, and their scores must survive until each ply is actually re-searched.
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
