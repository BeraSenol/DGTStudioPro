//
//  PGNStoreArchiveTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/07/2026.
//

import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// Locks in the second door of the one-hash/two-doors invariant (M5):
/// `archive(_:)` shares `contentHash` with import, so a finished live game
/// that already exists in the Library — imported earlier, or archived twice
/// by the resume self-heal — *deduplicates as success* instead of throwing
/// (the opposite of import, where a hash match is an error). `refreshHash`
/// is the third leg: an in-place edit that skipped it would leave a stale
/// hash and let future deduplication silently rot.
///
/// `@MainActor`: `LiveGame` is a `@MainActor` class and `archive(_:)` is
/// `@MainActor` for the same reason.
@MainActor
@Suite("PGN Store — Archive Door")
struct PGNStoreArchiveTests {
    
    // MARK: Helpers
    
    private static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: PGN.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }
    
    /// A pinned date so hash comparisons never straddle a midnight rollover.
    private static let fixedDate = Date(timeIntervalSince1970: 1_780_000_000)
    
    private static func roster() -> LiveGame.Roster {
        .init(
            event: "Club Night",
            site: "Home",
            date: fixedDate,
            round: 3,
            white: "Alice",
            black: "Bob"
        )
    }
    
    /// A decided one-ply game: 1.e4 then White resigns (0–1).
    private static func finishedGame() throws -> LiveGame {
        let game = LiveGame(roster: roster())
        game.commit(try game.currentState.parseSAN("e4"))
        game.resign(.white)
        return game
    }
    
    private static func libraryCount(in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<PGN>())
    }
    
    // MARK: Insert
    
    @Test func archiveInsertsAFinishedGame() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        
        let result = try store.archive(Self.finishedGame())
        
        #expect(result.deduplicated == false)
        #expect(result.pgn.white == "Alice")
        #expect(result.pgn.black == "Bob")
        #expect(result.pgn.event == "Club Night")
        #expect(result.pgn.round == 3)
        #expect(result.pgn.moves == ["e4"])
        #expect(result.pgn.result == .blackWins)
        // The hash must be *stored*, not just computed — same regression
        // the import suite pins (an empty hash kills deduplication).
        #expect(result.pgn.contentHash.count == 32)
        #expect(try Self.libraryCount(in: context) == 1)
    }
    
    // MARK: Decision #3 — no `*` ever archives
    
    @Test func archiveRefusesAnOngoingGame() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let ongoing = LiveGame(roster: Self.roster())
        
        do {
            _ = try store.archive(ongoing)
            Issue.record("Expected .ongoingGame; archive succeeded")
        } catch PGNStore.Error.ongoingGame {
            // Expected.
        } catch {
            Issue.record("Expected .ongoingGame, got \(error)")
        }
        #expect(try Self.libraryCount(in: context) == 0)
    }
    
    // MARK: Deduplication — the success kind
    
    @Test func archivingTwiceDeduplicatesAsSuccess() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        
        let first = try store.archive(Self.finishedGame())
        let second = try store.archive(Self.finishedGame())
        
        #expect(second.deduplicated == true)
        #expect(second.pgn.persistentModelID == first.pgn.persistentModelID)
        #expect(try Self.libraryCount(in: context) == 1)
    }
    
    /// The two doors share one hash: a game *imported* as text and the same
    /// game *archived* from live play land on the same row.
    @Test func archiveDeduplicatesAgainstAnImportedTwin() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        
        // The imported twin, dated with the same pinned day the live
        // roster uses (the hash formats dates as yyyy.MM.dd in UTC).
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateTag = formatter.string(from: Self.fixedDate)
        
        let imported = try store.importPGN(text: """
        [Event "Club Night"]
        [Site "Home"]
        [Date "\(dateTag)"]
        [Round "3"]
        [White "Alice"]
        [Black "Bob"]
        [Result "0-1"]
        
        1. e4 0-1
        """)
        
        let archived = try store.archive(Self.finishedGame())
        
        #expect(archived.deduplicated == true)
        #expect(archived.pgn.persistentModelID == imported.persistentModelID)
        #expect(try Self.libraryCount(in: context) == 1)
    }
    
    // MARK: refreshHash
    
    /// An in-place edit changes the hash inputs; `refreshHash` keeps the
    /// stored hash honest so the dedup doors keep working afterwards.
    @Test func refreshHashTracksInPlaceEdits() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        
        let result = try store.archive(Self.finishedGame())
        let originalHash = result.pgn.contentHash
        
        result.pgn.white = "Carol"
        try store.refreshHash(of: result.pgn)
        
        #expect(result.pgn.contentHash != originalHash)
        #expect(result.pgn.contentHash.count == 32)
        
        // The door still works against the *edited* identity: archiving a
        // live twin of the edited game deduplicates onto the same row.
        var editedRoster = Self.roster()
        editedRoster.white = "Carol"
        let twin = LiveGame(roster: editedRoster)
        twin.commit(try twin.currentState.parseSAN("e4"))
        twin.resign(.white)
        
        let rearchived = try store.archive(twin)
        #expect(rearchived.deduplicated == true)
        #expect(rearchived.pgn.persistentModelID == result.pgn.persistentModelID)
        #expect(try Self.libraryCount(in: context) == 1)
    }
}
