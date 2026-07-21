//
//  LiveGameDraftStoreTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 05/07/2026.
//

import Foundation
import Testing
@testable import DGTStudioPro

/// Store tests (M4.1) against injected temp directories — the real
/// Application Support sidecar is never touched, and every test gets a
/// fresh, isolated directory.
///
/// The contract under test: `load()` answers "absent" (`nil`) and "corrupt"
/// (throws) *differently* — the session offers nothing for the first and a
/// delete-only alert for the second — and an unknown `schemaVersion` counts
/// as corrupt, never guessed at.
///
/// `LiveGameDraftStore` is `@MainActor`, so the suite is too.
@MainActor
@Suite("LiveGame Draft Store")
struct LiveGameDraftStoreTests {

    /// Whole seconds so encode → decode equality holds (ISO 8601 drops
    /// fractional seconds).
    private static let instant = Date(timeIntervalSince1970: 1_750_000_000)

    private func temporaryStore() -> LiveGameDraftStore {
        LiveGameDraftStore(
            directory: FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString)
        )
    }

    private func sampleDraft(
        white: String = "Wendy",
        schemaVersion: Int = LiveGameDraft.currentSchemaVersion
    ) -> LiveGameDraft {
        LiveGameDraft(
            schemaVersion: schemaVersion,
            startFEN: FEN(GameState.starting).string,
            ruleSet: .fide,
            event: "Club Night",
            site: "Home",
            date: nil,
            round: nil,
            white: white,
            black: "Blake",
            sanMoves: ["e4"],
            result: .ongoing,
            startedAt: Self.instant,
            updatedAt: Self.instant
        )
    }

    /// The common launch: no file, no draft, no error.
    @Test func loadWithNoFileReturnsNil() throws {
        #expect(try temporaryStore().load() == nil)
    }

    @Test func saveThenLoadRoundTrips() throws {
        let store = temporaryStore()
        let draft = sampleDraft()

        try store.save(draft)

        #expect(try store.load() == draft)
    }

    /// One draft, one file: a second save replaces the first outright.
    @Test func saveOverwritesThePreviousDraft() throws {
        let store = temporaryStore()

        try store.save(sampleDraft(white: "First"))
        try store.save(sampleDraft(white: "Second"))

        #expect(try store.load()?.white == "Second")
    }

    @Test func deleteRemovesTheFile() throws {
        let store = temporaryStore()
        try store.save(sampleDraft())
        #expect(FileManager.default.fileExists(atPath: store.fileURL.path))

        store.delete()

        #expect(!FileManager.default.fileExists(atPath: store.fileURL.path))
        #expect(try store.load() == nil)
    }

    /// Deleting when nothing exists is a quiet no-op — the session calls
    /// this without checking first.
    @Test func deleteWithNoFileIsANoOp() throws {
        let store = temporaryStore()

        store.delete()

        #expect(try store.load() == nil)
    }

    /// A file that isn't JSON at all is the "corrupt" answer: `load()`
    /// throws rather than returning `nil`, so the session can tell the user
    /// something was there.
    @Test func garbageFileThrows() throws {
        let store = temporaryStore()
        try FileManager.default.createDirectory(
            at: store.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: store.fileURL)

        #expect(throws: (any Error).self) {
            try store.load()
        }
    }

    /// A decodable file from an unknown schema is rejected with the
    /// dedicated error — versions are validated, never guessed at.
    @Test func unsupportedSchemaThrowsItsError() throws {
        let store = temporaryStore()
        try store.save(sampleDraft(schemaVersion: 999))

        #expect(throws: LiveGameDraftStore.StoreError.unsupportedSchema(found: 999)) {
            try store.load()
        }
    }
}
