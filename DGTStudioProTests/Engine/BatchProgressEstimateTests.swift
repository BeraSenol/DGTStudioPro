import Testing
import Foundation
@testable import DGTStudioPro

/// The batch projection and its two renderings. Nonisolated, load-bearing — the compile is the
/// witness no `Date.now` was smuggled in.
@Suite("Batch Progress Estimate")
struct BatchProgressEstimateTests {

    // MARK: Projection

    /// Rate carried forward at the simplest ratio. Tolerance because `a / (a / b) == b` is not an
    /// identity in binary floating point.
    @Test("A rate observed is a rate projected")
    func projectsTheObservedRate() {
        let remaining = BatchProgressEstimate.secondsRemaining(
            pliesCompleted: 120,
            pliesRemaining: 120,
            elapsed: 60
        )
        #expect(remaining == 60)
    }

    /// The whole reason the unit is plies: a second game four times the length must project four
    /// times the elapsed.
    @Test("Long games left project longer than short games done")
    func pliesNotGames() {
        let shortGameDone = 25.0
        let longGameWaiting = 100
        let elapsed: TimeInterval = 50 // 2 sec per ply

        let remaining = BatchProgressEstimate.secondsRemaining(
            pliesCompleted: shortGameDone,
            pliesRemaining: longGameWaiting,
            elapsed: elapsed
        )
        #expect(remaining == 200)
    }

    /// Nil for the three empty states, asserted separately — different questions wearing one answer.
    @Test("No projection without a rate, work, and a clock")
    func nilCases() {
        #expect(
            BatchProgressEstimate.secondsRemaining(
                pliesCompleted: 0, pliesRemaining: 100, elapsed: 10
            ) == nil
        )
        #expect(
            BatchProgressEstimate.secondsRemaining(
                pliesCompleted: 100, pliesRemaining: 0, elapsed: 10
            ) == nil
        )
        #expect(
            BatchProgressEstimate.secondsRemaining(
                pliesCompleted: 100, pliesRemaining: 100, elapsed: 0
            ) == nil
        )
    }

    // MARK: Renderings

    /// Coarse below a minute, in five-second steps, with a floor of five — so
    /// the figure stops twitching between renders and never reads "about 0 sec",
    /// which is a promise about to be broken.
    @Test(
        "Sub-minute projections round to five-second steps",
        arguments: [
            (1.0, "about 5 sec"),
            (7.0, "about 5 sec"),
            (12.0, "about 10 sec"),
            (59.0, "about 55 sec"),
        ]
    )
    func describesSecondsCoarsely(seconds: TimeInterval, expected: String) {
        #expect(BatchProgressEstimate.describe(secondsRemaining: seconds) == expected)
    }

    @Test(
        "Minute projections round to whole minutes",
        arguments: [
            (60.0, "about 1 min"),
            (100.0, "about 2 min"),
            (540.0, "about 9 min"),
        ]
    )
    func describesMinutes(seconds: TimeInterval, expected: String) {
        #expect(BatchProgressEstimate.describe(secondsRemaining: seconds) == expected)
    }

    /// Elapsed is spelled unlike the projection, deliberately: one is a measurement, one a guess,
    /// and a reader should be able to tell which.
    @Test(
        "Elapsed is clock time, to the second, hours only when there are any",
        arguments: [
            (0.0, "0:00"),
            (9.0, "0:09"),
            (221.0, "3:41"),
            (3862.0, "1:04:22"),
        ]
    )
    func describesElapsed(seconds: TimeInterval, expected: String) {
        #expect(BatchProgressEstimate.describe(elapsed: seconds) == expected)
    }

    /// A negative interval is reachable if the system clock moves backwards
    /// under a running batch — NTP correction, or the user changing the date.
    /// Clamped rather than printing "-1:-3", which is the kind of thing that
    /// gets screenshotted.
    @Test("A clock that ran backwards reads zero rather than negative")
    func elapsedClampsAtZero() {
        #expect(BatchProgressEstimate.describe(elapsed: -42) == "0:00")
    }
}
