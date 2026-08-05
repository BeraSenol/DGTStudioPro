import Testing
import SwiftData
@testable import DGTStudioPro

/// Coverage for `OpenGamesRegistry` — the app-global set tracking which open
/// games have unsaved changes (consulted by the Library delete path to decide
/// between immediate-close and discard-confirmation). The registry is a thin,
/// correct wrapper over a `Set<PersistentIdentifier>`; these tests pin its
/// observable contract (toggle, per-game isolation, idempotence).
///
/// `@MainActor`: the registry is an `@Observable @MainActor` class.
///
/// The only honest way to obtain real `PersistentIdentifier` keys is from
/// inserted models, so each test mints them from a fresh in-memory
/// `ModelContainer` (the same idiom as `PGNStoreTests`) and captures the
/// identifiers *after* `save()`, when they are stable. This is the one suite
/// here that leans on SwiftData runtime behaviour rather than being purely
/// by-construction — a fixture failure would surface in `makeIDs`, not in the
/// registry logic under test.
@MainActor
@Suite("Open Games Registry")
struct OpenGamesRegistryTests {

    /// Inserts `count` PGNs into a fresh in-memory context and returns their
    /// stable persistent identifiers.
    private func makeIDs(_ count: Int) throws -> [PersistentIdentifier] {
        let container = try ModelContainer(
            for: PGN.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        var games: [PGN] = []
        for i in 0..<count {
            let pgn = PGN(white: "White \(i)", black: "Black \(i)")
            context.insert(pgn)
            games.append(pgn)
        }
        try context.save()
        return games.map(\.persistentModelID)
    }

    @Test func freshRegistryHasNoDirtyGames() throws {
        let ids = try makeIDs(1)
        let registry = OpenGamesRegistry()
        #expect(registry.isDirty(ids[0]) == false)
    }

    @Test func markDirtyThenMarkCleanTogglesState() throws {
        let ids = try makeIDs(1)
        let registry = OpenGamesRegistry()

        registry.markDirty(ids[0])
        #expect(registry.isDirty(ids[0]) == true)

        registry.markClean(ids[0])
        #expect(registry.isDirty(ids[0]) == false)
    }

    /// Dirty state is tracked per game: marking one leaves the others clean.
    @Test func dirtyStateIsPerGame() throws {
        let ids = try makeIDs(2)
        let registry = OpenGamesRegistry()

        registry.markDirty(ids[0])
        #expect(registry.isDirty(ids[0]) == true)
        #expect(registry.isDirty(ids[1]) == false)
    }

    /// `markDirty` is idempotent and `markClean` on an untracked id is a no-op —
    /// the `Set` semantics that keep the delete path from double-counting or
    /// crashing on an already-clean game.
    @Test func markDirtyIsIdempotentAndCleanIsSafeWhenAbsent() throws {
        let ids = try makeIDs(1)
        let registry = OpenGamesRegistry()

        registry.markDirty(ids[0])
        registry.markDirty(ids[0])
        #expect(registry.isDirty(ids[0]) == true)

        registry.markClean(ids[0])
        registry.markClean(ids[0])
        #expect(registry.isDirty(ids[0]) == false)
    }
}
