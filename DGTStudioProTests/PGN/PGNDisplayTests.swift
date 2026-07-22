//
//  PGNDisplayTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/06/2026.
//

import Testing
@testable import DGTStudioPro

/// Coverage for the pure presentation logic on `PGN` that needs no persisted
/// instance: the `displayPlayerName(_:)` "Last, First" → "First Last" transform
/// (a `static func`) and the `GameResult` raw-value mapping to PGN result
/// notation. The `@Model`-bound instance accessors and the import/dedup path
/// are covered with a real container in `PGNStoreTests`; everything here is
/// instance-free, so the suite is neither container-dependent nor `@MainActor`.
@Suite("PGN — Display Names & Result")
struct PGNDisplayTests {
    
    // MARK: displayPlayerName
    
    /// The common case: PGN stores "Last, First"; the UI shows "First Last".
    @Test func flipsLastCommaFirstIntoDisplayOrder() {
        #expect(PGN.displayPlayerName("Carlsen, Magnus") == "Magnus Carlsen")
        #expect(PGN.displayPlayerName("Fischer, Robert") == "Robert Fischer")
    }
    
    /// Multi-part given names are preserved in order.
    @Test func preservesMultiPartFirstNames() {
        #expect(PGN.displayPlayerName("Heylen, Christophe Maria") == "Christophe Maria Heylen")
    }
    
    /// A name with no comma is already in display form and passes through
    /// untouched (single token or already "First Last").
    @Test func passesThroughNamesWithoutAComma() {
        #expect(PGN.displayPlayerName("Magnus Carlsen") == "Magnus Carlsen")
        #expect(PGN.displayPlayerName("Nepo") == "Nepo")
    }
    
    /// Whitespace around each part is trimmed, and degenerate comma forms
    /// degrade gracefully: a trailing comma yields just the surname, a leading
    /// comma yields just the given name, and an all-whitespace input is empty.
    @Test func trimsWhitespaceAndHandlesStrayCommas() {
        #expect(PGN.displayPlayerName("Carlsen,  Magnus ") == "Magnus Carlsen")
        #expect(PGN.displayPlayerName("Carlsen,") == "Carlsen")   // empty given name
        #expect(PGN.displayPlayerName(", Magnus") == "Magnus")    // empty surname
        #expect(PGN.displayPlayerName("   ") == "")               // empty after trim
    }
    
    // MARK: GameResult
    
    /// The raw values are the literal PGN result strings — the on-disk and
    /// `Result` tag encoding.
    @Test func gameResultRawValuesArePGNNotation() {
        #expect(GameResult.whiteWins.rawValue == "1-0")
        #expect(GameResult.blackWins.rawValue == "0-1")
        #expect(GameResult.draw.rawValue == "1/2-1/2")
        #expect(GameResult.ongoing.rawValue == "*")
    }
    
    /// And they round-trip back from those strings, with unknown text rejected.
    @Test func gameResultParsesFromRawValue() {
        #expect(GameResult(rawValue: "1-0") == .whiteWins)
        #expect(GameResult(rawValue: "0-1") == .blackWins)
        #expect(GameResult(rawValue: "1/2-1/2") == .draw)
        #expect(GameResult(rawValue: "*") == .ongoing)
        #expect(GameResult(rawValue: "nonsense") == nil)
    }
    
    // MARK: nameIsStaleDefault (Library name backfill)
    
    /// An empty stored name is always stale — it heals to the display form.
    @Test func emptyNameIsStale() {
        #expect(PGN.nameIsStaleDefault(
            storedName: "", white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian"))
    }
    
    /// A pre-display-support row stored its name in raw "Last, First vs
    /// Last, First" form; it differs from the display default and heals.
    @Test func legacyRawTagNameIsStale() {
        #expect(PGN.nameIsStaleDefault(
            storedName: "Carlsen, Magnus vs Nepomniachtchi, Ian",
            white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian"))
    }
    
    /// A name already in display form is not stale — no rewrite.
    @Test func displayFormNameIsNotStale() {
        #expect(!PGN.nameIsStaleDefault(
            storedName: "Magnus Carlsen vs Ian Nepomniachtchi",
            white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian"))
    }
    
    /// The 20 July false-positive: comma-free names make the raw (legacy) and
    /// display defaults identical, so a freshly archived game whose name
    /// equals both must NOT be treated as a stale legacy row.
    @Test func commaFreeDefaultIsNotStale() {
        #expect(!PGN.nameIsStaleDefault(
            storedName: "Bera vs Lorenzo", white: "Bera", black: "Lorenzo"))
    }
    
    /// A user-set custom name is neither empty nor a recognized default.
    @Test func customNameIsNotStale() {
        #expect(!PGN.nameIsStaleDefault(
            storedName: "Club Championship R3", white: "Bera", black: "Lorenzo"))
    }
}
