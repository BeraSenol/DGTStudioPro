import Testing
@testable import DGTStudioPro

/// Pins the Analysis Data window's row fold (D73′).
///
/// Nonisolated — pure values in, pure values out, the D10′ posture. The claim
/// with teeth is the nil rule: this fold *diverges* from the bar's nil→drawn
/// display fold on purpose, and a divergence that is deliberate today is one
/// refactor away from being "unified" tomorrow unless something goes red.
@Suite("Analysis Data — Rows")
struct AnalysisDataRowTests {

    private let moves = ["e4", "e5", "Nf3", "Nc6"]

    // MARK: The Nil Rule

    /// **The deliberate divergence, pinned.** `EvaluationBarReading(nil)` folds
    /// to `.drawn` and prints "0.0", because a bar must render something at
    /// every ply. A data table printing "0.0" for a ply the engine never
    /// scored would manufacture exactly the false reading D67′ names — so an
    /// unscored ply is nil here, and the window draws the house em dash. If a
    /// future pass "unifies" the two folds, this is the test that says the
    /// difference was a decision.
    @Test("An unscored ply carries nil, never the bar's 0.0 fold")
    func unscoredPliesAreNilNotZero() {
        let rows = AnalysisDataRow.rows(
            moves: moves,
            evaluations: [.centipawns(30), nil, .centipawns(45), nil]
        )

        #expect(rows[1].evaluation == nil)
        #expect(rows[1].whiteWinPercent == nil)
        #expect(rows[3].evaluation == nil)
        // And the scored neighbours are untouched by the rule.
        #expect(rows[0].evaluation != nil)
        #expect(rows[2].evaluation != nil)
    }

    /// `PGN`'s other invariant shape — an empty array — yields a full-length
    /// table of unscored rows rather than no rows: the *moves* happened, and
    /// a window that showed nothing would read as a resolution failure.
    @Test("An empty evaluations array yields unscored rows for every move")
    func emptyEvaluationsYieldUnscoredRows() {
        let rows = AnalysisDataRow.rows(moves: moves, evaluations: [])

        #expect(rows.count == moves.count)
        #expect(rows.allSatisfy { $0.evaluation == nil })
    }

    // MARK: Shared Grammars

    /// The move column is `EvaluationGraphReading`'s spelling, asserted
    /// against that type's own output rather than a literal — the
    /// assert-against-the-shared-source rule, so the two surfaces cannot
    /// drift while both suites stay green.
    @Test("The move grammar is the graph reading's, verbatim")
    func moveGrammarMatchesTheGraphReading() {
        let evaluations: [Evaluation?] = [.centipawns(10), nil, nil, nil]
        let rows = AnalysisDataRow.rows(moves: moves, evaluations: evaluations)

        for ply in moves.indices {
            let reading = EvaluationGraphReading(
                ply: ply, moves: moves, evaluations: evaluations
            )
            #expect(rows[ply].move == reading?.move)
        }
        // The grammar's two shapes, stated once so a red here names the ply
        // kind rather than an index.
        #expect(rows[0].move == "1. e4")
        #expect(rows[1].move == "1… e5")
    }

    /// The evaluation column is the bar's pinned label grammar (D33′),
    /// asserted against `EvaluationBarReading` for scored plies.
    @Test("A scored ply's label is the bar grammar's")
    func scoredLabelsAreTheBarGrammars() {
        let rows = AnalysisDataRow.rows(
            moves: moves,
            evaluations: [.centipawns(130), .mate(-4), .centipawns(0), nil]
        )

        #expect(rows[0].evaluation == EvaluationBarReading(.centipawns(130)).label)
        #expect(rows[1].evaluation == EvaluationBarReading(.mate(-4)).label)
        #expect(rows[2].evaluation == EvaluationBarReading(.centipawns(0)).label)
    }

    // MARK: Win Probability

    /// Mates clamp to the ends and a dead-equal position is 50% — the
    /// projection is `whiteWinProbability`'s, so these are its known points
    /// rendered, not a new sigmoid.
    @Test("Win percent renders the projection's known points")
    func winPercentRendersKnownPoints() {
        let rows = AnalysisDataRow.rows(
            moves: moves,
            evaluations: [.mate(3), .mate(-3), .centipawns(0), nil]
        )

        #expect(rows[0].whiteWinPercent == "100%")
        #expect(rows[1].whiteWinPercent == "0%")
        #expect(rows[2].whiteWinPercent == "50%")
        #expect(rows[3].whiteWinPercent == nil)
    }

    // MARK: Identity

    /// Ids are the ply indices — unique by construction, which is the one
    /// thing a `Table`'s `ForEach` cannot tolerate being wrong.
    @Test("Row ids are the ply indices, distinct and ordered")
    func idsArePlyIndices() {
        let rows = AnalysisDataRow.rows(moves: moves, evaluations: [])

        #expect(rows.map(\.id) == Array(moves.indices))
    }
}
