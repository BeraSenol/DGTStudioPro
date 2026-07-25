//
//  SleepInhibitorPreferenceTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 25/07/2026.
//


import Foundation
import Testing

@testable import DGTStudioPro

/// D25′ — the preference half of `SleepInhibitor` is no longer waived: the
/// "absent reads as true" default and the write-through are the contract
/// that used to be duplicated across an `@AppStorage` initial and a `??`
/// fallback, so it is pinned here rather than trusted. Inhibition itself
/// stays waived — it's a `ProcessInfo` token over a bare predicate, and the
/// hardware checklist is its witness.
@MainActor
@Suite("Sleep inhibition preference")
internal struct SleepInhibitorPreferenceTests {

    /// A throwaway suite per test — `.standard` would edit the developer's
    /// own settings, and a fixed suite name would race under parallel
    /// execution.
    private func withScratchDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let name = "com.berasenol.dgtstudiopro.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    @Test("An untouched preference reads as enabled")
    internal func absentKeyReadsAsEnabled() throws {
        try withScratchDefaults { defaults in
            #expect(SleepInhibitor(defaults: defaults).isEnabled)
        }
    }

    @Test("A stored false is honoured")
    internal func storedFalseIsHonoured() throws {
        try withScratchDefaults { defaults in
            defaults.set(false, forKey: StorageKeys.preventSleepDuringPlay)
            #expect(SleepInhibitor(defaults: defaults).isEnabled == false)
        }
    }

    @Test("Reading the default does not write it back")
    internal func readingDoesNotPersist() throws {
        try withScratchDefaults { defaults in
            _ = SleepInhibitor(defaults: defaults)
            #expect(defaults.object(forKey: StorageKeys.preventSleepDuringPlay) == nil)
        }
    }

    @Test("Flipping the preference survives a relaunch")
    internal func flippingPersists() throws {
        try withScratchDefaults { defaults in
            let inhibitor = SleepInhibitor(defaults: defaults)
            inhibitor.isEnabled = false
            #expect(SleepInhibitor(defaults: defaults).isEnabled == false)
        }
    }
}
