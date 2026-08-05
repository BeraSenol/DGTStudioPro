//
//  TestHost.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 05/08/2026.
//

import Foundation

/// Whether this process is the XCTest host — asked once, spelled once.
///
/// **Extracted 5 Aug 2026 because it had acquired a second reader**, which is
/// the moment D25′ says a value needs an owner. `DGTStudioProApp.init` has
/// asked this since M1 to keep the test host hermetic (a real board must not
/// feed the suite hardware events mid-run), and `AppLog` now asks it to decide
/// whether to emit. Two copies of an environment probe is the twin-read-site
/// pattern in its purest form: they would agree today, and the first time
/// Apple adds or renames a marker variable they would agree no longer, in a
/// way whose only symptom is a suite that quietly stops being hermetic.
///
/// **Both variables are checked, and the redundancy is deliberate.** XCTest
/// marks its host with `XCTestConfigurationFilePath`; Xcode's newer harness
/// also sets `XCTestSessionIdentifier`, and Swift Testing runs under the same
/// harness. Neither is documented as load-bearing, so the union is the honest
/// query — this decides whether hardware I/O starts, and a false negative
/// there is a suite competing with a live serial port for the main actor.
///
/// Computed once into a `static let`: the environment cannot change under a
/// running process, and a lazily-initialized global is the cheapest correct
/// spelling of "ask the OS once".
internal enum TestHost {

    /// True when running under XCTest or Swift Testing.
    ///
    /// Deliberately **not** injectable, unlike D25′'s preference or D45′'s
    /// collapse store. Those are values a *test* wants to vary; this one is a
    /// fact about the process the test is running in, and a test that could
    /// set it to `false` would be a test lying about where it lives.
    internal static let isActive: Bool = isActive(in: ProcessInfo.processInfo.environment)

    /// The probe as a pure function, for the same reason `AppLog.isEnabled`
    /// has one: the constant above is `true` in every process a test runs in,
    /// so a suite asserting it can only ever confirm the arm it is standing
    /// in. This is the spelling the negative case is reachable from.
    ///
    /// The variable names live here and only here. `AppLog` composes this
    /// rather than re-reading the environment, so adding a third marker is
    /// one edit.
    internal static func isActive(in environment: [String: String]) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
    }
}
