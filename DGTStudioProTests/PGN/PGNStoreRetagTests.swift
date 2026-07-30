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

    // MARK: Merge — D38′

    @Test("Merge moves the loser's games and deletes the row")
    func mergeMovesGamesAndDeletesLoser() throws {
        let store = try Self.store()
        let canonical = try store.importPGN(text: Self.pgnText(black: "Reinaud, Lorenzo"))
        let variant = try store.importPGN(
            text: Self.pgnText(black: "L. Reinaud", round: 2)
        )
        let survivor = try Self.player(store, named: "Reinaud, Lorenzo")
        let loser = try Self.player(store, named: "L. Reinaud")

        let moved = try store.merge(loser, into: survivor)

        #expect(moved == 1)
        #expect(variant.black == "Reinaud, Lorenzo")
        #expect(variant.blackPlayer?.persistentModelID == survivor.persistentModelID)
        #expect(canonical.blackPlayer?.persistentModelID == survivor.persistentModelID)
        #expect(try store.player(withNormalizedKey: Self.key(forTag: "L. Reinaud")) == nil)
    }

    /// D38′'s reason for existing. Link surgery alone would be undone here:
    /// `applyEdit` re-resolves both seats from the tag strings unconditionally,
    /// so an untouched tag would resolve back to the merged-away player and
    /// mint it again. Because merge rewrote the tag, the edit is a no-op for
    /// identity.
    @Test("A merged game survives applyEdit's unconditional re-resolve")
    func mergeSurvivesApplyEdit() throws {
        let store = try Self.store()
        _ = try store.importPGN(text: Self.pgnText(black: "Reinaud, Lorenzo"))
        let variant = try store.importPGN(text: Self.pgnText(black: "L. Reinaud", round: 2))
        let survivor = try Self.player(store, named: "Reinaud, Lorenzo")
        let loser = try Self.player(store, named: "L. Reinaud")
        try store.merge(loser, into: survivor)

        // Any metadata edit re-resolves both seats.
        try store.applyEdit(to: variant) { $0.event = "Club Night II" }

        #expect(variant.blackPlayer?.persistentModelID == survivor.persistentModelID)
        #expect(try store.player(withNormalizedKey: Self.key(forTag: "L. Reinaud")) == nil)
    }

    @Test("Merging a player into itself is a no-op")
    func mergeIntoSelfIsNoOp() throws {
        let store = try Self.store()
        let game = try store.importPGN(text: Self.pgnText())
        let bera = try Self.player(store, named: "Senol, Bera")

        #expect(try store.merge(bera, into: bera) == 0)
        #expect(game.white == "Senol, Bera")
    }

    /// A merge inherits the retag door's refusal, since it *is* a retag —
    /// which is the whole point of D38′ putting them on one door.
    @Test("A merge that would collide is refused, like any other retag")
    func collidingMergeIsRefused() throws {
        let store = try Self.store()
        let first = try store.importPGN(text: Self.pgnText(black: "Reinaud, Lorenzo"))
        let second = try store.importPGN(text: Self.pgnText(black: "L. Reinaud"))
        let survivor = try Self.player(store, named: "Reinaud, Lorenzo")
        let loser = try Self.player(store, named: "L. Reinaud")

        #expect(throws: PGNStore.RetagRejection.self) {
            try store.merge(loser, into: survivor)
        }
        // Refused whole: the loser is still a player, still holding its game.
        #expect(second.black == "L. Reinaud")
        #expect(first.black == "Reinaud, Lorenzo")
        #expect(try store.player(withNormalizedKey: Self.key(forTag: "L. Reinaud")) != nil)
    }

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

    /// And the case the sweep exists for: the row D9′ says lingers once its
    /// last game is deleted — invisible in the Players destination, which folds
    /// records, and therefore reachable through nothing else.
    @Test("Deleting a player's last game lists them, and the sweep removes them")
    func orphanedPlayerIsListedAndSwept() throws {
        let (store, context) = try Self.storeAndContext()
        let game = try store.importPGN(text: Self.pgnText())
        try store.delete(game)

        let orphans = try Self.orphans(in: context)
        #expect(orphans.contains { $0.normalizedName == Self.key(forTag: "Senol, Bera") })
        #expect(try store.deleteOrphanedPlayers(orphans) == orphans.count)
        #expect(try store.player(withNormalizedKey: Self.key(forTag: "Senol, Bera")) == nil)
    }

    /// The snapshot guard. The sweep acts on a list built for a confirmation
    /// dialog, so between listing and deleting a row can pick up a link — here
    /// by importing a second game under the same tag, which resolves onto the
    /// existing orphan rather than minting a row. Deleting it then would
    /// nullify live links, so the re-check must skip it.
    @Test("A row that gained a link since it was listed is skipped")
    func sweepSkipsARowRelinkedSinceListing() throws {
        let (store, context) = try Self.storeAndContext()
        let game = try store.importPGN(text: Self.pgnText())
        try store.delete(game)
        let stale = try Self.orphans(in: context)
        #expect(!stale.isEmpty)

        _ = try store.importPGN(text: Self.pgnText(round: 2))

        #expect(try store.deleteOrphanedPlayers(stale) == 0)
        #expect(try store.player(withNormalizedKey: Self.key(forTag: "Senol, Bera")) != nil)
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
