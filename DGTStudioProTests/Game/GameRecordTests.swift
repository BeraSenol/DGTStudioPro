//
//  GameRecordTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// The chronology contract (nonisolated — pure values): `effectiveDate`
/// falls back to `importedAt`, and `chronologicalOrder` runs the full
/// deterministic chain (effective date → importedAt → contentHash). Every
/// fold's determinism rests on this being total.
@Suite("Game Record — Chronology")
struct GameRecordChronologyTests {

    private func record(
        date: Date? = nil,
        importedAt: Date = Date(timeIntervalSince1970: 1_000),
        contentHash: String = "hash"
    ) -> GameRecord {
        GameRecord(
            white: .init(key: "a", name: "A"), black: .init(key: "b", name: "B"),
            result: .whiteWins, endedInMate: false,
            date: date, importedAt: importedAt, contentHash: contentHash
        )
    }

    @Test func effectiveDateFallsBackToImportedAt() {
        let dated = record(date: Date(timeIntervalSince1970: 500))
        let undated = record(importedAt: Date(timeIntervalSince1970: 2_000))

        #expect(dated.effectiveDate == Date(timeIntervalSince1970: 500))
        #expect(undated.effectiveDate == Date(timeIntervalSince1970: 2_000))
    }

    @Test func ordersByEffectiveDateFirst() {
        let earlier = record(date: Date(timeIntervalSince1970: 100))
        // Undated, but imported before the dated game's date — the
        // fallback puts it later anyway.
        let later = record(importedAt: Date(timeIntervalSince1970: 900))

        #expect(GameRecord.chronologicalOrder(earlier, later))
        #expect(!GameRecord.chronologicalOrder(later, earlier))
    }

    @Test func breaksTiesByImportedAtThenContentHash() {
        let sharedDate = Date(timeIntervalSince1970: 100)
        let first = record(date: sharedDate, importedAt: Date(timeIntervalSince1970: 10), contentHash: "zzz")
        let second = record(date: sharedDate, importedAt: Date(timeIntervalSince1970: 20), contentHash: "aaa")
        #expect(GameRecord.chronologicalOrder(first, second), "importedAt outranks the hash")

        let sharedImport = Date(timeIntervalSince1970: 10)
        let hashA = record(date: sharedDate, importedAt: sharedImport, contentHash: "aaa")
        let hashB = record(date: sharedDate, importedAt: sharedImport, contentHash: "bbb")
        #expect(GameRecord.chronologicalOrder(hashA, hashB))
        #expect(!GameRecord.chronologicalOrder(hashB, hashA))
    }
}

/// The projection seam (`@MainActor` — realizes `@Model`s through the
/// store): resolved links become `Side`s, `"?"` sides project nil, and
/// the mate flag keys off the last SAN's `#`.
@MainActor
@Suite("Game Record — Projection")
struct GameRecordProjectionTests {

    private static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: PGN.self, Player.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private static func pgnText(
        white: String = "Lopez, Ruy",
        black: String = "Nepo",
        movetext: String = "1. e4 e5 1-0",
        result: String = "1-0"
    ) -> String {
        """
        [Event "Test"]
        [Site "Test"]
        [Date "2026.05.15"]
        [Round "1"]
        [White "\(white)"]
        [Black "\(black)"]
        [Result "\(result)"]
        
        \(movetext)
        """
    }

    @Test func projectsResolvedSidesAndMateFlag() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let pgn = try store.importPGN(
            text: Self.pgnText(movetext: "1. f3 e5 2. g4 Qh4# 0-1", result: "0-1")
        )

        let record = pgn.gameRecord

        #expect(record.white == GameRecord.Side(key: "ruy lopez", name: "Ruy Lopez"))
        #expect(record.black == GameRecord.Side(key: "nepo", name: "Nepo"))
        #expect(record.result == .blackWins)
        #expect(record.endedInMate)
        #expect(record.contentHash == pgn.contentHash)
        #expect(record.importedAt == pgn.importedAt)
    }

    /// The M-prs.5 growth: the Library-metadata fields `TagRule` reads
    /// arrive through the projection.
    @Test func projectsLibraryMetadataFields() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let pgn = try store.importPGN(text: """
                [Event "Winter Open"]
                [Site "Club"]
                [Date "2026.05.15"]
                [Round "3"]
                [White "Alice"]
                [Black "Bob"]
                [Result "1-0"]
                [TimeControl "300+3"]
                
                1. e4 e5 1-0
                """)
        pgn.evaluations = [nil, nil]

        let record = pgn.gameRecord

        #expect(record.event == "Winter Open")
        #expect(record.site == "Club")
        #expect(record.name == pgn.name)
        #expect(record.round == 3)
        #expect(record.plyCount == 2)
        #expect(record.isTimed)
        #expect(record.hasAnalysis, "a non-empty evaluations array means a pass ran")
    }

    @Test func placeholderSideProjectsNil() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let pgn = try store.importPGN(text: Self.pgnText(white: "?"))

        let record = pgn.gameRecord

        #expect(record.white == nil)
        #expect(record.black?.key == "nepo")
        #expect(!record.endedInMate)
    }

    /// A row inserted around the store — pre-backfill shape — projects
    /// linkless rather than inventing identity from raw tags.
    @Test func unlinkedRowProjectsNoSides() throws {
        let context = try Self.makeContext()
        let orphan = PGN(white: "Giri, Anish", black: "Caruana, Fabiano", contentHash: "pre")
        context.insert(orphan)
        try context.save()

        let record = orphan.gameRecord

        #expect(record.white == nil)
        #expect(record.black == nil)
    }
}
