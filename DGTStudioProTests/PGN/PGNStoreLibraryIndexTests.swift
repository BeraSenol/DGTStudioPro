import Testing
import SwiftData
@testable import DGTStudioPro
import Foundation

/// D58′'s folder backfill — driven through a real *directory*, matched by content hash.
@Suite("PGN Store — Library Index Backfill")
@MainActor
struct PGNStoreLibraryIndexTests {

    // MARK: Helpers

    private static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: PGN.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private static func pgnText(white: String = "Carlsen", moves: String = "1. e4 e5 *") -> String {
        """
        [Event "Test"]
        [Site "Test"]
        [Date "2026.05.15"]
        [Round "1"]
        [White "\(white)"]
        [Black "Nepo"]
        [Result "*"]

        \(moves)
        """
    }

    /// A scratch directory the caller owns and the helper cleans up.
    private static func withTemporaryFolder(
        _ files: [String: String],
        _ body: (URL) throws -> Void
    ) throws {
        let folder = URL.temporaryDirectory.appending(path: "backfill-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        for (name, text) in files {
            try Data(text.utf8).write(to: folder.appending(path: name))
        }
        try body(folder)
    }

    // MARK: The Job

    /// The case the door exists for: a game imported as text carries no
    /// ordinal (D58′), and the folder scan gives it the one its file names.
    @Test func aFileStampsTheRowItHashesTo() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)

        let game = try store.importPGN(text: Self.pgnText())
        #expect(game.libraryIndex == nil, "text import must not invent an ordinal")

        try Self.withTemporaryFolder(["47. Carlsen vs Nepo.pgn": Self.pgnText()]) { folder in
            let report = try store.backfillLibraryIndices(from: folder)

            #expect(report.stamped == 1)
            #expect(game.libraryIndex == 47)
        }
    }

    /// **Matching is by hash, not filename** — the file is named with a player not in the game and
    /// still matches. Not contrived: the folder writes full names, the serializer given names.
    @Test func matchingIgnoresTheNameInTheFilename() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let game = try store.importPGN(text: Self.pgnText())

        try Self.withTemporaryFolder(["12. Somebody Else vs Nobody.pgn": Self.pgnText()]) { folder in
            _ = try store.backfillLibraryIndices(from: folder)
            #expect(game.libraryIndex == 12)
        }
    }

    // MARK: What It Refuses To Do

    /// **An existing ordinal is never overwritten.** A scan that renumbers from
    /// a stale or partial folder would be silent and total, so this is the
    /// guard worth pinning hardest.
    @Test func anExistingOrdinalIsLeftAlone() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)

        let game = try store.importPGN(text: Self.pgnText())
        game.libraryIndex = 3

        try Self.withTemporaryFolder(["99. Carlsen vs Nepo.pgn": Self.pgnText()]) { folder in
            let report = try store.backfillLibraryIndices(from: folder)

            #expect(game.libraryIndex == 3, "the folder must not renumber a game that has a number")
            #expect(report.stamped == 0)
            #expect(report.alreadyNumbered == 1)
        }
    }

    /// A file the Library does not hold is a **finding, not an error** — it
    /// means a game has not been imported. The scan reports it and carries on.
    @Test func anUnmatchedFileIsReportedRatherThanThrown() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        _ = try store.importPGN(text: Self.pgnText())

        let stranger = Self.pgnText(white: "Firouzja", moves: "1. d4 d5 *")
        try Self.withTemporaryFolder(["8. Firouzja vs Nepo.pgn": stranger]) { folder in
            let report = try store.backfillLibraryIndices(from: folder)

            #expect(report.stamped == 0)
            #expect(report.unmatched == ["8. Firouzja vs Nepo.pgn"])
        }
    }

    /// D58′'s guard, one layer up: digits with no period are a year in a title,
    /// not an ordinal. Such a file is skipped *before* it is parsed, so this
    /// also pins the ordering choice — the game is a real Library game, and it
    /// still comes back unnumbered.
    @Test func aFilenameWithNoOrdinalIsSkippedNotGuessedAt() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let game = try store.importPGN(text: Self.pgnText())

        try Self.withTemporaryFolder(["1961 Candidates.pgn": Self.pgnText()]) { folder in
            let report = try store.backfillLibraryIndices(from: folder)

            #expect(game.libraryIndex == nil)
            #expect(report.unnumbered == ["1961 Candidates.pgn"])
            #expect(report.stamped == 0)
        }
    }

    /// One bad file must not cost the other forty. The unreadable one is
    /// reported under `skipped` — kept separate from `unmatched` because the
    /// remedies differ: a broken file versus a missing game.
    @Test func oneUnparseableFileDoesNotAbortTheScan() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let game = try store.importPGN(text: Self.pgnText())

        try Self.withTemporaryFolder([
            "5. Broken.pgn": "this is not a PGN",
            "6. Carlsen vs Nepo.pgn": Self.pgnText()
        ]) { folder in
            let report = try store.backfillLibraryIndices(from: folder)

            #expect(game.libraryIndex == 6, "the good file must still land")
            #expect(report.skipped == ["5. Broken.pgn"])
        }
    }

    /// Non-`.pgn` files are not opened at all, so a folder holding an export
    /// log or a `.DS_Store` reports nothing about them.
    @Test func onlyPGNFilesAreScanned() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        _ = try store.importPGN(text: Self.pgnText())

        try Self.withTemporaryFolder([
            "notes.txt": "1. e4",
            "3. Carlsen vs Nepo.pgn": Self.pgnText()
        ]) { folder in
            let report = try store.backfillLibraryIndices(from: folder)
            #expect(report.scanned == 1, "only the .pgn file counts as scanned")
        }
    }

    // MARK: The Affordance's Own Question

    /// `hasUnnumberedGames` is what decides whether the toolbar button exists,
    /// so it needs to be producible **both ways** — the D40′ check, run at
    /// minting rather than at the next sweep.
    @Test func hasUnnumberedGamesAnswersBothWays() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)

        #expect(try !store.hasUnnumberedGames(), "an empty Library has nothing to backfill")

        let game = try store.importPGN(text: Self.pgnText())
        #expect(try store.hasUnnumberedGames())

        game.libraryIndex = 1
        #expect(try !store.hasUnnumberedGames())
    }

    /// A backfill retires its own affordance: after a successful scan the
    /// button's condition is false. Asserted through the same predicate the
    /// toolbar reads rather than through a count, so the two cannot disagree.
    @Test func aCompletedBackfillRetiresTheAffordance() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        _ = try store.importPGN(text: Self.pgnText())

        try Self.withTemporaryFolder(["21. Carlsen vs Nepo.pgn": Self.pgnText()]) { folder in
            _ = try store.backfillLibraryIndices(from: folder)
            #expect(try !store.hasUnnumberedGames())
        }
    }
}
