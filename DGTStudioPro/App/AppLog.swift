import Foundation
import os

/// The one place that decides whether the app logs, and the one place that
/// says what a log line looks like.
///
/// D63′. Every type held its own `Logger(subsystem:category:)`, so the subsystem
/// string was written once per type and the *policy* — emit or don't — was
/// written nowhere. D25′'s rule applied to the last ownerless value in the app.
///
/// # Suppression
///
/// `logger(_:)` returns **nil** when logging is off, so a call site reads
/// `Self.logger?.info("…")` and optional chaining short-circuits the whole
/// postfix expression — a suppressed message is never even interpolated.
/// Nil-means-silent is this project's own idiom rather than a new one:
/// `sessionLog`, `onGameFinished`, `onDesync`, `boardIdentity` and
/// `requestBoardResync` all work this way, under the invariant that *nil hooks
/// mean unit tests run headless by construction*.
///
/// Rejected: a struct wrapping `Logger` with `String` parameters. It reads
/// better at the declaration and it costs the `privacy:` annotations —
/// `OSLogMessage` is compiler-synthesized and cannot be forwarded, so every
/// message would flatten to an already-interpolated `String`. Free only until
/// the first site that wants redaction.
///
/// # The house grammar
///
/// Written here because this is the only file every log line has in common.
///
/// 1. **One line, one fact.** A sentence needing "and" is two lines, or one
///    line with `key=value` details.
/// 2. **Past tense for something that happened** — `Archived`, `Created`,
///    `Imported`, `Deleted`, `Retagged`, `Classified`.
/// 3. **Present participle for work begun, and the outcome must be
///    discoverable** — a completion line, or an error line on the failure path.
///    `Connecting to …` is answered by `Connected: …`. **A participle whose
///    failure path is silent is the defect to look for.** The two tenses are
///    not interchangeable: participles log *before* the work and past tense
///    *after* it, so flattening them would make half the lines claim a thing
///    had happened at the moment it was attempted — wrong, and wrong only on
///    the failure path, which is the one path anybody reads a log on.
/// 4. **User data in single quotes** — `Created player 'Alice'`. Numbers and
///    enum-ish values go bare, so a quote mark means "this text is not ours".
/// 5. **Structured facts trail as `key=value`**, space-separated, lowercase
///    keys, no spaces around `=` — `plies=42 tags=9`. Prose first, data last.
/// 6. **No function names, no file names, no line numbers.** The category says
///    where a line came from and `os.Logger` carries the rest. Two deliberate
///    exceptions: `IOServiceMatching` / `IOServiceGetMatchingServices` name the
///    *OS* call that failed, the only useful thing an IOKit failure can say;
///    and `recv:` / `send:` in the `uci` category stay lowercase and un-prosed,
///    being the wire-direction markers every UCI transcript uses.
/// 7. **An error says what failed *and* what happened next** — `Archive failed:
///    … — draft kept, new-game entry suppressed`. An error that only names the
///    failure makes the reader guess whether anything was lost.
internal enum AppLog {

    // MARK: Subsystem and categories

    /// Spelled once. It was spelled twenty-five times.
    private static let subsystem = "com.berasenol.dgtstudiopro"

    /// The categories, which are a **contract with the console** rather than
    /// free strings.
    ///
    /// The manual-check list drives verification through
    /// `log stream --predicate 'category == "…"'` for `uci`, `eco` and
    /// `players`, so a raw value here is something a written procedure names.
    /// Hand-written for the `InspectorSection` reason: renaming a case must
    /// not silently retarget a check somebody is going to run against a live
    /// board six months from now.
    ///
    /// Typed rather than `String` — deliberately unlike `AccessibilityID`,
    /// and the difference is worth one sentence because that file argues the
    /// opposite. Its signatures stayed `String` because they were shared with
    /// a target that could not see the app's types; nothing is shared here,
    /// and what a typed category buys is the answer to "which categories
    /// exist", which is a question the manual checks ask and a grep for
    /// `category:` could only approximate.
    internal enum Category: String, Sendable, CaseIterable {
        case analysis, boardload, dgt, eco, engine, game, inspector, library
        case pgnexport, pgnparse, pgnstore, players, power, settings
        case smarttags, uci
    }

    // MARK: Policy

    /// Whether this process logs at all.
    ///
    /// Off under the test host, because a ⌘U run is the one context where the
    /// app's narration is somebody else's output. It was drowning the thing it
    /// shared a console with: a single `@Test` drives 2,100 `record` calls
    /// through the session log's ring-buffer cap and every one mirrored to
    /// Console, and the engine suites reprint Stockfish's whole option
    /// advertisement once per start. The signal — which test failed and why —
    /// was a handful of lines inside tens of thousands.
    ///
    /// **`DGT_LOG=1` puts it all back**, which is the half that makes this
    /// safe rather than merely quiet. Suppressing diagnostics is only a good
    /// trade if the diagnostics are one scheme checkbox away when a test
    /// actually fails, and an escape hatch nobody can find is the same as no
    /// escape hatch — so it is named here, at the `DGT_LOG` constant, and in
    /// the manual checks.
    ///
    /// Checked *before* the host, so setting it in a test scheme works: the
    /// variable exists to be read in exactly the situation the host check
    /// would otherwise veto.
    internal static let isEnabled: Bool = isEnabled(in: ProcessInfo.processInfo.environment)

    /// The policy as a pure function of an environment, which is the only
    /// form of it a test can be wrong about.
    ///
    /// **The constant above cannot be meaningfully tested and this can**,
    /// which is D44′'s rule rather than a preference. `isEnabled` is `false`
    /// in every process a test runs in, so a suite asserting it is `false`
    /// passes without ever exercising the branch that matters — and a suite
    /// asserting it is `true` could only pass with `DGT_LOG` set, i.e. a test
    /// that fails whenever somebody turns logging on to debug something. Both
    /// spellings are the "check that could never fail" shape. Taking the
    /// environment as a parameter is what lets both arms be driven from the
    /// side where they would break.
    internal static func isEnabled(in environment: [String: String]) -> Bool {
        if environment[enableVariable] == "1" { return true }
        return TestHost.isActive(in: environment) == false
    }

    /// The scheme variable that re-arms logging under test.
    ///
    /// A constant rather than a literal because it is named in three places —
    /// here, this file's doc, and the manual-check list — and a variable name
    /// that drifts from its documentation is an escape hatch that silently
    /// stops opening.
    internal static let enableVariable = "DGT_LOG"

    // MARK: Door

    /// The app's only `Logger` factory. Nil when suppressed.
    ///
    /// Call sites hold the result in a `private static let` and reach it as
    /// `Self.logger?.info(…)`.
    ///
    /// `enabled` defaults to the real policy and exists so a suite can drive
    /// the arm the test host can never reach — the same reason `isEnabled`
    /// has a pure twin. Twenty-five production call sites pass nothing.
    internal static func logger(_ category: Category, enabled: Bool = isEnabled) -> Logger? {
        guard enabled else { return nil }
        return Logger(subsystem: subsystem, category: category.rawValue)
    }
}
