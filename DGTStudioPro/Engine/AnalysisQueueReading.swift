import Foundation

/// The queue window's prose, extracted pure (M18 Phase 2 - the `EvaluationGraphReading`
/// precedent): every string the window renders about the batch, computed from values with no
/// view in reach, so the grammar is pinnable. The view keeps only what is genuinely its own -
/// `outcomeTint` (a `Color` is presentation), `searchFact` and `section` (layout), and the
/// move label, which stays `GameAnalysisDriver.moveLabel` because the driver is `@MainActor`
/// and already the one spelling shared with its failure rows.
enum AnalysisQueueReading {

    /// Title over the whole batch. `batchPosition` is the one spelling of the numerator,
    /// shared with the Library toolbar's "3/18".
    static func headerTitle<ID: Hashable & Sendable>(for queue: AnalysisQueue<ID>) -> String {
        guard queue.isActive else {
            return queue.hasFailures ? "Analysis finished with errors" : "Analysis finished"
        }
        return "Analyzing \(queue.batchPosition) of \(queue.totalCount)"
    }

    /// Only the knowable half: the projection drops off once the queue drains - "about 0 sec"
    /// is not the same statement as no estimate.
    static func timingLine(
        now: Date,
        started: Date,
        isActive: Bool,
        secondsRemaining: TimeInterval?
    ) -> String {
        let elapsed = BatchProgressEstimate.describe(elapsed: now.timeIntervalSince(started))
        guard isActive, let secondsRemaining else { return "\(elapsed) elapsed" }
        return "\(elapsed) elapsed · \(BatchProgressEstimate.describe(secondsRemaining: secondsRemaining)) left"
    }

    /// "8.9 Mn/s" - the unit every engine front end shows; degrades through thousands to bare
    /// nodes. The third tier exists because the kn/s branch is integer division: without it,
    /// the first `info` line of a cold search reads "0 kn/s", which is what a stalled engine
    /// would show.
    static func speedLabel(_ nodesPerSecond: Int?) -> String {
        guard let nodesPerSecond else { return RosterSummary.displayUnknown }
        if nodesPerSecond >= 1_000_000 {
            return String(format: "%.1f Mn/s", Double(nodesPerSecond) / 1_000_000)
        }
        if nodesPerSecond >= 1_000 {
            return "\(nodesPerSecond / 1_000) kn/s"
        }
        return "\(nodesPerSecond) n/s"
    }

    /// "58 plies to search" - searchable, not total: the number the estimate is denominated
    /// in, so a jumped "about 9 min" is explicable.
    ///
    /// Empty string for an unknown count, not the dash `speedLabel` uses: a missing count
    /// means there is nothing to say about this row, where a missing speed means a named fact
    /// is unavailable. Two spellings of "unknown", on purpose.
    static func plyLabel(plies: Int?) -> String {
        guard let plies else { return "" }
        return "\(plies) plies to search"
    }

    static func outcomeSymbol<ID: Hashable & Sendable>(_ outcome: AnalysisQueue<ID>.Outcome) -> String {
        switch outcome {
        case .done:      "checkmark.circle.fill"
        case .cancelled: "minus.circle.fill"
        case .failed:    "exclamationmark.triangle.fill"
        }
    }

    static func outcomeDetail<ID: Hashable & Sendable>(_ outcome: AnalysisQueue<ID>.Outcome) -> String? {
        switch outcome {
        case .done:                nil
        case .cancelled:           "Stopped. Evaluations recorded before the stop were kept."
        case .failed(let message): message
        }
    }
}
