//
//  PGNStoreRetagTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 30/07/2026.
//

import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// M5's store door: rename, merge and delete over `Player` (D37′, D38′, D39′).
///
/// The claims worth pinning are the ones that are cheap to get wrong and
/// invisible once wrong: that a rename reaches the *games'* stored tags rather
/// than the registry row (D37′, which is what makes export tell the truth);
/// that merge survives `applyEdit`'s unconditional re-resolve (D38′, the trap
/// that forced merge and rename onto one door); that a rewrite which would
/// collide two games' content hashes is refused **before** anything is written
/// (D39′); and that a self-play row — the same player on both sides — is one
/// rewrite with both seats, not two half-rewrites whose prospective hashes the
/// game never actually reaches.
///
/// `@MainActor`: fronts `PGNStore` and realized `@Model`s, matching the other
/// store suites.
@MainActor
@Suite("PGN Store — Player Retag, Merge and Delete")
struct PGNStoreRetagTests {

    // MARK: Helpers

    private static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: PGN.self, Player.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// `round` varies the content hash, so several games with one pairing can
    /// coexist without tripping the archive door's deduplication.
    private static func pgnText(
        white: String = "Senol, Bera",
        black: String = "Reinaud, Lorenzo",
        round: Int = 1,
        moves: String = "1. e4 e5 1-0"
    ) -> String {
        """
        [Event "Club Night"]
        [Site "Home"]
        [Date "2026.05.15"]
        [Round "\(round)"]
        [White "\(white)"]
        [Black "\(black)"]
        [Result "1-0"]

        \(moves)
        """
    }

    private static func store() throws -> PGNStore {
        PGNStore(modelContext: try makeContext())
    }

    /// The sweep's two halves live on either side of the view/store line
    /// (D40′) — `PGNStore.isOrphaned` is the rule, a `@Query` supplies the rows
    /// — so its pins need the context too, and compose it exactly the way
    /// `PlayersDestination` does rather than through a convenience the app
    /// doesn't have.
    private static func storeAndContext() throws -> (PGNStore, ModelContext) {
        let context = try makeContext()
        return (PGNStore(modelContext: context), context)
    }

    private static func orphans(in context: ModelContext) throws -> [Player] {
        try context.fetch(FetchDescriptor<Player>()).filter(PGNStore.isOrphaned)
    }

    /// Mints a linkless registry row — an orphan of the only kind that still
    /// occurs, now that `delete(_ pgns:)` collects the ones a game deletion
    /// would strand.
    ///
    /// Through `resolvePlayer`, not `context.insert(Player(...))`: D9′'s single
    /// creation door is the whole reason a row exists at all, and a fixture
    /// that constructs one directly would pin the sweep against a shape the app
    /// cannot produce. The explicit `save` is not ceremony — the door inserts
    /// without saving by contract, and these suites fetch.
    private static func orphanedRow(
        _ store: PGNStore,
        in context: ModelContext,
        named tag: String
    ) throws -> Player {
        let player = try #require(try store.resolvePlayer(named: tag))
        try context.save()
        return player
    }

    private static func player(
        _ store: PGNStore,
        named tag: String
    ) throws -> Player {
        try #require(try store.resolvePlayer(named: tag))
    }

    /// The identity key a raw *tag* resolves to — `resolvePlayer`'s own route,
    /// tag → display form → fold.
    ///
    /// Spelled once, because `Player.normalizedKey(for:)` takes a **display**
    /// form: handing it a comma tag gives `"senol, bera"`, a key no player row
    /// ever carries, and every lookup written that way quietly returns nil and
    /// passes an "it's gone" assertion for the wrong reason.
    private static func key(forTag tag: String) -> String {
        Player.normalizedKey(for: PlayerName.displayForm(of: tag))
    }

    // MARK: Library Index — D58′

