import Testing
import SwiftData
@testable import DGTStudioPro

/// `OpenGamesRegistry` - the unsaved-changes set the delete path consults. Real
/// `PersistentIdentifier`s come from a throwaway in-memory container; the registry itself never
/// touches SwiftData.
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

    /// `markDirty` is idempotent and `markClean` on an untracked id is a no-op -
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
