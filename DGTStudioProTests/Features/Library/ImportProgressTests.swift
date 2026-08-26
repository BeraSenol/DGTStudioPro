import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// Pins the import sheet's model half - the category partition, the counts the summary
/// renders, and the cancel arithmetic (M16). `@MainActor` for the sibling suites' reason:
/// the `.duplicate` case carries a `PersistentIdentifier`, which only an inserted model
/// can mint.
@MainActor
@Suite("Import Progress")
struct ImportProgressTests {

    // MARK: Helpers

    private static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: PGN.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// One inserted game, for a real id - the preview deliberately skips the `.duplicate`
    /// row on exactly this cost; the suite pays it once here.
    private static func insertedID(in context: ModelContext) -> PersistentIdentifier {
        let pgn = PGN(white: "Alice", black: "Bob", moves: ["e4"], name: "Fixture")
        context.insert(pgn)
        return pgn.persistentModelID
    }

    private static func imported(_ n: Int) -> [ImportResult] {
        (0..<n).map { ImportResult(fileName: "game-\($0).pgn", outcome: .imported(name: "Game \($0)")) }
    }

    private static func failed(_ n: Int) -> [ImportResult] {
        (0..<n).map { ImportResult(fileName: "bad-\($0).pgn", outcome: .failed(.malformedPGN(reason: "unbalanced braces"))) }
    }

    // MARK: Category Partition

    /// Three buckets, three distinct expectations - and the duplicate one is the pin that
    /// matters: a duplicate is a *failure case* by type and deliberately **not** a failure
    /// by category, the no-op the user asked for.
    @Test func categoriesPartitionTheThreeBuckets() throws {
        let context = try Self.makeContext()

        let imported = ImportResult.Outcome.imported(name: "A")
        let duplicate = ImportResult.Outcome.failed(
            .duplicate(existingID: Self.insertedID(in: context), existingName: "A")
        )
        let failed = ImportResult.Outcome.failed(.malformedPGN(reason: "truncated"))

        #expect(imported.category == .imported)
        #expect(duplicate.category == .duplicate)
        #expect(failed.category == .failed)
    }

    // MARK: Counts

    /// Three different numbers on purpose - identical inputs cannot catch a count reading
    /// its neighbour's category (the D81′ crossed-wiring lesson).
    @Test func countsCountTheirOwnCategory() throws {
        let context = try Self.makeContext()

        var results = Self.imported(3)
        results.append(ImportResult(
            fileName: "dupe.pgn",
            outcome: .failed(.duplicate(existingID: Self.insertedID(in: context), existingName: "A"))
        ))
        results.append(contentsOf: Self.failed(2))

        let progress = ImportProgress(total: 6, results: results)

        #expect(progress.importedCount == 3)
        #expect(progress.duplicateCount == 1)
        #expect(progress.failedCount == 2)
        #expect(progress.completed == 6)
    }

    // MARK: Cancel Arithmetic

    @Test func notImportedCountIsWhatTheBatchNeverReached() {
        let progress = ImportProgress(
            total: 12, results: Self.imported(2), isFinished: true, isCancelled: true
        )
        #expect(progress.notImportedCount == 10)
    }

    /// Zero by arithmetic on a drained batch - the property that lets the summary show the
    /// part unconditionally rather than gate it on the flag.
    @Test func aDrainedBatchHasNothingUnreached() {
        let progress = ImportProgress(
            total: 3, results: Self.imported(3), isFinished: true
        )
        #expect(progress.notImportedCount == 0)
        #expect(!progress.isCancelled)
    }

    /// The flags describe the batch's ending, never its contents: cancelling changes no count.
    @Test func cancellationLeavesTheCountsAlone() {
        let results = Self.imported(2) + Self.failed(1)
        let live = ImportProgress(total: 9, results: results)
        let cancelled = ImportProgress(total: 9, results: results, isFinished: true, isCancelled: true)

        #expect(live.importedCount == cancelled.importedCount)
        #expect(live.failedCount == cancelled.failedCount)
        #expect(live.notImportedCount == cancelled.notImportedCount)
        #expect(cancelled.notImportedCount == 6)
    }

    // MARK: Construction

    /// A fresh batch is live, uncancelled and empty - the sheet's first render depends on
    /// all three, and the memberwise defaults are API the loop relies on.
    @Test func constructionStartsLive() {
        let progress = ImportProgress(total: 5)
        #expect(!progress.isFinished)
        #expect(!progress.isCancelled)
        #expect(progress.completed == 0)
        #expect(progress.notImportedCount == 5)
    }
}
