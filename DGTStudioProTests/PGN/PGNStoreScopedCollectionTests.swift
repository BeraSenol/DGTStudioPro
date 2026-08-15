import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// Orphan collection is scoped at the editing doors: an edit checks only the rows it
/// displaced, a rename only its source, and the pre-existing backlog stays the backfill's.
/// The half that must not change rides alongside: the displaced row still goes, in the same
/// transaction, which is what keeps rename an honest merge replacement.
@MainActor
@Suite("PGN Store — Scoped Orphan Collection")
struct PGNStoreScopedCollectionTests {

    // MARK: Helpers

    private static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: PGN.self, Player.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private static func pgnText(
        white: String = "Old, Name",
        black: String = "Rival, Some"
    ) -> String {
        """
        [Event "Test"]
        [Site "Test"]
        [Date "2026.05.15"]
        [Round "1"]
        [White "\(white)"]
        [Black "\(black)"]
        [Result "1-0"]

        1. e4 e5
        1-0
        """
    }

    private static func key(forTag tag: String) -> String {
        Player.normalizedKey(for: PlayerName.displayForm(of: tag))
    }

    // MARK: The Scope

    @Test("A seat edit collects its displaced row and spares an unrelated orphan")
    func applyEditIsScoped() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let game = try store.importPGN(text: Self.pgnText())
        _ = try #require(try store.resolvePlayer(named: "Linkless, Bystander"))
        try context.save()

        try store.applyEdit(to: game) { $0.white = "New, Name" }

        // Fetch-based assertions throughout, never `isDeleted`: once the containing save runs,
        // a deleted row reads `isDeleted == false` again (the fault is expunged), so the lookup
        // is the only honest witness on a door that saves.
        // The displaced row went with the edit; the bystander is the backfill's business.
        #expect(try store.player(withNormalizedKey: Self.key(forTag: "Old, Name")) == nil)
        #expect(try store.player(withNormalizedKey: Self.key(forTag: "Linkless, Bystander")) != nil)
        #expect(game.whitePlayer?.normalizedName == Self.key(forTag: "New, Name"))

        // The global arm still owns the backlog.
        try store.backfillPlayerLinks()
        #expect(try store.player(withNormalizedKey: Self.key(forTag: "Linkless, Bystander")) == nil)
    }

    @Test("A rename collects exactly its source row")
    func retagIsScoped() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let game = try store.importPGN(text: Self.pgnText())
        _ = try #require(try store.resolvePlayer(named: "Linkless, Bystander"))
        try context.save()
        let source = try #require(game.whitePlayer)

        _ = try store.retag(source, to: "Brand, New")

        // Fetch-based for the `isDeleted`-after-save reason above.
        #expect(try store.player(withNormalizedKey: Self.key(forTag: "Old, Name")) == nil)
        #expect(try store.player(withNormalizedKey: Self.key(forTag: "Linkless, Bystander")) != nil)
        #expect(game.white == "Brand, New")
    }
}
