import Testing
@testable import DGTStudioPro

/// The logging gate (D63′).
///
/// **Nonisolated deliberately** — `AppLog` and `TestHost` are namespaces over
/// pure functions, and a suite that needed the main actor would mean one of
/// them had acquired isolation it has no use for. The D44′ shape: the suite is
/// the compile-time witness.
///
/// **Every test here drives the environment as a parameter rather than reading
/// the process's own, and that is the whole point.** `AppLog.isEnabled` and
/// `TestHost.isActive` are constants whose value is fixed by the fact that a
/// test is running: the first is always `false` here and the second always
/// `true`. Asserting them is the "check that could never fail" shape this
/// project keeps cataloguing — it would pass forever while exercising one arm
/// of a two-arm decision. The pure twins exist so the *other* arm, the one a
/// real launch takes, is reachable from a place where it could come out wrong.
@Suite("App log policy")
struct AppLogPolicyTests {

    // MARK: The host probe

    /// A normal launch is not a test host. This is the arm the constant can
    /// never report, because the constant is only ever read from inside a
    /// process that *is* one.
    @Test func anOrdinaryEnvironmentIsNotATestHost() {
        #expect(TestHost.isActive(in: [:]) == false)
        #expect(TestHost.isActive(in: ["HOME": "/Users/bera"]) == false)
    }

    /// Both markers are honoured, independently. The union is deliberate —
    /// XCTest sets the first, Xcode's newer harness also sets the second, and
    /// neither is documented as load-bearing — so each is checked on its own
    /// rather than together, where one working would hide the other failing.
    @Test(arguments: ["XCTestConfigurationFilePath", "XCTestSessionIdentifier"])
    func eitherMarkerAloneIdentifiesTheTestHost(_ variable: String) {
        #expect(TestHost.isActive(in: [variable: "/tmp/whatever"]))
    }

    /// And the live constant agrees with the pure function about the process
    /// this suite is actually running in. The one assertion here that *is*
    /// one-armed, kept because it is what ties the testable spelling to the
    /// shipped one — without it, the pure function could be correct while the
    /// constant read some other variable entirely.
    @Test func theShippedConstantMatchesThePureProbe() {
        #expect(TestHost.isActive)
    }

    // MARK: The gate

    /// A normal launch logs. The default, and the arm no test process is in.
    @Test func anOrdinaryLaunchLogs() {
        #expect(AppLog.isEnabled(in: [:]))
    }

    /// A test host does not — which is the change D63′ exists to make.
    @Test(arguments: ["XCTestConfigurationFilePath", "XCTestSessionIdentifier"])
    func aTestHostIsSilent(_ variable: String) {
        #expect(AppLog.isEnabled(in: [variable: "/tmp/whatever"]) == false)
    }

    /// `DGT_LOG=1` re-arms it, and it is checked *before* the host probe —
    /// which is the only ordering that makes the escape hatch usable, since
    /// the situation it exists for is precisely the one the host probe vetoes.
    ///
    /// Suppressing diagnostics is only a defensible trade while this passes.
    @Test func theEscapeHatchOutranksTheTestHost() {
        let underTest = [
            "XCTestConfigurationFilePath": "/tmp/whatever",
            AppLog.enableVariable: "1"
        ]
        #expect(AppLog.isEnabled(in: underTest))
    }

    /// Only `"1"` arms it. `DGT_LOG=0`, `DGT_LOG=true` and an empty value all
    /// leave a test run silent — so "I set DGT_LOG and got nothing" has one
    /// cause rather than a guess, and an exported-but-empty variable in a
    /// shell profile cannot switch logging on by accident.
    @Test(arguments: ["0", "true", "YES", "", "yes"])
    func onlyTheExactValueArmsTheEscapeHatch(_ value: String) {
        let underTest = [
            "XCTestConfigurationFilePath": "/tmp/whatever",
            AppLog.enableVariable: value
        ]
        #expect(AppLog.isEnabled(in: underTest) == false)
    }

    // MARK: The door

    /// Suppressed means **nil**, not a logger that discards.
    ///
    /// That distinction is the feature: optional chaining short-circuits the
    /// whole postfix expression, so a suppressed call never interpolates its
    /// message. A discarding logger would still pay for every string in a
    /// 986-test run.
    @Test func aSuppressedCategoryHasNoLogger() {
        #expect(AppLog.logger(.dgt, enabled: false) == nil)
    }

    @Test func anEnabledCategoryHasOne() {
        #expect(AppLog.logger(.dgt, enabled: true) != nil)
    }

    /// The shipped default is the policy, not a hardcoded `true` — the seam
    /// through which all twenty-five production call sites are gated.
    @Test func theDefaultParameterIsTheRealPolicy() {
        #expect((AppLog.logger(.dgt) != nil) == AppLog.isEnabled)
    }

    // MARK: Categories

    /// Raw values are distinct, which is the one thing the compiler cannot
    /// check about hand-written raw values — the `InspectorSection` lesson.
    /// Two categories sharing a string would silently merge two subsystems in
    /// Console, and the symptom would be a `log stream` filter returning more
    /// than it should, which reads as "chatty" rather than "broken".
    @Test func everyCategoryHasADistinctRawValue() {
        let raws = AppLog.Category.allCases.map(\.rawValue)
        #expect(Set(raws).count == raws.count)
    }

    /// The three categories the manual-check list names by string are still
    /// spelled that way.
    ///
    /// Asserted on literals deliberately, which is rare and correct here: a
    /// written procedure says to run `log stream --predicate 'category ==
    /// "uci"'` against a live board, and nothing else in the app would notice
    /// if that string moved. This is the only place that check can fail before
    /// somebody is standing at the board with a cable in their hand.
    @Test func theCategoriesNamedInManualChecksKeepTheirSpelling() {
        #expect(AppLog.Category.uci.rawValue == "uci")
        #expect(AppLog.Category.eco.rawValue == "eco")
        #expect(AppLog.Category.players.rawValue == "players")
    }
}
