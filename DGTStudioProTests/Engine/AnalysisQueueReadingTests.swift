import Testing
import Foundation
@testable import DGTStudioPro

/// Pins the queue window's prose (M18 Phase 2 - extracted as `AnalysisQueueReading`).
/// Nonisolated, and that is load-bearing: the reading is pure over value types, which is the
/// arrangement that makes a window's grammar pinnable at all. `Int` stands in for
/// `PersistentIdentifier` - the reading is generic over the id exactly so a suite needs no store.
@Suite("Analysis Queue Reading")
struct AnalysisQueueReadingTests {

    // MARK: Header

    /// Drive one three-game batch through its states and read the title at each - the
    /// numerator is `batchPosition`, the one spelling shared with the Library toolbar.
    @Test func headerTitleFollowsTheBatch() {
        var queue = AnalysisQueue<Int>()
        _ = queue.enqueue([1, 2, 3])
        _ = queue.startNext()
        #expect(AnalysisQueueReading.headerTitle(for: queue) == "Analyzing 1 of 3")

        queue.finishCurrent(.done)
        _ = queue.startNext()
        #expect(AnalysisQueueReading.headerTitle(for: queue) == "Analyzing 2 of 3")

        queue.finishCurrent(.done)
        _ = queue.startNext()
        queue.finishCurrent(.done)
        #expect(AnalysisQueueReading.headerTitle(for: queue) == "Analysis finished")
    }

    /// A drained batch with one failure reads "with errors" - the toolbar's warning state.
    @Test func headerTitleNamesADrainedBatchsFailures() {
        var queue = AnalysisQueue<Int>()
        _ = queue.enqueue([1])
        _ = queue.startNext()
        queue.finishCurrent(.failed(message: "engine died"))
        #expect(AnalysisQueueReading.headerTitle(for: queue) == "Analysis finished with errors")
    }

    // MARK: Timing Line

    private static let started = Date(timeIntervalSinceReferenceDate: 0)
    private static let now = started.addingTimeInterval(65)

    @Test func timingLineWithAnEstimateShowsBothClocks() {
        let line = AnalysisQueueReading.timingLine(
            now: Self.now, started: Self.started, isActive: true, secondsRemaining: 120
        )
        #expect(line == "1:05 elapsed · about 2 min left")
    }

    /// No estimate yet (a cold batch has no observed rate): elapsed alone.
    @Test func timingLineWithoutAnEstimateShowsElapsedAlone() {
        let line = AnalysisQueueReading.timingLine(
            now: Self.now, started: Self.started, isActive: true, secondsRemaining: nil
        )
        #expect(line == "1:05 elapsed")
    }

    /// A drained queue drops the projection even if a stale estimate is still in hand -
    /// "about 0 sec left" is not a statement this window makes.
    @Test func timingLineAfterTheDrainIgnoresAStaleEstimate() {
        let line = AnalysisQueueReading.timingLine(
            now: Self.now, started: Self.started, isActive: false, secondsRemaining: 3
        )
        #expect(line == "1:05 elapsed")
    }

    // MARK: Speed

    /// All four tiers, one value each - and the boundary pair around the integer-division
    /// branch, whose whole reason to exist is that a cold search must never read "0 kn/s".
    @Test func speedLabelDegradesThroughItsTiers() {
        #expect(AnalysisQueueReading.speedLabel(nil) == "-")
        #expect(AnalysisQueueReading.speedLabel(500) == "500 n/s")
        #expect(AnalysisQueueReading.speedLabel(999) == "999 n/s")
        #expect(AnalysisQueueReading.speedLabel(1_000) == "1 kn/s")
        #expect(AnalysisQueueReading.speedLabel(999_999) == "999 kn/s")
        #expect(AnalysisQueueReading.speedLabel(8_940_000) == "8.9 Mn/s")
    }

    // MARK: Ply Label

    /// Empty for an unknown count - deliberately not the dash: a missing count means nothing
    /// to say about the row, a missing speed means a named fact is unavailable.
    @Test func plyLabelWritesTheCountOrNothing() {
        #expect(AnalysisQueueReading.plyLabel(plies: 58) == "58 plies to search")
        #expect(AnalysisQueueReading.plyLabel(plies: nil) == "")
    }

    // MARK: Outcomes

    /// Three outcomes, three distinct symbols (the N-way-mapping rule: N distinct expectations).
    @Test func outcomeSymbolsAreDistinctPerCase() {
        #expect(AnalysisQueueReading.outcomeSymbol(AnalysisQueue<Int>.Outcome.done) == "checkmark.circle.fill")
        #expect(AnalysisQueueReading.outcomeSymbol(AnalysisQueue<Int>.Outcome.cancelled) == "minus.circle.fill")
        #expect(
            AnalysisQueueReading.outcomeSymbol(AnalysisQueue<Int>.Outcome.failed(message: "x"))
                == "exclamationmark.triangle.fill"
        )
    }

    /// Done says nothing, cancelled keeps its promise about kept evaluations, failed passes
    /// the driver's message through untouched.
    @Test func outcomeDetailSpeaksOnlyWhenThereIsSomethingToSay() {
        #expect(AnalysisQueueReading.outcomeDetail(AnalysisQueue<Int>.Outcome.done) == nil)
        #expect(
            AnalysisQueueReading.outcomeDetail(AnalysisQueue<Int>.Outcome.cancelled)
                == "Stopped. Evaluations recorded before the stop were kept."
        )
        #expect(
            AnalysisQueueReading.outcomeDetail(AnalysisQueue<Int>.Outcome.failed(message: "engine died"))
                == "engine died"
        )
    }
}
