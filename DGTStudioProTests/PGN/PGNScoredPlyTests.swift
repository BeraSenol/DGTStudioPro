import Testing
@testable import DGTStudioPro

/// `PGN.hasScoredPly` — the app's one spelling of "is there analysis to show?",
/// extracted 7 August 2026 after the `!evaluations.isEmpty` spelling drew a
/// fabricated flat curve for two games whose analysis pass scored nothing.
///
/// **The middle case is the whole suite.** Empty-versus-scored is a
/// distinction both spellings get right, and a test that only covered those
/// two would have passed against the defect — the shape this project keeps
/// cataloguing as "a claim is only checked by a test that could have failed".
/// The array that broke it is full-length and all-nil, which is what
/// `GameAnalysisDriver` writes before it walks, and it is the only input the
/// two spellings disagree on.
///
/// Nonisolated, matching `PGNDisplayTests` one file over: `hasScoredPly` reads
/// a stored array and needs neither a container nor the main actor. Following
/// the sibling rather than reaching for `@MainActor` because `PGN` is a
/// `@Model` — a `@Model` is not main-actor-isolated, and annotating this would
/// invent a constraint to look safe.
@Suite("PGN — has a scored ply")
struct PGNScoredPlyTests {

    private static func game(evaluations: [Evaluation?]) -> PGN {
        PGN(
            moves: ["e4", "e5", "Nf3", "Nc6"],
            evaluations: evaluations
        )
    }

    /// Never analysed: the array the initializer leaves alone.
    @Test func anEmptyArrayHasNoScoredPly() {
        #expect(Self.game(evaluations: []).hasScoredPly == false)
    }

    /// **The regression.** `GameAnalysisDriver` resets `evaluations` to
    /// `Array(repeating: nil, count: moves.count)` *before* the walk, so a
    /// pass that dies or is stopped before scoring anything leaves exactly
    /// this. It is not empty; it contains no analysis. Under the old spelling
    /// the bar rendered at dead even and the graph drew a flat line on its own
    /// midline — a reading invented entirely by the `?? 0.5` fallback.
    @Test func aFullLengthAllNilArrayHasNoScoredPly() {
        let stalled = Self.game(evaluations: [Evaluation?](repeating: nil, count: 4))
        #expect(stalled.evaluations.isEmpty == false)   // the old gate said yes
        #expect(stalled.hasScoredPly == false)          // the question actually being asked
    }

    /// One scored ply is enough, which is deliberate and is why
    /// `AnalysisGlyph.State` needs three cases rather than a `Bool`: the
    /// driver writes as it walks, so this goes true at ply one. "Some plies
    /// are scored" and "the pass finished" are different questions and this
    /// answers only the first — Get Info's "n of m" row answers the second.
    @Test func oneScoredPlyIsEnough() {
        let partial = Self.game(evaluations: [nil, .drawn, nil, nil])
        #expect(partial.hasScoredPly)
    }

    /// A *drawn* evaluation is a real score, not an absence. Worth its own
    /// case because `Evaluation.drawn` is also what a nil per-ply reading
    /// folds to for display — the two are the same number and different
    /// facts, and a predicate that confused them would put this game back
    /// under the bug it was written for.
    @Test func aDrawnEvaluationIsAScore() {
        #expect(Self.game(evaluations: [.drawn, nil, nil, nil]).hasScoredPly)
    }

    @Test func aFullyScoredGameHasScoredPlies() {
        #expect(Self.game(evaluations: [.drawn, .drawn, .drawn, .drawn]).hasScoredPly)
    }

    /// The glyph forwards rather than restating, so the two can never drift.
    /// Asserted against `hasScoredPly` itself rather than against literals:
    /// a literal would keep passing while the two definitions diverged, which
    /// is precisely the failure this extraction exists to prevent.
    @Test func theGlyphForwardsToTheOneSpelling() {
        for evaluations: [Evaluation?] in [
            [],
            [Evaluation?](repeating: nil, count: 4),
            [nil, .drawn, nil, nil],
            [.drawn, .drawn, .drawn, .drawn],
        ] {
            let pgn = Self.game(evaluations: evaluations)
            #expect(AnalysisGlyph.isAnalyzed(pgn) == pgn.hasScoredPly)
        }
    }
}
