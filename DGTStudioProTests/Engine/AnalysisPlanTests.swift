import Testing
@testable import DGTStudioPro

/// The pass's plan, pure — the `AnalysisQueue` extraction's shape one layer down: which
/// plies get searched is the decision worth pinning without an engine.
@Suite("Analysis Plan")
struct AnalysisPlanTests {

    private let drawn = Evaluation.drawn

    @Test("The book prefix is never searched")
    func bookPrefixSkips() {
        let plan = AnalysisPlan.plan(
            moveCount: 10, evaluations: [], depths: [], bookPlies: 6, targetDepth: 18
        )
        #expect(plan.searchable == [6, 7, 8, 9])
        // Empty evaluations don't fit ten moves — the fresh-game reset.
        #expect(plan.resetsStorage)
    }

    @Test("A ply at target depth is kept; shallow, unknown-depth and unscored plies re-search")
    func satisfiedPliesSkip() {
        let plan = AnalysisPlan.plan(
            moveCount: 4,
            evaluations: [drawn, drawn, drawn, nil],
            depths: [18, 12, nil, 18],
            bookPlies: 0,
            targetDepth: 18
        )
        // 0 is satisfied; 1 is shallow; 2 has no recorded depth; 3 has a depth but no score.
        #expect(plan.searchable == [1, 2, 3])
        #expect(!plan.resetsStorage)
    }

    @Test("Legacy games — evaluations with no depths — keep their scores and re-search everything")
    func legacyDepthsAreUnknownNotAReset() {
        let plan = AnalysisPlan.plan(
            moveCount: 2, evaluations: [drawn, drawn], depths: [], bookPlies: 0, targetDepth: 18
        )
        #expect(plan.searchable == [0, 1])
        // The scores survive until each ply is actually re-searched — unknown is not a reset.
        #expect(!plan.resetsStorage)
    }

    @Test("A length mismatch on evaluations is the one reset")
    func mismatchedEvaluationsReset() {
        let plan = AnalysisPlan.plan(
            moveCount: 3, evaluations: [drawn], depths: [], bookPlies: 0, targetDepth: 18
        )
        #expect(plan.resetsStorage)
        #expect(plan.searchable == [0, 1, 2])
    }

    @Test("A fully satisfied game plans nothing — no engine will spawn")
    func fullySatisfiedPlansEmpty() {
        let plan = AnalysisPlan.plan(
            moveCount: 2, evaluations: [drawn, drawn], depths: [18, 20], bookPlies: 0, targetDepth: 18
        )
        #expect(plan.searchable.isEmpty)
        #expect(!plan.resetsStorage)
    }

    @Test("A deeper target re-opens every satisfied ply — re-analysis means deepen")
    func deeperTargetReopens() {
        let plan = AnalysisPlan.plan(
            moveCount: 2, evaluations: [drawn, drawn], depths: [18, 18], bookPlies: 0, targetDepth: 22
        )
        #expect(plan.searchable == [0, 1])
    }

    @Test("Book plies clamp to the move count in both directions")
    func bookClamps() {
        let over = AnalysisPlan.plan(
            moveCount: 3, evaluations: [], depths: [], bookPlies: 40, targetDepth: 18
        )
        #expect(over.searchable.isEmpty)

        let negative = AnalysisPlan.plan(
            moveCount: 2, evaluations: [], depths: [], bookPlies: -1, targetDepth: 18
        )
        #expect(negative.searchable == [0, 1])
    }
}
