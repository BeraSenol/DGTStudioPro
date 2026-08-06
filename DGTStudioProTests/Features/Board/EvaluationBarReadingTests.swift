import Testing
@testable import DGTStudioPro

/// The M3 bar mapping (D33′): fraction identical to the graph's projection,
/// nil folding to `.drawn`, and the label grammar — signed pawns to one
/// decimal, unsigned zero, `evalTagContent`-spelled mates. Pure value type,
/// nonisolated.
@Suite("Evaluation Bar Reading")
struct EvaluationBarReadingTests {

    // MARK: The Graph Agreement (the gate, as identity)

    /// The bar's fraction is `whiteWinProbability` verbatim — not a second
    /// sigmoid that could drift. Pinned across the shapes the graph plots:
    /// even, advantage both ways, mate both ways.
    @Test(arguments: [
        Evaluation.centipawns(0),
        .centipawns(23), .centipawns(-150), .centipawns(400),
        .mate(3), .mate(-2), .mate(0),
    ])
    func fractionIsTheGraphsProjection(evaluation: Evaluation) {
        #expect(EvaluationBarReading(evaluation).whiteFraction == evaluation.whiteWinProbability)
    }

    // MARK: Nil — the `.drawn` Fold

    /// Ply 0 and unanalysed plies read neutral, exactly like the graph's
    /// `?? 0.5` — and this is `Evaluation.drawn`'s named consumer finally
    /// consuming it.
    @Test func nilFoldsToDrawn() {
        #expect(EvaluationBarReading(nil) == EvaluationBarReading(.drawn))
        #expect(EvaluationBarReading(nil).whiteFraction == 0.5)
        #expect(EvaluationBarReading(nil).label == "0.0")
    }

    // MARK: Label Grammar

    @Test func centipawnLabelsAreSignedPawnsToOneDecimal() {
        #expect(EvaluationBarReading(.centipawns(150)).label == "+1.5")
        #expect(EvaluationBarReading(.centipawns(-30)).label == "-0.3")
        #expect(EvaluationBarReading(.centipawns(23)).label == "+0.2")
        #expect(EvaluationBarReading(.centipawns(999)).label == "+10.0")
    }

    /// Anything that *rounds* to zero shows the unsigned "0.0" — a signed
    /// zero would claim a direction the number no longer shows.
    @Test func nearZeroRoundsToUnsignedZero() {
        #expect(EvaluationBarReading(.centipawns(0)).label == "0.0")
        #expect(EvaluationBarReading(.centipawns(4)).label == "0.0")
        #expect(EvaluationBarReading(.centipawns(-4)).label == "0.0")
    }

    @Test func mateLabelsUseTheEvalTagSpelling() {
        #expect(EvaluationBarReading(.mate(3)).label == "#3")
        #expect(EvaluationBarReading(.mate(-2)).label == "#-2")
        #expect(EvaluationBarReading(.mate(0)).label == "#0")
    }

    /// Mates clamp like the graph: full bar / empty bar, never a sliver.
    @Test func matesClampTheFraction() {
        #expect(EvaluationBarReading(.mate(1)).whiteFraction == 1.0)
        #expect(EvaluationBarReading(.mate(-1)).whiteFraction == 0.0)
        #expect(EvaluationBarReading(.mate(0)).whiteFraction == 0.5)
    }
}
