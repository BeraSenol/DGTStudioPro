import Foundation
import os

/// The one door to `Logger`, and the one place the logging policy lives.
///
/// Returns `Logger?` rather than a wrapper: optional chaining short-circuits, so a suppressed
/// message is never interpolated. A wrapper cannot do that — `OSLogMessage` is not forwardable,
/// so every message would flatten to `String` and lose its `privacy:` decoration.
///
/// **Message grammar**, kept by every call site: a participle before the work (`"Connecting
/// to …"`), past tense after (`"Classified 12 game(s)"`). A participle whose failure path logs
/// nothing leaves the console showing work that never resolved — that is the defect this rule
/// exists to catch.
enum AppLog {
    
    // MARK: Subsystem and categories
    
    private static let subsystem = "com.berasenol.dgtstudiopro"
    
    /// A **contract with the console**: the manual checks name `uci`, `eco` and `players` in
    /// `log stream` predicates, so renaming a case breaks a written check. Raw values and
    /// `allCases` are pinned by `AppLogPolicyTests`.
    enum Category: String, Sendable, CaseIterable {
        case analysis, boardload, dgt, eco, engine, game, inspector, library
        case pgnexport, pgnparse, pgnstore, players, power, settings
        case smarttags, sound, uci
    }
    
    // MARK: Policy
    
    /// Off under the test host, re-armed by `DGT_LOG=1`.
    static let isEnabled: Bool = isEnabled(in: ProcessInfo.processInfo.environment)
    
    /// The testable twin: the constant above is fixed for the life of the process, so only a
    /// function taking an environment can reach both arms.
    static func isEnabled(in environment: [String: String]) -> Bool {
        if environment[enableVariable] == "1" { return true }
        return TestHost.isActive(in: environment) == false
    }
    
    /// A constant because the name also appears in this file's docs and in the manual checks: an
    /// escape hatch whose name drifts is one that stops opening.
    static let enableVariable = "DGT_LOG"
    
    // MARK: Door
    
    /// nil when suppressed. `enabled:` exists so a test can reach the arm its own process cannot;
    /// production call sites pass nothing.
    static func logger(_ category: Category, enabled: Bool = isEnabled) -> Logger? {
        guard enabled else { return nil }
        return Logger(subsystem: subsystem, category: category.rawValue)
    }
}
