import Testing
@testable import DGTStudioPro

/// The logging gate. Nonisolated; the pure twins exist because the constants are fixed
/// in any given process - only the parameterized forms make the other arm reachable.
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

    /// Both markers are honoured, independently. The union is deliberate -
    /// XCTest sets the first, Xcode's newer harness also sets the second, and
    /// neither is documented as load-bearing - so each is checked on its own
    /// rather than together, where one working would hide the other failing.
    @Test(arguments: ["XCTestConfigurationFilePath", "XCTestSessionIdentifier"])
    func eitherMarkerAloneIdentifiesTheTestHost(_ variable: String) {
        #expect(TestHost.isActive(in: [variable: "/tmp/whatever"]))
    }

    /// The live constant agrees with the pure probe about *this* process - the one one-armed
    /// assertion, kept because it ties the testable spelling to the shipped one.
    @Test func theShippedConstantMatchesThePureProbe() {
        #expect(TestHost.isActive)
    }

    // MARK: The gate

    /// A normal launch logs. The default, and the arm no test process is in.
    @Test func anOrdinaryLaunchLogs() {
        #expect(AppLog.isEnabled(in: [:]))
    }

    /// A test host does not - which is the change the logging policy exists to make.
    @Test(arguments: ["XCTestConfigurationFilePath", "XCTestSessionIdentifier"])
    func aTestHostIsSilent(_ variable: String) {
        #expect(AppLog.isEnabled(in: [variable: "/tmp/whatever"]) == false)
    }

    /// `DGT_LOG=1` outranks the host probe - the only ordering that makes the escape hatch usable.
    @Test func theEscapeHatchOutranksTheTestHost() {
        let underTest = [
            "XCTestConfigurationFilePath": "/tmp/whatever",
            AppLog.enableVariable: "1"
        ]
        #expect(AppLog.isEnabled(in: underTest))
    }

    /// Only `"1"` arms it. `DGT_LOG=0`, `DGT_LOG=true` and an empty value all
    /// leave a test run silent - so "I set DGT_LOG and got nothing" has one
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

    /// Suppressed means **nil**, not a discarding logger: optional chaining short-circuits, so a
    /// suppressed call never interpolates.
    @Test func aSuppressedCategoryHasNoLogger() {
        #expect(AppLog.logger(.dgt, enabled: false) == nil)
    }

    @Test func anEnabledCategoryHasOne() {
        #expect(AppLog.logger(.dgt, enabled: true) != nil)
    }

    /// The shipped default is the policy, not a hardcoded `true` - the seam
    /// through which all twenty-five production call sites are gated.
    @Test func theDefaultParameterIsTheRealPolicy() {
        #expect((AppLog.logger(.dgt) != nil) == AppLog.isEnabled)
    }

    // MARK: Categories

    /// Raw values are distinct - the one thing the compiler cannot check about hand-written ones.
    @Test func everyCategoryHasADistinctRawValue() {
        let raws = AppLog.Category.allCases.map(\.rawValue)
        #expect(Set(raws).count == raws.count)
    }

    /// The three categories the manual checks name by string keep their spelling - asserted on
    /// literals, rare and correct: the check's runner is a person at a Console.
    @Test func theCategoriesNamedInManualChecksKeepTheirSpelling() {
        #expect(AppLog.Category.uci.rawValue == "uci")
        #expect(AppLog.Category.eco.rawValue == "eco")
        #expect(AppLog.Category.players.rawValue == "players")
    }
}
