import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// The converged stamp on the two player backfills. The rules worth pinning: a healing
/// pass never stamps, a clean pass stamps, a stamped store skips the scan entirely - which is
/// the priced trade, asserted rather than assumed - and clearing the default is the recovery.
/// Scratch defaults per test, never `.standard`.
@MainActor
@Suite("PGN Store - Backfill Converged Stamp")
struct PGNStoreHealGateTests {

    // MARK: Helpers

    private static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: PGN.self, Player.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private static func scratchDefaults() throws -> UserDefaults {
        let name = "heal-gate-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// The pre-schema shape the backfill exists for: inserted around the doors, tags present,
    /// links nil.
    @discardableResult
    private static func insertUnlinked(_ context: ModelContext) throws -> PGN {
        let game = PGN(
            event: "Test", site: "Test",
            white: "Senol, Bera", black: "Heylen, Christophe",
            moves: ["e4"], result: .whiteWins
        )
        context.insert(game)
        try context.save()
        return game
    }

    // MARK: The Gate

    @Test("A healing pass does not stamp; the confirming clean pass does")
    func healThenStamp() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let defaults = try Self.scratchDefaults()
        let game = try Self.insertUnlinked(context)

        try store.healPlayersIfNeeded(defaults: defaults)
        #expect(game.whitePlayer != nil)
        #expect(defaults.bool(forKey: StorageKeys.playerBackfillsConverged) == false)

        try store.healPlayersIfNeeded(defaults: defaults)
        #expect(defaults.bool(forKey: StorageKeys.playerBackfillsConverged) == true)
    }

    @Test("A stamped store skips the scan - and clearing the stamp is the recovery")
    func stampSkipsAndClearingHeals() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let defaults = try Self.scratchDefaults()

        // An empty store converges on its first pass.
        try store.healPlayersIfNeeded(defaults: defaults)
        #expect(defaults.bool(forKey: StorageKeys.playerBackfillsConverged))

        let game = try Self.insertUnlinked(context)
        try store.healPlayersIfNeeded(defaults: defaults)
        // The skip is real: a row the scan would have healed stays unhealed. That is the trade
        // The prices - nothing inside the app inserts around the doors, so the gate only ever
        // skips work that converged.
        #expect(game.whitePlayer == nil)

        defaults.set(false, forKey: StorageKeys.playerBackfillsConverged)
        try store.healPlayersIfNeeded(defaults: defaults)
        #expect(game.whitePlayer != nil)
    }
}
