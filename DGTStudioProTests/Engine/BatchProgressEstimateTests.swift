import Testing
import Foundation
@testable import DGTStudioPro

/// Pins the batch projection and its two renderings.
///
/// Nonisolated, and that is load-bearing rather than stylistic: the estimator
/// takes three numbers and returns a fourth, with no clock of its own and no
/// actor. A suite that constructs it off the main actor is a compile-time
/// witness that the controller could not have smuggled `Date.now` into it — the
/// D44′ argument for isolation being checked at compile time or not at all.
@Suite("Batch Progress Estimate")
struct BatchProgressEstimateTests {

    // MARK: Projection

    /// The rate carried forward, at the simplest ratio there is: half the plies
    /// done in one minute means the other half takes another minute.
    ///
    /// The figures are chosen to be exactly representable (120 plies in 60
    /// seconds is 2/sec on the nose) so this can assert equality rather than a
    /// tolerance. `a / (a / b) == b` is not an identity in binary floating
    /// point, and a test that quietly needed a tolerance would be the wrong
    /// place to discover that.
    @Test("A rate observed is a rate projected")
    func projectsTheObservedRate() {
        let remaining = BatchProgressEstimate.secondsRemaining(
            pliesCompleted: 120,
            pliesRemaining: 120,
            elapsed: 60
        )
        #expect(remaining == 60)
    }

    /// The whole reason the unit is plies. A batch of two games where the
    /// second is four times the length of the first must project four times the
    /// elapsed — a games-based estimate would have said "one game left, one
    /// game's worth of time" and been wrong by 300%.
    ///
    /// This is the assertion that would fail if someone "simplified" the
    /// controller to count games, which is why it is spelled as a scenario
    /// rather than as another ratio.
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

    /// Nil for the three states with nothing to say, asserted separately
    /// because they are different questions wearing one answer: no rate yet, no
    /// work left, and a clock that has not moved. Each is reachable — the first
    /// on the opening ply of a batch, the second at the drain, the third on a
    /// library of one-ply games where start and first report share a
    /// millisecond.
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

    /// **Elapsed is spelled unlike the projection, deliberately**, and this is
    /// the pin on that decision rather than on the format: one is a measurement
    /// and the other is a guess, and a reader should be able to tell which is
    /// which without a label. If elapsed ever grows an "about", these two
    /// suites stop disagreeing and the distinction is gone.
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
