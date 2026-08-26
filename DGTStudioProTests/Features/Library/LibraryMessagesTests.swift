import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// Pins the Library's alert grammars (M18 Phase 1 - the audit's first unreferenced file).
/// These strings are user-facing contracts shared across surfaces; the suite asserts the exact
/// copy, singular/plural arms included, so a reworded clause is a deliberate edit here rather
/// than a drift there. `@MainActor` because `deletion(for:lead:)` asks the store's main-actor
/// orphan pre-flight.
@MainActor
@Suite("Library Messages")
struct LibraryMessagesTests {

    // MARK: Helpers

    private static func makeStore() throws -> PGNStore {
        let container = try ModelContainer(
            for: PGN.self, Player.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return PGNStore(modelContext: ModelContext(container))
    }

    /// Minimal valid PGN; seats and round vary hash and links per test.
    private static func samplePGN(white: String, black: String, round: Int) -> String {
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

    // MARK: Deletion

    /// Both seats appear in a surviving game, so the cascade takes nobody and the
    /// confirmation is the lead alone - no clause, no trailing space.
    @Test func deletionWithNoOrphansIsTheLeadAlone() throws {
        let store = try Self.makeStore()
        let doomed = try store.importPGN(text: Self.samplePGN(white: "Alice", black: "Bob", round: 1))
        _ = try store.importPGN(text: Self.samplePGN(white: "Alice", black: "Bob", round: 2))

        #expect(LibraryMessages.deletion(for: [doomed], lead: "Delete?") == "Delete?")
    }

    /// One seat survives elsewhere, one does not: the singular clause, named.
    @Test func deletionNamesASingleOrphanInTheSingular() throws {
        let store = try Self.makeStore()
        let doomed = try store.importPGN(text: Self.samplePGN(white: "Alice", black: "Bob", round: 1))
        _ = try store.importPGN(text: Self.samplePGN(white: "Alice", black: "Carol", round: 2))

        #expect(
            LibraryMessages.deletion(for: [doomed], lead: "Delete?")
                == "Delete? Bob is in no other game and will be removed from Players."
        )
    }

    /// Both orphaned: the plural clause, names in the pre-flight's sorted order.
    @Test func deletionListsTwoOrphansInThePlural() throws {
        let store = try Self.makeStore()
        let doomed = try store.importPGN(text: Self.samplePGN(white: "Bob", black: "Alice", round: 1))

        #expect(
            LibraryMessages.deletion(for: [doomed], lead: "Delete?")
                == "Delete? Alice, Bob are in no other games and will be removed from Players."
        )
    }

    /// Six orphans across a three-game batch: five shown, the sixth folded into
    /// "And 1 more." - the truncation arm nothing else renders.
    @Test func deletionTruncatesPastFiveOrphans() throws {
        let store = try Self.makeStore()
        let games = [
            try store.importPGN(text: Self.samplePGN(white: "Ann", black: "Ben", round: 1)),
            try store.importPGN(text: Self.samplePGN(white: "Cat", black: "Dan", round: 2)),
            try store.importPGN(text: Self.samplePGN(white: "Eve", black: "Fay", round: 3))
        ]

        #expect(
            LibraryMessages.deletion(for: games, lead: "Delete 3 Games?")
                == "Delete 3 Games? Ann, Ben, Cat, Dan, Eve are in no other games "
                + "and will be removed from Players. And 1 more."
        )
    }

    // MARK: Backfill - the empty and matched-none leads

    @Test func backfillWithNothingScannedNamesTheEmptyFolder() {
        #expect(
            LibraryMessages.backfill(for: .init())
                == "That folder has no PGN files in it."
        )
    }

    /// Scanned plenty, matched nothing: the wrong-folder guidance, with the plural count.
    @Test func backfillMatchingNoneSuggestsTheWrongFolder() {
        let report = PGNStore.LibraryIndexBackfill(unmatched: ["a.pgn", "b.pgn"])
        #expect(
            LibraryMessages.backfill(for: report)
                == "Scanned 2 files and matched none of them to games in your Library. "
                + "If these are your games, check that you picked the folder they were "
                + "imported from."
        )
    }

    /// The same lead in the singular - "1 file", not "1 files".
    @Test func backfillMatchingNoneReadsSingularForOneFile() {
        let report = PGNStore.LibraryIndexBackfill(unnumbered: ["stray.pgn"])
        #expect(
            LibraryMessages.backfill(for: report)
                == "Scanned 1 file and matched none of them to games in your Library. "
                + "If these are your games, check that you picked the folder they were "
                + "imported from."
        )
    }

    // MARK: Backfill - the composed report

    /// Every clause at once, each in its plural arm, joined by single spaces in
    /// declaration order - the full composition pinned once.
    @Test func backfillComposesEveryClauseInOrder() {
        let report = PGNStore.LibraryIndexBackfill(
            stamped: 2,
            alreadyNumbered: 3,
            unmatched: ["a.pgn", "b.pgn", "c.pgn", "d.pgn", "e.pgn"],
            unnumbered: ["x.pgn", "y.pgn"],
            skipped: ["bad.pgn"]
        )
        #expect(
            LibraryMessages.backfill(for: report)
                == "Numbered 2 games. 3 already had a number and were left alone. "
                + "5 files are not in your Library yet (a.pgn, b.pgn, c.pgn and 2 more). "
                + "2 filenames carry no number. 1 couldn’t be read."
        )
    }

    /// The singular arms: one game numbered, one unmatched file ("is", no truncation),
    /// one filename ("carries").
    @Test func backfillReadsTheSingularArms() {
        let report = PGNStore.LibraryIndexBackfill(
            stamped: 1,
            unmatched: ["only.pgn"],
            unnumbered: ["plain.pgn"]
        )
        #expect(
            LibraryMessages.backfill(for: report)
                == "Numbered 1 game. 1 file is not in your Library yet (only.pgn). "
                + "1 filename carries no number."
        )
    }

    /// Exactly three unmatched: all named, no "and 0 more" - the truncation boundary.
    @Test func backfillNamesExactlyThreeUnmatchedWithoutTruncating() {
        let report = PGNStore.LibraryIndexBackfill(
            stamped: 1,
            unmatched: ["a.pgn", "b.pgn", "c.pgn"]
        )
        #expect(
            LibraryMessages.backfill(for: report)
                == "Numbered 1 game. 3 files are not in your Library yet (a.pgn, b.pgn, c.pgn)."
        )
    }
}
