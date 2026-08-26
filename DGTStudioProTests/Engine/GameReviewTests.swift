import Testing
@testable import DGTStudioPro

/// Pins D86′: the classification vocabulary's thresholds, the mover-loss parity and its gap
/// rule (D77′'s, ply 0 included), the accuracy formula's arithmetic and its honest nils, and
/// the biggest-swing destination. Nonisolated - pure folds over `[Evaluation?]`, load-bearing.
///
/// Fixtures use the two exact probabilities the type offers - `centipawns(0)` is 50% and a
/// mate is 100%/0% - so every expected value below is arithmetic, not a sigmoid transcript.
@Suite("Game Review")
struct GameReviewTests {

    private static let even = Evaluation.centipawns(0)     // 50%
    private static let whiteWinning = Evaluation.mate(1)   // 100%
    private static let blackWinning = Evaluation.mate(-1)  // 0%

    // MARK: Thresholds

    /// The tier boundaries, one distinct expectation per edge - the thresholds are data, and
    /// this is the table read back: below 10 is quiet, the tiers begin at 10 / 20 / 30.
    @Test func classificationTiersBeginAtTheirThresholds() {
        #expect(GameReview.classification(loss: 9.99) == nil)
        #expect(GameReview.classification(loss: 10) == .inaccuracy)
        #expect(GameReview.classification(loss: 19.99) == .inaccuracy)
        #expect(GameReview.classification(loss: 20) == .mistake)
        #expect(GameReview.classification(loss: 29.99) == .mistake)
        #expect(GameReview.classification(loss: 30) == .blunder)
        #expect(GameReview.classification(loss: 100) == .blunder)
    }

    // MARK: Mover Losses

    /// Parity: an even ply's loss is White's fall, an odd ply's is Black's - one fixture per
    /// side, both landing on exactly 50 pp.
    @Test func lossesFollowTheMoversParity() {
        // Ply 2 is White's: 50% → 0% is White losing 50 pp.
        let whiteBlunder = GameReview.moverLosses(
            evaluations: [Self.even, Self.even, Self.blackWinning]
        )
        #expect(whiteBlunder[2] == 50)
        #expect(whiteBlunder[1] == 0)

        // Ply 1 is Black's: 50% → 100% white is Black losing 50 pp.
        let blackBlunder = GameReview.moverLosses(
            evaluations: [Self.even, Self.whiteWinning]
        )
        #expect(blackBlunder[1] == 50)
    }

    /// A move that improves the mover's lot is a loss of zero, never negative.
    @Test func anImprovementFloorsAtZero() {
        // Ply 1 is Black's, and 50% → 0% white is Black *gaining*.
        let losses = GameReview.moverLosses(evaluations: [Self.even, Self.blackWinning])
        #expect(losses[1] == 0)
    }

    /// The gap rule, D77′'s exactly: ply 0 never classifies (no previous row), and a nil on
    /// either side of a step yields nil, never a fake delta across the book.
    @Test func theGapRuleIsTheSwingColumns() {
        let losses = GameReview.moverLosses(
            evaluations: [Self.even, nil, Self.even, Self.whiteWinning]
        )
        #expect(losses[0] == nil)   // ply 0, even though scored
        #expect(losses[1] == nil)   // after unscored
        #expect(losses[2] == nil)   // before unscored
        #expect(losses[3] == 50)    // both scored: Black's 50 pp loss
    }

    /// The per-ply vocabulary end to end: quiet, quiet, blunder.
    @Test func classificationsBadgeOnlyTheLapses() {
        let badges = GameReview.classifications(
            evaluations: [Self.even, Self.even, Self.blackWinning]
        )
        #expect(badges == [nil, nil, .blunder])
    }

    // MARK: Accuracy

    /// Two sides, two different numbers from one game: White's clean 100 against Black's one
    /// 50 pp lapse over two steps - mean 25, accuracy 50. The formula read back as arithmetic.
    @Test func accuracyIsTheStatedMonotoneMap() {
        let evaluations: [Evaluation?] = [
            Self.even, Self.even, Self.even, Self.whiteWinning, Self.whiteWinning
        ]
        #expect(GameReview.accuracy(for: .white, evaluations: evaluations) == 100)
        #expect(GameReview.accuracy(for: .black, evaluations: evaluations) == 50)
    }

    /// The floor: hanging the game on your only classifiable step is 0, clamped - not negative.
    @Test func accuracyClampsAtTheFloor() {
        let evaluations: [Evaluation?] = [Self.even, Self.even, Self.blackWinning]
        #expect(GameReview.accuracy(for: .white, evaluations: evaluations) == 0)
    }

    /// Honest nils, asymmetric on purpose: two scored plies give Black one classifiable step
    /// and White none (White's plies are 0 and 2 - one gap-ruled, one absent), so Black reads
    /// a number and White reads nothing. An unanalyzed game has no accuracy, not a perfect one.
    @Test func aSideWithNoClassifiableStepHasNoAccuracy() {
        let evaluations: [Evaluation?] = [Self.even, Self.even]
        #expect(GameReview.accuracy(for: .black, evaluations: evaluations) == 100)
        #expect(GameReview.accuracy(for: .white, evaluations: evaluations) == nil)
        #expect(GameReview.accuracy(for: .white, evaluations: []) == nil)
    }

    // MARK: Biggest Swing

    /// The destination is the largest absolute white-relative step; a tie keeps the first
    /// (strict comparison), and a game with no scored pair has no destination.
    @Test func biggestSwingFindsTheTurningPoint() {
        #expect(
            GameReview.biggestSwingPly(
                evaluations: [Self.even, Self.whiteWinning, Self.even, Self.even]
            ) == 1
        )
        #expect(GameReview.biggestSwingPly(evaluations: [Self.even]) == nil)
        #expect(GameReview.biggestSwingPly(evaluations: [Self.even, nil, Self.even]) == nil)
        #expect(GameReview.biggestSwingPly(evaluations: []) == nil)
    }
}
