import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// The second door of one-hash/two-doors (M5): a hash match on archive is *success* — the
/// opposite of import.
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

    /// An importable game that is not the archive fixture — all seven tags (`importPGN` throws on
    /// missing ones), distinct moves so it can never dedupe against the archived game.
    private static func importableText() -> String {
        """
        [Event "Elsewhere"]
        [Site "Elsewhere"]
        [Date "2026.05.15"]
        [Round "1"]
        [White "Carlsen"]
        [Black "Nepo"]
        [Result "*"]

        1. d4 d5 *
        """
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

    // MARK: Board Tag (M2)

    /// The archive door threads `Roster.board` to `PGN.board` — and because
    /// the tag sits outside the content hash (equipment, not game),
    /// a boarded game still dedupes against its board-less twin, which is
    /// exactly the pre-M2 archive it might meet in the Library.
    @Test func archiveThreadsBoardIdentityOutsideTheHash() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)

        var roster = Self.roster()
        roster.board = "DGT 3000448278"
        let boarded = LiveGame(roster: roster)
        boarded.commit(try boarded.currentState.parseSAN("e4"))
        boarded.resign(.white)

        let first = try store.archive(boarded)
        #expect(first.pgn.board == "DGT 3000448278")

        // Same game, no board — the crash-resume / pre-M2 shape.
        let second = try store.archive(Self.finishedGame())
        #expect(second.deduplicated == true)
        #expect(try Self.libraryCount(in: context) == 1)
    }

    // MARK: No `*` ever archives
    
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

    // MARK: The Ordinal

    /// The pin the 7 Aug fix exists for: nil from `highestLibraryIndex()` means "the run starts
    /// here", and the old `flatMap` spelling read it as "no ordinal".
    @Test func theFirstGameArchivedIntoAnEmptyLibraryIsNumberOne() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)

        let result = try store.archive(Self.finishedGame())

        #expect(result.pgn.libraryIndex == 1)
    }

    /// One step further out, and the arm that actually bit: games present, none numbered — still an
    /// empty run.
    @Test func aLibraryOfUnnumberedGamesStillStartsItsRunAtOne() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let existing = try store.importPGN(text: Self.importableText())
        #expect(existing.libraryIndex == nil, "precondition: the row carries no ordinal")

        let result = try store.archive(Self.finishedGame())

        #expect(result.pgn.libraryIndex == 1)
    }

    /// `max + 1` once a run exists — and deliberately `max`, not `count`. A
    /// folder's numbering is neither gapless nor dense, so a Library
    /// holding one game at 47 continues at 48 rather than at 2.
    @Test func anArchivedGameContinuesTheHighestRun() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let existing = try store.importPGN(text: Self.importableText())
        existing.libraryIndex = 47

        let result = try store.archive(Self.finishedGame())

        #expect(result.pgn.libraryIndex == 48)
    }

    /// A deduplicated archive keeps the existing row's ordinal — the new one is computed before the
    /// hash probe and must be discarded with the fresh row.
    @Test func aDeduplicatedArchiveKeepsTheExistingOrdinal() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)

        let first = try store.archive(Self.finishedGame())
        first.pgn.libraryIndex = 12

        let second = try store.archive(Self.finishedGame())

        #expect(second.deduplicated == true)
        #expect(second.pgn.libraryIndex == 12)
    }
}
