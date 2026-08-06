import Foundation

/// How long a running batch has left, projected from how fast it has gone so
/// far. A pure fold over three numbers, extracted from `AnalysisQueueController`
/// for the reason `AnalysisQueue` was: the interesting choice is testable
/// without an engine subprocess or a clock (D10′).
///
/// **The unit is plies, not games, and that is the whole design.** A batch of
/// eighteen holds a 25-ply miniature next to a 135-ply grind, so "mean seconds
/// per finished game × games left" is wrong by a factor of five on real input —
/// and wrong in the direction that matters, since the long games tend to sit at
/// the end of an import. Every ply is one engine search to the configured
/// depth, so plies are the unit the work is actually denominated in. The
/// controller records each game's ply count at enqueue, where it has the models
/// in hand.
///
/// **It is still a guess, and the surface that shows it says so.** Ply cost is
/// not uniform: an endgame with six pieces resolves in milliseconds while a
/// sharp middlegame at depth 20 can take seconds, and the log this was built
/// from has both inside one game (1 ms for a forced mate, 3.5 s for a tangle).
/// The projection is a *rate carried forward*, which is right on average across
/// a long batch and visibly wrong across a short one. Rendered as "about", never
/// as a countdown.
internal enum BatchProgressEstimate {

    /// Seconds still to run, or nil when there is nothing to project from.
    ///
    /// Nil rather than zero for the empty cases, and they are different
    /// questions: `pliesCompleted == 0` means no rate has been observed yet
    /// (the first game is still on its first ply), while `pliesRemaining == 0`
    /// means the batch is done. Both render as an absence rather than as
    /// "0 seconds", which would read as a promise about to be broken.
    ///
    /// `elapsed <= 0` is guarded because a clock that has not advanced would
    /// divide by zero, and a batch that starts and reports in the same
    /// millisecond is reachable on a library of one-ply games.
    internal static func secondsRemaining(
        pliesCompleted: Double,
        pliesRemaining: Int,
        elapsed: TimeInterval
    ) -> TimeInterval? {
        guard pliesCompleted > 0, pliesRemaining > 0, elapsed > 0 else { return nil }
        let pliesPerSecond = pliesCompleted / elapsed
        return Double(pliesRemaining) / pliesPerSecond
    }

    /// "about 4 min", "about 25 sec" — the rendering, kept beside the
    /// arithmetic so the two cannot drift.
    ///
    /// Coarse on purpose. `Duration`'s own formatting gives "4:03", which reads
    /// as a countdown accurate to the second; this projection is not, and a
    /// format that implies precision it does not have is the more expensive
    /// kind of wrong. Rounds to minutes above a minute and to five-second steps
    /// below it, so the number stops twitching between renders.
    internal static func describe(secondsRemaining seconds: TimeInterval) -> String {
        if seconds < 60 {
            let steps = max(5, (Int(seconds.rounded()) / 5) * 5)
            return "about \(steps) sec"
        }
        let minutes = Int((seconds / 60).rounded())
        return "about \(minutes) min"
    }

    /// "1:04:22", "3:41" — elapsed wall clock, which *is* known to the second
    /// and is formatted like it.
    ///
    /// The deliberate contrast with `describe(secondsRemaining:)` above: one of
    /// these is a measurement and the other is a projection, and they are
    /// spelled differently so a reader can tell which is which without a label
    /// saying so. Hours appear only once there are any.
    internal static func describe(elapsed seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let (hours, minutes, secs) = (total / 3600, (total % 3600) / 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
