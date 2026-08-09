import Foundation
import os

/// The one place that decides whether the app logs and what a line looks like (D63′) — the
/// subsystem was spelled 25 times, the policy nowhere. Returns `Logger?`: optional chaining
/// short-circuits, so a suppressed message is never interpolated. Not a wrapping struct —
/// `OSLogMessage` cannot be forwarded, so a wrapper would flatten every message to `String` and
/// make `privacy:` decoration.
/// Grammar: participles before the work, past tense after; a participle whose failure path is
/// silent is the defect.
internal enum AppLog {

    // MARK: Subsystem and categories

    /// Spelled once. It was spelled twenty-five times.
    private static let subsystem = "com.berasenol.dgtstudiopro"

    /// Categories are a **contract with the console**: manual checks name `uci`, `eco`, `players`
    /// in `log stream` predicates, so raw values are pinned on literals. Typed, deliberately unlike
    /// `AccessibilityID` — nothing here is shared with a target that cannot see app types.
    internal enum Category: String, Sendable, CaseIterable {
        case analysis, boardload, dgt, eco, engine, game, inspector, library
        case pgnexport, pgnparse, pgnstore, players, power, settings
        case smarttags, uci
    }

    // MARK: Policy

    /// Whether this process logs at all. Off under the test host (one `@Test` drove 2,100 mirrored
    /// lines); re-armed by `DGT_LOG=1` — suppression is only safe while the escape hatch is one
    /// scheme checkbox away.
    internal static let isEnabled: Bool = isEnabled(in: ProcessInfo.processInfo.environment)

    /// The policy as a pure function of an environment — the only form a test can be wrong about:
    /// both constants are fixed in any given process (the "check that could never fail" shape).
    internal static func isEnabled(in environment: [String: String]) -> Bool {
        if environment[enableVariable] == "1" { return true }
        return TestHost.isActive(in: environment) == false
    }

    /// The scheme variable that re-arms logging. A constant because it is named in three places,
    /// and a name that drifts from its documentation is an escape hatch that stops opening.
    internal static let enableVariable = "DGT_LOG"

    // MARK: Door

    /// The app's only `Logger` factory; nil when suppressed. `enabled:` is the seam that makes the
    /// unreachable arm testable — production call sites pass nothing.
    internal static func logger(_ category: Category, enabled: Bool = isEnabled) -> Logger? {
        guard enabled else { return nil }
        return Logger(subsystem: subsystem, category: category.rawValue)
    }
}
