import Foundation

/// Remaining time projected from observed rate — a pure fold over three numbers. **The unit is
/// plies, not games**: games are wildly non-uniform, and a game-rate estimate is visibly wrong
/// on short batches. Rendered as "about", never as a countdown.
enum BatchProgressEstimate {

    /// Seconds remaining, or nil when there is nothing to project from — nil and zero are different
    /// statements; `elapsed <= 0` is guarded (a stopped clock projects nothing).
    static func secondsRemaining(
        pliesCompleted: Double,
        pliesRemaining: Int,
        elapsed: TimeInterval
    ) -> TimeInterval? {
        guard pliesCompleted > 0, pliesRemaining > 0, elapsed > 0 else { return nil }
        let pliesPerSecond = pliesCompleted / elapsed
        return Double(pliesRemaining) / pliesPerSecond
    }

    /// "about 4 min" — kept beside the arithmetic so the two cannot drift. Vague on purpose: a
    /// format implying second-accuracy this projection lacks is the more expensive lie.
    static func describe(secondsRemaining seconds: TimeInterval) -> String {
        if seconds < 60 {
            let steps = max(5, (Int(seconds.rounded()) / 5) * 5)
            return "about \(steps) sec"
        }
        let minutes = Int((seconds / 60).rounded())
        return "about \(minutes) min"
    }

    /// "1:04:22" — elapsed *is* known to the second and formatted like it; the deliberate contrast
    /// with the estimate. Hours appear only once there are any.
    static func describe(elapsed seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let (hours, minutes, secs) = (total / 3600, (total % 3600) / 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
