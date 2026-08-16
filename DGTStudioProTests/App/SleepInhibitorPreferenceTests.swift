import Foundation
import Testing

@testable import DGTStudioPro

/// The preference half of `SleepInhibitor` is no longer waived: the
/// "absent reads as true" default and the write-through are the contract
/// that used to be duplicated across an `@AppStorage` initial and a `??`
/// fallback, so it is pinned here rather than trusted.
///
/// **The two-gate revision moved the predicate onto this list too.** The token stays waived -
/// it is `ProcessInfo` transport and the hardware checklist is its witness -
/// but the *decision* stopped being bare when a second gate arrived, because
/// two gates over two causes can be crossed. `activityReason` is pure, so the
/// truth table is cheap and the crossed wiring is reachable from a test.
@MainActor
@Suite("Sleep inhibition preference")
struct SleepInhibitorPreferenceTests {

    /// A throwaway suite per test - `.standard` would edit the developer's
    /// own settings, and a fixed suite name would race under parallel
    /// execution.
    private func withScratchDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let name = "com.berasenol.dgtstudiopro.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    @Test("An untouched preference reads as enabled")
    func absentKeyReadsAsEnabled() throws {
        try withScratchDefaults { defaults in
            let inhibitor = SleepInhibitor(defaults: defaults)
            #expect(inhibitor.preventsSleepDuringPlay)
            #expect(inhibitor.preventsSleepDuringAnalysis)
        }
    }

    @Test("A stored false is honoured")
    func storedFalseIsHonoured() throws {
        try withScratchDefaults { defaults in
            defaults.set(false, forKey: StorageKeys.preventSleepDuringPlay)
            defaults.set(false, forKey: StorageKeys.preventSleepDuringAnalysis)
            let inhibitor = SleepInhibitor(defaults: defaults)
            #expect(inhibitor.preventsSleepDuringPlay == false)
            #expect(inhibitor.preventsSleepDuringAnalysis == false)
        }
    }

    /// **The two gates are independent**, which is the whole point and the
    /// one thing a shared-key implementation would pass every other test
    /// while getting wrong. Each arm sets one key and asserts the *other*
    /// preference is untouched - the assertion that fails if the second
    /// property ever quietly reads the first one's key.
    @Test("Each gate reads its own key")
    func gatesAreIndependent() throws {
        try withScratchDefaults { defaults in
            defaults.set(false, forKey: StorageKeys.preventSleepDuringPlay)
            let playOff = SleepInhibitor(defaults: defaults)
            #expect(playOff.preventsSleepDuringPlay == false)
            #expect(playOff.preventsSleepDuringAnalysis)
        }
        try withScratchDefaults { defaults in
            defaults.set(false, forKey: StorageKeys.preventSleepDuringAnalysis)
            let analysisOff = SleepInhibitor(defaults: defaults)
            #expect(analysisOff.preventsSleepDuringPlay)
            #expect(analysisOff.preventsSleepDuringAnalysis == false)
        }
    }

    @Test("Reading the defaults does not write them back")
    func readingDoesNotPersist() throws {
        try withScratchDefaults { defaults in
            _ = SleepInhibitor(defaults: defaults)
            #expect(defaults.object(forKey: StorageKeys.preventSleepDuringPlay) == nil)
            #expect(defaults.object(forKey: StorageKeys.preventSleepDuringAnalysis) == nil)
        }
    }

    @Test("Flipping a preference survives a relaunch")
    func flippingPersists() throws {
        try withScratchDefaults { defaults in
            let inhibitor = SleepInhibitor(defaults: defaults)
            inhibitor.preventsSleepDuringPlay = false
            inhibitor.preventsSleepDuringAnalysis = false
            let reloaded = SleepInhibitor(defaults: defaults)
            #expect(reloaded.preventsSleepDuringPlay == false)
            #expect(reloaded.preventsSleepDuringAnalysis == false)
        }
    }

    // MARK: The predicate

    /// Neither cause running is the resting state, and it must stay `nil`
    /// whatever the gates say - a preference is permission, not a request.
    @Test("Nothing running holds nothing")
    func idleHoldsNothing() {
        #expect(SleepInhibitor.activityReason(
            playing: false, analyzing: false, allowsPlay: true, allowsAnalysis: true
        ) == nil)
    }

    /// **The crossed wiring**, and the reason this function exists. Each arm
    /// runs one cause with only the *other* gate open, so a predicate that
    /// paired `allowsAnalysis` with playing - which compiles and reads fine -
    /// returns a reason here instead of nil.
    @Test("A gate only permits its own cause")
    func gatesDoNotCross() {
        #expect(SleepInhibitor.activityReason(
            playing: true, analyzing: false, allowsPlay: false, allowsAnalysis: true
        ) == nil)
        #expect(SleepInhibitor.activityReason(
            playing: false, analyzing: true, allowsPlay: true, allowsAnalysis: false
        ) == nil)
    }

    /// Either cause alone holds, and names itself. Asserted on `contains`
    /// rather than on the whole string: the exact wording is a `pmset`
    /// diagnostic that may be reworded, while *which cause is named* is the
    /// contract.
    @Test("Each cause names itself")
    func eachCauseNamesItself() throws {
        let play = try #require(SleepInhibitor.activityReason(
            playing: true, analyzing: false, allowsPlay: true, allowsAnalysis: true
        ))
        #expect(play.contains("Live chess game"))
        #expect(!play.contains("analysis"))

        let analysis = try #require(SleepInhibitor.activityReason(
            playing: false, analyzing: true, allowsPlay: true, allowsAnalysis: true
        ))
        #expect(analysis.contains("analysis"))
        #expect(!analysis.contains("Live chess game"))
    }

    /// Both causes at once name both. A reason that reported only the first
    /// would be the one lie this type's single diagnostic surface can tell,
    /// and it would only ever appear while analyzing during a live game -
    /// which is exactly the session nobody is watching Console for.
    @Test("Two causes name both")
    func bothCausesAreNamed() throws {
        let both = try #require(SleepInhibitor.activityReason(
            playing: true, analyzing: true, allowsPlay: true, allowsAnalysis: true
        ))
        #expect(both.contains("Live chess game"))
        #expect(both.contains("analysis"))
    }

    /// Both gates shut is off, whatever is running - the opt-out still opts
    /// out, which is the contract inherited rather than re-decided.
    @Test("Both gates shut holds nothing")
    func bothGatesShutHoldsNothing() {
        #expect(SleepInhibitor.activityReason(
            playing: true, analyzing: true, allowsPlay: false, allowsAnalysis: false
        ) == nil)
    }
}
