import Foundation
import Testing

@testable import DGTStudioPro

/// The collapse store's contract: the default and the persistence are the whole promise.
@MainActor
@Suite("Inspector section collapse")
struct InspectorSectionCollapseTests {

    /// A throwaway suite per test — `.standard` would edit the developer's own
    /// settings, and a fixed suite name would race under parallel execution.
    /// Lifted verbatim from `SleepInhibitorPreferenceTests`, which is the
    /// helper this suite's subject is modelled on.
    private func withScratchDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let name = "com.berasenol.dgtstudiopro.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    // MARK: Default

    /// Sections default open via the representation: an absent key decodes to the empty set — no
    /// `?? true` to keep in step.
    @Test func absentKeyLeavesEverySectionOpen() throws {
        try withScratchDefaults { defaults in
            let collapse = InspectorSectionCollapse(defaults: defaults)
            #expect(collapse.collapsed.isEmpty)
            for section in InspectorSection.allCases {
                #expect(collapse.isCollapsed(section) == false)
            }
        }
    }

    /// Reading must not write. A first launch that persisted its own default
    /// would put a key in the domain describing state the user never chose,
    /// which is harmless here and is the habit that stops being harmless the
    /// first time a default changes.
    @Test func constructionWritesNothing() throws {
        try withScratchDefaults { defaults in
            _ = InspectorSectionCollapse(defaults: defaults)
            #expect(
                defaults.object(forKey: StorageKeys.collapsedInspectorSections) == nil
            )
        }
    }

    // MARK: Persistence

    @Test func toggleRoundTripsThroughTheStore() throws {
        try withScratchDefaults { defaults in
            let collapse = InspectorSectionCollapse(defaults: defaults)
            collapse.toggle(.pgn)

            #expect(collapse.isCollapsed(.pgn))
            // The reload is the point: a store that only tracked its own
            // in-memory set would pass the line above and lose the state on
            // the next launch.
            let reloaded = InspectorSectionCollapse(defaults: defaults)
            #expect(reloaded.isCollapsed(.pgn))
            #expect(reloaded.collapsed == [.pgn])
        }
    }

    @Test func togglingTwiceLeavesNothingBehind() throws {
        try withScratchDefaults { defaults in
            let collapse = InspectorSectionCollapse(defaults: defaults)
            collapse.toggle(.evaluation)
            collapse.toggle(.evaluation)

            #expect(collapse.collapsed.isEmpty)
            #expect(InspectorSectionCollapse(defaults: defaults).collapsed.isEmpty)
        }
    }

    /// Sections are independent — collapsing one must not disturb another.
    /// Cheap, and it is the assertion that fails if the set is ever replaced
    /// by a single stored section.
    @Test func sectionsCollapseIndependently() throws {
        try withScratchDefaults { defaults in
            let collapse = InspectorSectionCollapse(defaults: defaults)
            collapse.toggle(.pgn)
            collapse.toggle(.ratingTrend)
            collapse.toggle(.pgn)

            #expect(collapse.collapsed == [.ratingTrend])
        }
    }

    // MARK: Retired Sections

    /// The answer to "what does a removed section leave in the store": nothing
    /// that can affect a live one. An unknown raw value is dropped on read —
    /// the alternative, treating it as an error, would make deleting a section
    /// from the app a migration.
    @Test func unknownStoredSectionsAreIgnored() throws {
        try withScratchDefaults { defaults in
            defaults.set(
                ["pgn", "sectionRetiredInSomeFutureVersion", "ratingTrend"],
                forKey: StorageKeys.collapsedInspectorSections
            )

            let collapse = InspectorSectionCollapse(defaults: defaults)
            #expect(collapse.collapsed == [.pgn, .ratingTrend])
        }
    }

    /// …and the next write clears it out, which is the half that makes the
    /// drop permanent rather than perpetual. Asserted on the stored array
    /// rather than on the in-memory set, because that is where the stale
    /// entry would survive.
    @Test func theNextWriteEvictsAnUnknownSection() throws {
        try withScratchDefaults { defaults in
            defaults.set(
                ["pgn", "sectionRetiredInSomeFutureVersion"],
                forKey: StorageKeys.collapsedInspectorSections
            )

            let collapse = InspectorSectionCollapse(defaults: defaults)
            collapse.toggle(.moves)

            let stored = defaults.stringArray(
                forKey: StorageKeys.collapsedInspectorSections
            )
            #expect(stored == ["moves", "pgn"])
        }
    }

    /// A malformed value of the wrong *type* must not crash the read. Not
    /// defensive nil-handling for its own sake: `stringArray(forKey:)` returns
    /// nil for a non-array, and the whole store would silently reset — which
    /// is the correct outcome and worth pinning so it stays deliberate.
    @Test func aNonArrayValueReadsAsNothingCollapsed() throws {
        try withScratchDefaults { defaults in
            defaults.set(
                "pgn",
                forKey: StorageKeys.collapsedInspectorSections
            )

            #expect(InspectorSectionCollapse(defaults: defaults).collapsed.isEmpty)
        }
    }

    // MARK: Stored Form

    /// The written order is sorted, so re-storing identical state produces an
    /// identical array. A `Set`'s iteration order is not stable across runs,
    /// and an unsorted write would churn the domain for no reason — which is
    /// invisible until someone diffs a `defaults export` and finds noise.
    @Test func theStoredArrayIsSorted() throws {
        try withScratchDefaults { defaults in
            let collapse = InspectorSectionCollapse(defaults: defaults)
            for section in [InspectorSection.ratingTrend, .evaluation, .pgn, .moves] {
                collapse.toggle(section)
            }

            let stored = defaults.stringArray(
                forKey: StorageKeys.collapsedInspectorSections
            )
            #expect(stored == ["evaluation", "moves", "pgn", "ratingTrend"])
        }
    }

    /// Raw values are stored form and hand-written (so a rename can't reach the store), which means
    /// two *can* collide — the one check the compiler doesn't do.
    @Test func everySectionHasADistinctStoredKey() {
        let keys = Set(InspectorSection.allCases.map(\.rawValue))
        #expect(keys.count == InspectorSection.allCases.count)
    }
}
