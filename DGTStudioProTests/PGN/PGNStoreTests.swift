import Testing
import SwiftData
@testable import DGTStudioPro
import Foundation

/// Locks in the import → deduplicate → persist contract for `PGNStore`.
///
/// The dedup path is hash-driven: on import, the store computes a content
/// hash and looks up any existing PGN with the same hash. For lookups to
/// hit, the hash has to actually be *stored* on the inserted PGN — a
/// regression where the field was computed but never assigned (so all
/// rows landed with `contentHash == ""`) silently broke deduplication
/// across the whole library. These tests pin both halves of the contract:
/// the hash is non-empty on the stored model, and re-importing the same
/// movetext throws `.duplicate`.
@Suite("PGN Store — Import and Deduplication")
@MainActor
struct PGNStoreTests {
    
    // MARK: Helpers
    
    private static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: PGN.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }
    
    /// Minimal valid PGN; tags vary only via the white player so tests can
    /// produce distinct-but-otherwise-identical games.
    private static func samplePGN(white: String = "Carlsen") -> String {
        """
        [Event "Test"]
        [Site "Test"]
        [Date "2026.05.15"]
        [Round "1"]
        [White "\(white)"]
        [Black "Nepo"]
        [Result "*"]
        
        1. e4 e5 *
        """
    }
    
    // MARK: Hash Persistence
    
    @Test func importPopulatesContentHashOnStoredPGN() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        
        let imported = try store.importPGN(text: Self.samplePGN())
        
        // The whole point of the field is that it survives import and is
        // queryable. An empty string here means deduplication is dead.
        #expect(!imported.contentHash.isEmpty)
        #expect(
            imported.contentHash.count == 32,
            "Expected 32-char MD5 hex, got '\(imported.contentHash)'"
        )
    }
    
    // MARK: Deduplication
    
    @Test func reimportingIdenticalPGNThrowsDuplicate() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        
        let first = try store.importPGN(text: Self.samplePGN())
        
        do {
            _ = try store.importPGN(text: Self.samplePGN())
            Issue.record("Expected duplicate error on re-import; import succeeded")
        } catch let PGNStore.Error.duplicate(existingID, existingName) {
            #expect(existingID == first.persistentModelID)
            #expect(existingName == first.name)
        } catch {
            Issue.record("Expected .duplicate, got \(error)")
        }
    }
    
    @Test func distinctPGNsImportSeparately() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        
        let a = try store.importPGN(text: Self.samplePGN(white: "Carlsen"))
        let b = try store.importPGN(text: Self.samplePGN(white: "Fischer"))
        
        #expect(a.contentHash != b.contentHash)
        #expect(a.persistentModelID != b.persistentModelID)
    }
    
    @Test func dedupSurvivesAcrossStoreInstances() throws {
        // The dedup check goes through a SwiftData fetch, not in-memory
        // state on the store. A fresh `PGNStore` over the same context
        // must still see the prior import.
        let context = try Self.makeContext()
        
        let firstStore = PGNStore(modelContext: context)
        _ = try firstStore.importPGN(text: Self.samplePGN())
        
        let secondStore = PGNStore(modelContext: context)
        #expect(throws: PGNStore.Error.self) {
            try secondStore.importPGN(text: Self.samplePGN())
        }
    }
    
    /// Pins the hash's date rendering — a **persistence contract** (see
    /// `PGNStore.hashDateString`): every stored `contentHash` was computed
    /// against "yyyy.MM.dd" in UTC, so any drift here silently rots
    /// deduplication against the existing Library. The dates are built
    /// through an explicit UTC Gregorian calendar so the expectations are
    /// exact regardless of the test host's locale/zone; the late-evening
    /// UTC case guards the classic off-by-a-zone bug (a host in the
    /// Americas would render the *previous* local day).
    @Test func hashDateRenderingIsPinnedToUTCDots() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        
        let midJuly = try #require(utc.date(from: DateComponents(
            year: 2026, month: 7, day: 16, hour: 12
        )))
        #expect(PGNStore.hashDateString(from: midJuly) == "2026.07.16")
        
        let lateNewYearsEve = try #require(utc.date(from: DateComponents(
            year: 2025, month: 12, day: 31, hour: 23, minute: 59
        )))
        #expect(PGNStore.hashDateString(from: lateNewYearsEve) == "2025.12.31")
        
        let singleDigits = try #require(utc.date(from: DateComponents(
            year: 999, month: 1, day: 2
        )))
        #expect(PGNStore.hashDateString(from: singleDigits) == "0999.01.02",
                "Zero-padding must match the old formatter's yyyy.MM.dd")
    }
    
    // MARK: Structural Edit Door (M11 review)
    
    /// `applyEdit(to:_:)` welds mutation and rehash together: the hash
    /// after an edit must differ from the pre-edit hash whenever a
    /// hash-covered field changed.
    @Test func applyEditRefreshesTheHashAtomically() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let pgn = try store.importPGN(text: Self.samplePGN())
        let before = pgn.contentHash
        
        try store.applyEdit(to: pgn) { $0.white = "Edited" }
        
        #expect(pgn.white == "Edited")
        #expect(pgn.contentHash != before)
    }
}
