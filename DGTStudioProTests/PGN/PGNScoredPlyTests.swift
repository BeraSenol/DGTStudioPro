import Testing
@testable import DGTStudioPro

/// `PGN.hasScoredPly` - the one spelling of "is there analysis to show?", extracted after
/// `!evaluations.isEmpty` drew a fabricated flat curve over an all-nil array.
@Suite("PGN - Has a Scored Ply")
struct PGNScoredPlyTests {

    private static func game(evaluations: [Evaluation?]) -> PGN {
        PGN(
            moves: ["e4", "e5", "Nf3", "Nc6"],
            evaluations: evaluations
        )
    }

    /// Never analyzed: the array the initializer leaves alone.
    @Test func anEmptyArrayHasNoScoredPly() {
        #expect(Self.game(evaluations: []).hasScoredPly == false)
    }

    /// **The regression**: the driver resets to all-nil *before* the walk, so a pass stopped before
    /// scoring leaves exactly this - not empty, containing no analysis.
    @Test func aFullLengthAllNilArrayHasNoScoredPly() {
        let stalled = Self.game(evaluations: [Evaluation?](repeating: nil, count: 4))
        #expect(stalled.evaluations.isEmpty == false)   // the old gate said yes
        #expect(stalled.hasScoredPly == false)          // the question actually being asked
    }

    /// One scored ply is enough (the driver writes as it walks) - "some plies" vs "all plies" are
    /// different questions; this answers the first.
    @Test func oneScoredPlyIsEnough() {
        let partial = Self.game(evaluations: [nil, .drawn, nil, nil])
        #expect(partial.hasScoredPly)
    }

    /// A *drawn* evaluation is a real score, not an absence - same number as the display fold,
    /// different meaning.
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