    /// The index is filing, not identity: one game filed under two different
    /// numbers is one game, so the second import is refused as a duplicate.
    ///
    /// **Asserted as the behaviour rather than as a digest comparison**, which
    /// is both the stronger claim and the only one available — `contentHash`
    /// is private to the store, and widening it to suit a test would trade the
    /// one-hash invariant's encapsulation for a weaker assertion.
    ///
    /// Checked on the *identifier* rather than on the bare fact of a throw, the
    /// `renamedGameExportRoundTrips` rule: a refusal naming some other game
    /// would satisfy a weaker test while meaning the opposite.
    ///
    /// This is the field most likely to be folded into the hash by a future
    /// reader, because unlike `board` and `timeControl` it *looks* like an
    /// identifier. If it ever is, this test is what says so.
    @Test("A game filed under two different numbers is still one game")
    func theLibraryIndexIsOutsideTheContentHash() throws {
        let store = try Self.store()
        let first = try store.importPGN(text: Self.pgnText(), libraryIndex: 47)

        #expect(first.libraryIndex == 47)

        do {
            _ = try store.importPGN(text: Self.pgnText(), libraryIndex: 1_284)
            Issue.record("expected the re-filed copy to be refused")
        } catch let error as PGNStore.Error {
            guard case .duplicate(let existingID, _) = error else {
                Issue.record("expected .duplicate, got \(error)")
                return
            }
            #expect(existingID == first.persistentModelID)
        }
    }

    /// An import with no ordinal keeps none — nil is a real answer, and the
    /// door must not invent one to fill the column.
    ///
    /// The negative half of the pair above, and the one that would fail if
    /// somebody "helpfully" defaulted the parameter to a running count.
    @Test("A game imported without a filename ordinal keeps none")
    func textImportCarriesNoIndex() throws {
        let store = try Self.store()
        let game = try store.importPGN(text: Self.pgnText())
        #expect(game.libraryIndex == nil)
    }

    // MARK: Rename — D37′

    /// The decision itself: a rename reaches the stored seat tag, not just the
    /// registry row. If this ever regresses to touching `Player.name` alone,
    /// export starts writing a name the Players list doesn't show.
    @Test("Rename rewrites the games' stored seat tags")
    func renameRewritesStoredTags() throws {
        let store = try Self.store()
        let game = try store.importPGN(text: Self.pgnText())
        let bera = try Self.player(store, named: "Senol, Bera")

        let count = try store.retag(bera, to: "Şenol, Bera")

        #expect(count == 1)
        #expect(game.white == "Şenol, Bera")
        // The registry row follows, through the one transform D23′ allows.
        #expect(game.whitePlayer?.name == "Bera Şenol")
    }

    /// The accepted cost, pinned so it is a decision rather than a surprise:
    /// seat tags are inside the content hash, so a rename moves it.
    @Test("Rename changes the affected games' content hash")
    func renameChangesTheHash() throws {
        let store = try Self.store()
        let game = try store.importPGN(text: Self.pgnText())
        let before = game.contentHash

        try store.retag(try Self.player(store, named: "Senol, Bera"), to: "Şenol, Bera")

        #expect(game.contentHash != before)
    }

    /// Games the player isn't in are untouched — the rewrite is scoped by the
    /// relationship, not by a string sweep over the Library.
    @Test("Rename leaves unrelated games alone")
    func renameLeavesOthersAlone() throws {
        let store = try Self.store()
        _ = try store.importPGN(text: Self.pgnText())
        let other = try store.importPGN(
            text: Self.pgnText(white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian", round: 2)
        )
        let otherHash = other.contentHash

        try store.retag(try Self.player(store, named: "Senol, Bera"), to: "Şenol, Bera")

        #expect(other.white == "Carlsen, Magnus")
        #expect(other.contentHash == otherHash)
    }

    /// Both seats of a self-play row rewrite together. The seat-wise shape got
    /// this wrong in a way no ordinary fixture reaches.
    @Test("A self-play game rewrites both seats in one pass")
    func selfPlayRewritesBothSeats() throws {
        let store = try Self.store()
        let game = try store.importPGN(
            text: Self.pgnText(white: "Senol, Bera", black: "Senol, Bera")
        )
        let bera = try Self.player(store, named: "Senol, Bera")

        let count = try store.retag(bera, to: "Şenol, Bera")

        // One game, not two — the union is folded on identity.
        #expect(count == 1)
        #expect(game.white == "Şenol, Bera")
        #expect(game.black == "Şenol, Bera")
    }

    /// `"?"` and empty are PGN's vocabulary for *no player*; retagging to one
    /// is a deletion in a rename's clothes, and the door says so.
    @Test("Retagging to a placeholder is refused", arguments: ["?", "", "   "])
    func placeholderTagRefused(tag: String) throws {
        let store = try Self.store()
        let game = try store.importPGN(text: Self.pgnText())
        let bera = try Self.player(store, named: "Senol, Bera")

        #expect(throws: PGNStore.RetagRejection.self) {
            try store.retag(bera, to: tag)
        }
        #expect(game.white == "Senol, Bera")
    }

