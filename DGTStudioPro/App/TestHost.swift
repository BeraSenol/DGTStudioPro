import Foundation

/// Whether this process is the XCTest host - asked once, spelled once (extracted when `AppLog`
/// became a second reader; two copies of an environment probe stop agreeing the first time
/// Apple renames a marker, and the only symptom is a suite that quietly stops being hermetic).
enum TestHost {

    /// True under XCTest or Swift Testing. Deliberately not injectable - a test that could set it
    /// false would be a test lying about where it lives.
    static let isActive: Bool = isActive(in: ProcessInfo.processInfo.environment)

    /// The probe as a pure function (`AppLog.isEnabled`'s reason): the constant is `true` in every
    /// process a test runs in, so only this form makes the other arm reachable.
    static func isActive(in environment: [String: String]) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
    }
}
