import Testing
@testable import DGTStudioPro

/// Coverage for the pure presentation logic on `PGN` that needs no persisted
/// instance: the `GameResult` raw-value mapping to PGN result notation and the
/// `nameIsStaleDefault` backfill predicate. The name transform itself left this
/// file - it lives on `PlayerName` now, suited by `PlayerNameTests`.
/// The `@Model`-bound instance accessors and the import/dedup path are covered
/// with a real container in `PGNStoreTests`; everything here is instance-free,
/// so the suite is neither container-dependent nor `@MainActor`.
@Suite("PGN - Display Names & Result")
struct PGNDisplayTests {

    // MARK: GameResult
    
    /// The raw values are the literal PGN result strings - the on-disk and
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
    
    /// An empty stored name is always stale - it heals to the display form.
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
    
    /// A name already in display form is not stale - no rewrite.
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
