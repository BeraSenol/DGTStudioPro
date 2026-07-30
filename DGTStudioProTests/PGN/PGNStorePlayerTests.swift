//
//  PGNStorePlayerTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// Locks in the player-resolution contract (M-prs.1): `Player` rows are
/// created by exactly one door (`resolvePlayer(named:)`), identity is the
/// case-insensitive, whitespace-folded *display* form (so "Lopez, Ruy",
/// "Ruy Lopez", and "ruy  lopez" are one player), `"?"`/empty tags resolve
/// to no player, both store doors link on insert, the backfill heals
/// pre-schema rows idempotently, and `applyEdit` re-resolves — the
/// relationship sibling of the one-hash rule. Also pins two deliberate
/// non-behaviors: first-seen casing wins, and orphaned players are not
/// garbage-collected.
///
/// `@MainActor`: fronts `PGNStore` and realized `@Model`s, same as the
/// other store suites.
@MainActor
@Suite("PGN Store — Player Resolution")
struct PGNStorePlayerTests {
    
    // MARK: Helpers
    
    private static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: PGN.self, Player.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }
    
    /// Minimal valid PGN; `round` varies the content hash so multiple
    /// imports of the same pairing don't trip deduplication.
    private static func samplePGN(
        white: String = "Carlsen, Magnus",
        black: String = "Nepo",
        round: Int = 1
    ) -> String {
        """
        [Event "Test"]
        [Site "Test"]
        [Date "2026.05.15"]
        [Round "\(round)"]
        [White "\(white)"]
        [Black "\(black)"]
        [Result "1-0"]
        
        1. e4 e5 1-0
        """
    }
    
    /// A decided one-ply game — the `PGNStoreArchiveTests` fixture shape.
    private static func finishedGame() throws -> LiveGame {
        let game = LiveGame(
            roster: .init(
                event: "Club Night",
                site: "Home",
                date: Date(timeIntervalSince1970: 1_780_000_000),
                round: 3,
                white: "Alice",
                black: "Bob"
            )
        )
        game.commit(try game.currentState.parseSAN("e4"))
        game.resign(.white)
        return game
    }
    
    private static func playerCount(in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<Player>())
    }
    
    // MARK: Resolver Identity
    
    @Test func resolveCreatesPlayerInDisplayFormWithNormalizedKey() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        
        let player = try store.resolvePlayer(named: "Lopez, Ruy")
        
        #expect(player?.name == "Ruy Lopez")
        #expect(player?.normalizedName == "ruy lopez")
        #expect(try Self.playerCount(in: context) == 1)
    }
    
    /// The identity fold: raw-tag form, casing, and interior whitespace
    /// all collapse to one player.
    @Test func resolveReusesAcrossTagFormCasingAndWhitespace() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        
        let first = try store.resolvePlayer(named: "Lopez, Ruy")
        let variants = ["Ruy Lopez", "ruy lopez", "  Ruy   Lopez  ", "LOPEZ,   RUY"]
        for variant in variants {
            let resolved = try store.resolvePlayer(named: variant)
            #expect(
                resolved?.persistentModelID == first?.persistentModelID,
                "'\(variant)' resolved to a different player"
            )
        }
        #expect(try Self.playerCount(in: context) == 1)
    }
    
    /// First-seen casing wins — a later, differently cased sighting reuses
    /// the row without rewriting its display name.
    @Test func firstSeenCasingIsPreserved() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        
        let first = try store.resolvePlayer(named: "ruy lopez")
        let second = try store.resolvePlayer(named: "Ruy Lopez")
        
        #expect(second?.persistentModelID == first?.persistentModelID)
        #expect(second?.name == "ruy lopez")
    }
    
    // MARK: Tag Form (D29′)

    /// The resolver remembers the first-seen tag form — whitespace-folded,
    /// comma structure and casing verbatim — beside the display form.
    @Test func resolveStampsFirstSeenTagName() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)

        let player = try store.resolvePlayer(named: "Lopez,   Ruy")

        #expect(player?.name == "Ruy Lopez")
        #expect(player?.tagName == "Lopez, Ruy")
    }

    /// First-seen wins, `name`-casing style: a later sighting in a
    /// different raw form reuses the row without rewriting its tag form —
    /// even when the later form is the "better" comma form.
    @Test func laterSightingDoesNotRewriteTagName() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)

        let first = try store.resolvePlayer(named: "Ruy Lopez")
        let second = try store.resolvePlayer(named: "Lopez, Ruy")

        #expect(second?.persistentModelID == first?.persistentModelID)
        #expect(second?.tagName == "Ruy Lopez")
    }

    /// Pre-schema rows heal from their earliest linked game's seat tag;
    /// the pass is idempotent and a second run reports no work.
    @Test func backfillStampsTagNamesFromEarliestGameIdempotently() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let later = try store.importPGN(text: Self.samplePGN(white: "CARLSEN, MAGNUS", round: 2))
        let earlier = try store.importPGN(text: Self.samplePGN(white: "Carlsen, Magnus", round: 1))
        earlier.date = Date(timeIntervalSince1970: 1_000)
        later.date = Date(timeIntervalSince1970: 2_000)
        let white = try #require(earlier.whitePlayer)
        white.tagName = nil   // simulate a row that predates the field
        try context.save()

        #expect(try store.backfillPlayerTagNames() == 1)
        #expect(white.tagName == "Carlsen, Magnus", "earliest game's tag should win")
        #expect(try store.backfillPlayerTagNames() == 0)
    }

    /// A linkless row (a future deletion's orphan) stays nil and never
    /// re-reports as work — readers fall back to `name`.
    @Test func backfillSkipsLinklessPlayers() throws {
        let context = try Self.makeContext()
        let orphan = Player(name: "Nobody Linked")
        context.insert(orphan)
        try context.save()
        let store = PGNStore(modelContext: context)

        #expect(try store.backfillPlayerTagNames() == 0)
        #expect(orphan.tagName == nil)
    }

    /// A placeholder is the absence of a player, never a player named "?".
    @Test func placeholderAndEmptyTagsResolveToNoPlayer() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        
        for tag in ["?", "", "   ", ","] {
            #expect(try store.resolvePlayer(named: tag) == nil, "'\(tag)' produced a player")
        }
        #expect(try Self.playerCount(in: context) == 0)
    }
    
    // MARK: The Two Doors
    
    @Test func importLinksBothPlayers() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        
        let imported = try store.importPGN(text: Self.samplePGN())
        
        #expect(imported.whitePlayer?.name == "Magnus Carlsen")
        #expect(imported.blackPlayer?.name == "Nepo")
        #expect(try Self.playerCount(in: context) == 2)
    }
    
    @Test func importSharesPlayersAcrossGames() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        
        let first = try store.importPGN(text: Self.samplePGN(round: 1))
        let second = try store.importPGN(text: Self.samplePGN(round: 2))
        
        #expect(second.whitePlayer?.persistentModelID == first.whitePlayer?.persistentModelID)
        #expect(try Self.playerCount(in: context) == 2)
    }
    
    @Test func archiveLinksBothPlayers() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        
        let result = try store.archive(Self.finishedGame())
        
        #expect(result.pgn.whitePlayer?.name == "Alice")
        #expect(result.pgn.blackPlayer?.name == "Bob")
        #expect(try Self.playerCount(in: context) == 2)
    }
    
    // MARK: Backfill
    
    @Test func backfillLinksPreexistingRowsIdempotently() throws {
        let context = try Self.makeContext()
        // Inserted around the store — the pre-M-prs.1 row shape.
        let orphan = PGN(white: "Giri, Anish", black: "Caruana, Fabiano", contentHash: "pre-schema")
        context.insert(orphan)
        try context.save()
        let store = PGNStore(modelContext: context)
        
        let firstPass = try store.backfillPlayerLinks()
        
        #expect(firstPass == 1)
        #expect(orphan.whitePlayer?.name == "Anish Giri")
        #expect(orphan.blackPlayer?.name == "Fabiano Caruana")
        
        let secondPass = try store.backfillPlayerLinks()
        #expect(secondPass == 0)
        #expect(try Self.playerCount(in: context) == 2)
    }
    
    /// A `"?"` side stays nil forever and never re-reports as work.
    @Test func backfillSkipsPlaceholderSides() throws {
        let context = try Self.makeContext()
        let orphan = PGN(white: "?", black: "Nepo", contentHash: "half-placeholder")
        context.insert(orphan)
        try context.save()
        let store = PGNStore(modelContext: context)
        
        #expect(try store.backfillPlayerLinks() == 1)
        #expect(orphan.whitePlayer == nil)
        #expect(orphan.blackPlayer?.name == "Nepo")
        #expect(try store.backfillPlayerLinks() == 0)
    }
    
    // MARK: Edit Re-Resolution
    
    /// The relationship sibling of the one-hash rule: editing a tag through
    /// the funnel relinks. The displaced player deliberately survives
    /// unreferenced — no GC in the POC.
    @Test func applyEditRelinksAndKeepsOrphanedPlayer() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let imported = try store.importPGN(text: Self.samplePGN())
        
        try store.applyEdit(to: imported) { $0.white = "Firouzja, Alireza" }
        
        #expect(imported.whitePlayer?.name == "Alireza Firouzja")
        #expect(imported.blackPlayer?.name == "Nepo")
        #expect(try Self.playerCount(in: context) == 3, "Magnus Carlsen should linger unreferenced")
    }
    
    // MARK: Relationship Semantics
    
    /// Deleting a game updates the player's inverse and never cascades
    /// into the registry.
    @Test func deletingGameEmptiesInverseWithoutDeletingPlayer() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let imported = try store.importPGN(text: Self.samplePGN())
        let white = try #require(imported.whitePlayer)
        
        try store.delete(imported)
        
        #expect(white.whiteGames.isEmpty)
        #expect(try Self.playerCount(in: context) == 2)
    }
    
    // MARK: Read-Only Lookup (M-prs.6)
    
    /// The M-prs.6 bridge is read-only by contract: it finds the row the
    /// resolver created, keyed exactly like the resolver keys it, and a
    /// miss creates nothing — the single door (D9′) is about creation,
    /// and the lookup must never become a second one by accident.
    @Test func playerLookupByKeyFindsWithoutCreating() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let resolved = try store.resolvePlayer(named: "Lopez, Ruy")
        try context.save()
        
        let found = try store.player(
            withNormalizedKey: Player.normalizedKey(for: "Ruy Lopez")
        )
        
        #expect(found?.persistentModelID == resolved?.persistentModelID)
        #expect(try context.fetch(FetchDescriptor<Player>()).count == 1)
    }
    
    @Test func playerLookupByKeyMissesCleanly() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        
        #expect(try store.player(withNormalizedKey: "nobody here") == nil)
        #expect(try context.fetch(FetchDescriptor<Player>()).isEmpty)
    }
}
