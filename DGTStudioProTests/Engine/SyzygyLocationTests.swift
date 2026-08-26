import Testing
import Foundation
@testable import DGTStudioPro

/// Pins `SyzygyLocation`'s keyboard-reachable half (M18 Phase 1): the census summary the
/// Settings diagnostic renders, and the storage clear path. The bookmark-creating store arm
/// and `Access` stay unpinned by decision - both are sandbox transport, witnessed by the
/// Syzygy owed check (whose three readings are the real test of this type).
@Suite("Syzygy Location")
struct SyzygyLocationTests {

    /// The scratch-suite shape `BoardSoundPreferenceTests` uses, for the same reason:
    /// `.standard` would edit real settings, a fixed name would race.
    private func withScratchDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let name = "com.berasenol.dgtstudiopro.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    // MARK: Census

    /// "N WDL · N DTZ" with the middle dot - the string the owed check's three readings parse
    /// by eye, so its shape is a contract with a checklist.
    @Test func aPopulatedCensusSummarizesBothCounts() {
        let census = SyzygyLocation.Census(wdl: 290, dtz: 290)
        #expect(!census.isEmpty)
        #expect(census.summary == "290 WDL · 290 DTZ")
    }

    @Test func anEmptyCensusNamesTheAbsence() {
        let census = SyzygyLocation.Census(wdl: 0, dtz: 0)
        #expect(census.isEmpty)
        #expect(census.summary == "No tablebase files found")
    }

    /// A half-download is *not* empty and shows its asymmetry - the reason DTZ is counted
    /// separately at all.
    @Test func aHalfDownloadShowsTheAsymmetry() {
        let census = SyzygyLocation.Census(wdl: 290, dtz: 0)
        #expect(!census.isEmpty)
        #expect(census.summary == "290 WDL · 0 DTZ")
    }

    // MARK: Storage

    /// The nil-clear is the branch that cannot fail, and it must take both keys - a surviving
    /// display path over a cleared bookmark is Settings showing a folder the engine cannot open.
    @Test func storingNilClearsBothKeys() throws {
        try withScratchDefaults { defaults in
            defaults.set(Data([1, 2, 3]), forKey: StorageKeys.syzygyBookmark)
            defaults.set("/Users/bera/Tables", forKey: StorageKeys.syzygyDisplayPath)

            #expect(SyzygyLocation.store(nil, in: defaults))
            #expect(defaults.data(forKey: StorageKeys.syzygyBookmark) == nil)
            #expect(SyzygyLocation.displayPath(in: defaults) == nil)
        }
    }

    @Test func displayPathReadsItsOwnKey() throws {
        try withScratchDefaults { defaults in
            #expect(SyzygyLocation.displayPath(in: defaults) == nil)
            defaults.set("/Users/bera/Tables", forKey: StorageKeys.syzygyDisplayPath)
            #expect(SyzygyLocation.displayPath(in: defaults) == "/Users/bera/Tables")
        }
    }

    /// Garbage bookmark data resolves to no access token rather than trapping - the init's
    /// one keyboard-reachable refusal.
    @Test func accessRefusesAnUnresolvableBookmark() throws {
        try withScratchDefaults { defaults in
            defaults.set(Data([0xDE, 0xAD]), forKey: StorageKeys.syzygyBookmark)
            #expect(SyzygyLocation.access(in: defaults) == nil)
        }
    }
}
