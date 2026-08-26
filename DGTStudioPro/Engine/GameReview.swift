import Foundation

/// The review layer's arithmetic (D86′): move classifications and per-game accuracy, both
/// derived from the win-probability curve the app already stores - the D77′ swing column's own
/// currency. Pure over `[Evaluation?]`; derives and stores nothing.
///
/// **The gap rule is D77′'s, inherited whole**: a step classifies only when *both* of its ends
/// are scored, so the opening book and any skipped tail produce no classifications and no
/// accuracy contribution - never a fake verdict across a gap.
enum GameReview {

    // MARK: Vocabulary

    /// Chosen once (M19's schedule): the three tiers every chess reader already knows.
    /// **No "best move" tier** - the stored data cannot honestly say it without multipv, and a
    /// tier the data cannot produce is a lie with a green build. A quiet move is `nil`, not a
    /// case: the vocabulary names lapses, and "not a lapse" is the absence of a badge.
    enum MoveClassification: String, CaseIterable, Sendable {
        case inaccuracy
        case mistake
        case blunder
    }

    /// Thresholds as data, in percentage points of the mover's win-probability loss, checked
    /// worst-first. The values are the vocabulary's conventional ones (10 / 20 / 30 pp - the
    /// tiers lichess documents for its own reports); the *classification reads the raw loss*,
    /// where the D77′ column rounds for display - display-vs-branch stays split, the
    /// `BatchProgressEstimate` lesson.
    static let thresholds: [(classification: MoveClassification, minimumLoss: Double)] = [
        (.blunder, 30),
        (.mistake, 20),
        (.inaccuracy, 10),
    ]

    /// The tier for one mover-loss, or nil below every threshold.
    static func classification(loss: Double) -> MoveClassification? {
        thresholds.first(where: { loss >= $0.minimumLoss })?.classification
    }

    // MARK: Per-Ply Losses

    /// The mover's win-probability loss at each ply, in percentage points - `nil` where the
    /// gap rule says no verdict. The rule is the D77′ column's *exactly*, ply 0 included:
    /// the column prints no swing at the first row (no previous row to step from), so no
    /// badge appears there either - the two surfaces read one step, and ply 0 is book in
    /// practice anyway. Inventing a 50% "before" for it was considered and dropped: a seed
    /// the engine never scored is a fake delta in gap-rule clothes.
    ///
    /// Even plies are White's, odd are Black's; a mover's loss is their own win probability
    /// falling, so White's is `before - after` and Black's is `after - before`, floored at
    /// zero - a move that *improves* the mover's lot is a loss of zero, not a negative lapse.
    static func moverLosses(evaluations: [Evaluation?]) -> [Double?] {
        evaluations.indices.map { ply in
            guard
                ply > 0,
                let after = evaluations[ply]?.whiteWinProbability,
                let before = evaluations[ply - 1]?.whiteWinProbability
            else { return nil }
            let whiteDelta = (after - before) * 100
            let moverLoss = ply.isMultiple(of: 2) ? -whiteDelta : whiteDelta
            return max(0, moverLoss)
        }
    }

    /// One classification per ply (`nil` = quiet or unclassifiable) - what the move list badges.
    static func classifications(evaluations: [Evaluation?]) -> [MoveClassification?] {
        moverLosses(evaluations: evaluations).map { $0.flatMap(classification(loss:)) }
    }

    // MARK: Accuracy

    /// Per-game accuracy for one side: **`100 - 2 × (mean win% loss in pp)`, clamped to
    /// 0…100** - a monotone map from mean loss, stated as ours. Nil when the side has no
    /// classifiable step (an unanalyzed or all-book game has no accuracy, not a perfect one).
    ///
    /// Rejected: **chess.com's CAPS** (proprietary - a number we cannot recompute is a number
    /// we cannot pin); **lichess's exponential fit** (borrowing its constants without its
    /// harmonic-mean machinery reproduces neither its numbers nor ours honestly); **counting
    /// unscored plies as zero loss** (inflates accuracy exactly where the engine never
    /// looked). The factor 2 puts 0 at a 50 pp mean loss - hanging the game every move -
    /// which is the scale's honest floor.
    static func accuracy(for color: PieceColor, evaluations: [Evaluation?]) -> Double? {
        let losses = moverLosses(evaluations: evaluations)
        let own = stride(
            from: color == .white ? 0 : 1,
            to: losses.count,
            by: 2
        ).compactMap { losses[$0] }
        guard !own.isEmpty else { return nil }
        let mean = own.reduce(0, +) / Double(own.count)
        return min(100, max(0, 100 - 2 * mean))
    }

    // MARK: Navigation

    /// The ply of the biggest absolute white-relative swing between two *scored* neighbours -
    /// "jump to the biggest swing"'s destination. Nil when no adjacent pair is scored. Uses
    /// the same white-relative delta the D77′ column prints, not the mover loss: the reader
    /// is looking for the game's turning point, whoever it favoured.
    static func biggestSwingPly(evaluations: [Evaluation?]) -> Int? {
        var best: (ply: Int, magnitude: Double)?
        for ply in evaluations.indices.dropFirst() {
            guard
                let before = evaluations[ply - 1]?.whiteWinProbability,
                let after = evaluations[ply]?.whiteWinProbability
            else { continue }
            let magnitude = abs(after - before)
            if magnitude > (best?.magnitude ?? -1) {
                best = (ply, magnitude)
            }
        }
        return best?.ply
    }
}