    // MARK: Collision refusal — D39′

    /// The Library-side collision: the rewrite would land on a row that
    /// already exists. Refused, and — the load-bearing half — refused with
    /// nothing written.
    @Test("A rename that would collide with an existing game is refused whole")
    func collidingRenameIsRefusedWhole() throws {
        let store = try Self.store()
        // Same game, two spellings of White, so the hashes differ today and
        // would coincide the moment one spelling becomes the other.
        let first = try store.importPGN(text: Self.pgnText(white: "Senol, Bera"))
        let second = try store.importPGN(text: Self.pgnText(white: "Bera"))
        let firstHash = first.contentHash
        let secondHash = second.contentHash

        let bera = try Self.player(store, named: "Bera")
        #expect(throws: PGNStore.RetagRejection.self) {
            try store.retag(bera, to: "Senol, Bera")
        }

        // Nothing moved: the refusal is pre-flight, so a rejected rename is
        // indistinguishable from one never attempted.
        #expect(second.white == "Bera")
        #expect(first.contentHash == firstHash)
        #expect(second.contentHash == secondHash)
    }

    /// The refusal names the games, because "this would create a duplicate" is
    /// unactionable without saying which two.
    @Test("The refusal carries the colliding pair")
    func refusalNamesTheCollidingGames() throws {
        let store = try Self.store()
        let first = try store.importPGN(text: Self.pgnText(white: "Senol, Bera"))
        let second = try store.importPGN(text: Self.pgnText(white: "Bera"))
        let bera = try Self.player(store, named: "Bera")

        do {
            try store.retag(bera, to: "Senol, Bera")
            Issue.record("Expected the retag to be refused")
        } catch let rejection as PGNStore.RetagRejection {
            guard case .wouldCollide(let collisions) = rejection else {
                Issue.record("Expected .wouldCollide, got \(rejection)")
                return
            }
            #expect(collisions.count == 1)
            #expect(collisions.first?.gameID == second.persistentModelID)
            #expect(collisions.first?.existingID == first.persistentModelID)
        }
    }

    /// The batch-internal collision, which a Library-only probe misses: both
    /// copies belong to the player being retagged, so neither is in the store
    /// under its future hash yet. This is the double-imported game that
    /// motivates merging in the first place, one copy per spelling.
    @Test("Two of the player's own games colliding with each other is caught")
    func batchInternalCollisionIsCaught() throws {
        let store = try Self.store()
        // Both games are "Bera"'s, and differ only in the *black* spelling —
        // so retagging Black's player collapses them onto one hash.
        _ = try store.importPGN(text: Self.pgnText(black: "Reinaud, Lorenzo"))
        _ = try store.importPGN(text: Self.pgnText(black: "Lorenzo Reinaud"))
        // Both black seats resolve to one player already (display-form
        // identity), which is precisely why the batch holds two games.
        let lorenzo = try Self.player(store, named: "Reinaud, Lorenzo")
        #expect(lorenzo.blackGames.count == 2)

        #expect(throws: PGNStore.RetagRejection.self) {
            try store.retag(lorenzo, to: "Reinaud, L")
        }
    }

    /// A rename that only changes casing or spacing folds to the same hash the
    /// game already has, so the game collides with *itself* — which is not a
    /// collision. The identity check in the pre-flight is what makes this pass.
    @Test("A fold-equivalent rename is not a self-collision")
    func foldEquivalentRenameIsAllowed() throws {
        let store = try Self.store()
        let game = try store.importPGN(text: Self.pgnText(white: "senol,  bera"))
        let bera = try Self.player(store, named: "senol,  bera")

        try store.retag(bera, to: "Senol, Bera")

        #expect(game.white == "Senol, Bera")
    }

    // The four merge pins (moves-and-deletes, survives-applyEdit,
    // merge-into-self, colliding-merge-refused) went with `merge` itself
    // (D52′, 4 Aug 2026). What they guarded that still needs guarding is
    // guarded: the rename pins cover the same retag door — collision
    // refusal, fold-equivalent identity, resolver-only target creation —
    // and the applyEdit re-resolve contract is pinned by the rename
    // round-trips above.

    // MARK: Delete — the orphan sweep (D38′'s guard, D40′'s surface)

    /// The guard's reason, now expressed as absence rather than refusal: a
    /// linked player is never *offered*, because `.nullify` leaves the games'
    /// tags intact and the Library's next `backfillPlayerLinks()` resolves
    /// those same tags and creates the row again. A delete the app undoes
    /// within one navigation is worse than no delete.
    @Test("A linked player is never listed as an orphan")
    func linkedPlayerIsNeverListed() throws {
        let (store, context) = try Self.storeAndContext()
        _ = try store.importPGN(text: Self.pgnText())

        #expect(try Self.orphans(in: context).isEmpty)
        #expect(try store.player(withNormalizedKey: Self.key(forTag: "Senol, Bera")) != nil)
    }

    /// And the case the sweep still exists for. It used to be spelled by
    /// deleting a player's last game; the cascade collects those at the source
    /// now, so the remaining orphan is a registry row that never had a link —
    /// the pre-cascade backlog, and anything a future path strands.
    @Test("An unlinked registry row is listed, and the sweep removes it")
    func orphanedPlayerIsListedAndSwept() throws {
        let (store, context) = try Self.storeAndContext()
        _ = try Self.orphanedRow(store, in: context, named: "Ghost, Casper")

        let orphans = try Self.orphans(in: context)
        #expect(orphans.contains { $0.normalizedName == Self.key(forTag: "Ghost, Casper") })
        #expect(try store.deleteOrphanedPlayers(orphans) == orphans.count)
        #expect(try store.player(withNormalizedKey: Self.key(forTag: "Ghost, Casper")) == nil)
    }

    /// The snapshot guard. The sweep acts on a list built for a confirmation
    /// dialog, so between listing and deleting a row can pick up a link — here
    /// by importing a game under the same tag, which resolves onto the existing
    /// orphan rather than minting a row. Deleting it then would nullify live
    /// links, so the re-check must skip it.
    @Test("A row that gained a link since it was listed is skipped")
    func sweepSkipsARowRelinkedSinceListing() throws {
        let (store, context) = try Self.storeAndContext()
        _ = try Self.orphanedRow(store, in: context, named: "Senol, Bera")
        let stale = try Self.orphans(in: context)
        #expect(!stale.isEmpty)

        _ = try store.importPGN(text: Self.pgnText())

        #expect(try store.deleteOrphanedPlayers(stale) == 0)
        #expect(try store.player(withNormalizedKey: Self.key(forTag: "Senol, Bera")) != nil)
    }

    // MARK: Delete — the game-deletion cascade

    /// The decision: deleting the last game a player appears in takes the row
    /// with it. This is the half of D9′'s "no collector" that is narrowed —
    /// and it works where the roadmap's old delete-player could not, because
    /// the seat tags go with the game, leaving `backfillPlayerLinks()` nothing
    /// to resolve the row back out of.
    @Test("Deleting the last game collects both of its players")
    func deletingTheLastGameCollectsItsPlayers() throws {
        let store = try Self.store()
        let game = try store.importPGN(text: Self.pgnText())

        try store.delete(game)

        #expect(try store.player(withNormalizedKey: Self.key(forTag: "Senol, Bera")) == nil)
        #expect(try store.player(withNormalizedKey: Self.key(forTag: "Reinaud, Lorenzo")) == nil)
    }

    /// The other half, and the one a careless cascade gets wrong: a player with
    /// a game outside the deletion set stays. Without this the feature is a
    /// registry wipe wearing a delete button.
    @Test("A player with another game survives the deletion")
    func aPlayerWithAnotherGameSurvives() throws {
        let store = try Self.store()
        let first = try store.importPGN(text: Self.pgnText())
        _ = try store.importPGN(
            text: Self.pgnText(black: "Carlsen, Magnus", round: 2)
        )

        try store.delete(first)

        // Bera held both games; only Lorenzo's last one went.
        #expect(try store.player(withNormalizedKey: Self.key(forTag: "Senol, Bera")) != nil)
        #expect(try store.player(withNormalizedKey: Self.key(forTag: "Reinaud, Lorenzo")) == nil)
    }

    /// One player on both sides is one row, collected once. A seat-wise reading
    /// reaches `modelContext.delete` twice for the same model here — the
    /// identifier-keyed fold in `playersOrphaned(byDeleting:)` is what prevents
    /// it, and this is the fixture that exercises it (`selfPlayRewritesBothSeats`
    /// is the same shape guarding the retag).
    @Test("A self-play game's single player is collected once")
    func selfPlayCollectsTheRowOnce() throws {
        let (store, context) = try Self.storeAndContext()
        let game = try store.importPGN(
            text: Self.pgnText(white: "Senol, Bera", black: "Senol, Bera")
        )

        try store.delete(game)

        #expect(try store.player(withNormalizedKey: Self.key(forTag: "Senol, Bera")) == nil)
        #expect(try context.fetch(FetchDescriptor<Player>()).isEmpty)
    }

    /// The batch case a per-game reading cannot see: each row on its own leaves
    /// the player looking survivable, because the game that would save it is
    /// also going. Only the set question answers this, which is why the
    /// predicate takes the whole deletion set rather than one game at a time.
    @Test("A player spread across a batch is collected by it")
    func aBatchCollectsAPlayerSpreadAcrossIt() throws {
        let store = try Self.store()
        let first = try store.importPGN(text: Self.pgnText())
        let second = try store.importPGN(text: Self.pgnText(round: 2))

        try store.delete([first, second])

        #expect(try store.player(withNormalizedKey: Self.key(forTag: "Senol, Bera")) == nil)
    }

    /// The propagation-timing pin, and the reason it is spelled as a *pure*
    /// question rather than a post-delete relationship read.
    ///
    /// This asserts the predicate answers correctly with **nothing deleted
    /// yet** — no `modelContext.delete` has been called, so an implementation
    /// that asked `isOrphaned` after the fact could not produce this answer at
    /// all. It is the shape of check the project keeps rediscovering it needs:
    /// one that could have failed. A test that deleted the game first and
    /// looked for the row would pass whenever SwiftData happened to have
    /// propagated the inverse, and pass just as quietly on the day it doesn't.
    @Test("The cascade is answerable before anything is deleted")
    func theCascadeIsComputedBeforeTheDeletion() throws {
        let store = try Self.store()
        let doomed = try store.importPGN(text: Self.pgnText())
        _ = try store.importPGN(text: Self.pgnText(black: "Carlsen, Magnus", round: 2))

        let stranded = PGNStore.playersOrphaned(byDeleting: [doomed])

        // Both games still exist. Bera is in the survivor, Lorenzo is not.
        #expect(stranded.map(\.normalizedName) == [Self.key(forTag: "Reinaud, Lorenzo")])
    }

    // MARK: Invariants the retag must not break

    /// The resolver stays the single creation door: a retag creates its target
    /// player through `resolvePlayers`, never by constructing a row itself.
    @Test("Retagging to a brand-new name creates exactly one player for it")
    func retagCreatesTargetThroughTheResolver() throws {
        let store = try Self.store()
        _ = try store.importPGN(text: Self.pgnText())
        _ = try store.importPGN(text: Self.pgnText(round: 2))
        let bera = try Self.player(store, named: "Senol, Bera")

        try store.retag(bera, to: "Şenol, Bera")

        let created = try #require(
            try store.player(withNormalizedKey: Self.key(forTag: "Bera Şenol"))
        )
        #expect(created.whiteGames.count == 2)
    }

    /// A renamed game's export re-imports and dedupes against itself — the
    /// milestone's gate sentence, and the reason the rehash rides the rewrite
    /// rather than waiting for a later `refreshHash`.
    @Test("A renamed game's export dedupes against itself")
    func renamedGameExportRoundTrips() throws {
        let store = try Self.store()
        let game = try store.importPGN(text: Self.pgnText())
        try store.retag(try Self.player(store, named: "Senol, Bera"), to: "Şenol, Bera")

        // The import door *throws* on a duplicate rather than handing back the
        // existing row, so "dedupes" is asserted as a refusal — and against
        // the identifier, not merely the fact of a throw, because a refusal
        // naming some other game would pass a bare `#expect(throws:)` while
        // meaning the opposite.
        do {
            _ = try store.importPGN(text: game.pgnText)
            Issue.record("Expected the re-import to be refused as a duplicate")
        } catch let error as PGNStore.Error {
            guard case .duplicate(let existingID, _) = error else {
                Issue.record("Expected .duplicate, got \(error)")
                return
            }
            #expect(existingID == game.persistentModelID)
        }
    }
}
