import Testing
import Foundation
@testable import DGTStudioPro

/// Pins the rating math and the fold's contracts (nonisolated — pure).
///
/// Reference values were computed by evaluating the Glicko-1 formulas at
/// full double precision, not copied from the paper's prose: Glickman's
/// published 1464.06 / 151.4 comes from *rounded intermediate* g and E
/// values in his walkthrough; the exact formulas give 1464.1065 /
/// 151.3989, which is what this implementation must produce.
@Suite("Glicko-1")
struct Glicko1Tests {
    
    // MARK: Helpers
    
    private let alice = GameRecord.Side(key: "alice", name: "Alice")
    private let bob   = GameRecord.Side(key: "bob",   name: "Bob")
    
    private func record(
        white: GameRecord.Side?,
        black: GameRecord.Side?,
        result: GameResult,
        date: Date,
        contentHash: String = "hash"
    ) -> GameRecord {
        GameRecord(
            white: white, black: black, result: result, endedInMate: false,
            date: date, importedAt: date, contentHash: contentHash
        )
    }
    
    private func expectClose(
        _ value: Double, _ expected: Double, within tolerance: Double = 0.001,
        _ comment: Comment? = nil, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            abs(value - expected) < tolerance,
            comment ?? "expected \(expected), got \(value)",
            sourceLocation: sourceLocation
        )
    }
    
    // MARK: Period Update
    
    /// Glickman's canonical example: 1500/RD 200 scores 1, 0, 0 against
    /// (1400, 30), (1550, 100), (1700, 300) in one period.
    @Test func glickmanWorkedExample() {
        let player = Glicko1.Rating(mean: 1500, deviation: 200)
        let updated = Glicko1.updated(player, against: [
            .init(opponent: .init(mean: 1400, deviation: 30), score: 1),
            .init(opponent: .init(mean: 1550, deviation: 100), score: 0),
            .init(opponent: .init(mean: 1700, deviation: 300), score: 0),
        ])
        
        expectClose(updated.mean, 1464.1065, within: 0.01)
        expectClose(updated.deviation, 151.3989, within: 0.01)
    }
    
    /// The amateur-convergence property that motivated D11′: one game
    /// between fresh players moves both by 162 points, symmetrically.
    @Test func freshEqualGameIsLargeAndSymmetric() {
        let winner = Glicko1.updated(.initial, against: [.init(opponent: .initial, score: 1)])
        let loser  = Glicko1.updated(.initial, against: [.init(opponent: .initial, score: 0)])
        
        expectClose(winner.mean, 1662.2120)
        expectClose(loser.mean, 1337.7880)
        expectClose(winner.deviation, 290.2305)
        expectClose(loser.deviation, 290.2305)
    }
    
    /// A draw between exact equals is exactly a no-op on the mean
    /// (s − E is literally zero), while the deviation still tightens —
    /// information without movement.
    @Test func freshEqualDrawMovesDeviationOnly() {
        let after = Glicko1.updated(.initial, against: [.init(opponent: .initial, score: 0.5)])
        
        #expect(after.mean == 1500)
        expectClose(after.deviation, 290.2305)
    }
    
    /// At RD 30 the unclamped update lands at 29.95 — the floor must
    /// engage, and the near-frozen mean barely moves on a win.
    @Test func deviationFloorEngages() {
        let veteran = Glicko1.Rating(mean: 1500, deviation: 30)
        let after = Glicko1.updated(veteran, against: [.init(opponent: .initial, score: 1)])
        
        #expect(after.deviation == Glicko1.deviationFloor)
        expectClose(after.mean, 1501.7274)
    }
    
    @Test func emptyPeriodIsIdentity() {
        let player = Glicko1.Rating(mean: 1600, deviation: 80)
        #expect(Glicko1.updated(player, against: []) == player)
    }
    
    @Test func provisionalThreshold() {
        #expect(Glicko1.Rating.initial.isProvisional)
        #expect(!Glicko1.Rating(mean: 1500, deviation: Glicko1.deviationFloor).isProvisional)
        #expect(!Glicko1.Rating(mean: 1500, deviation: 110).isProvisional, "boundary is established")
    }
    
    /// The marker is `*` since 5 Aug 2026, not the word "(provisional)" — the
    /// Rating column's 120 pt cell truncated the word. Argued at the
    /// declaration; the expected string moved and the two claims did not:
    /// provisional ratings are marked, settled ones are bare, and both round.
    ///
    /// This test is why the rename was caught at all. The change was made for
    /// a table cell, the doc comment above `displaySummary` still said
    /// "(provisional)" afterwards, and nothing else in the app would have
    /// disagreed out loud — three view sites print whatever this returns.
    @Test func displaySummaryRoundsAndMarksProvisional() {
        #expect(Glicko1.Rating(mean: 1662.212, deviation: 290.23).displaySummary == "1662*")
        #expect(Glicko1.Rating(mean: 1499.6, deviation: 30).displaySummary == "1500")
    }
    
    // MARK: The Fold
    
    /// A beats B, then B beats A. Pins three things at once: chronology
    /// (the fold must sort), simultaneity (game two uses both post-game-
    /// one states), and the genuine Glicko recency effect — the later win
    /// outweighs the earlier one because both deviations have tightened,
    /// so the pool does *not* return to 1500/1500.
    @Test func foldIsChronologicalAndSimultaneous() throws {
        let records = [
            record(white: alice, black: bob, result: .whiteWins,
                   date: Date(timeIntervalSince1970: 1_000), contentHash: "g1"),
            record(white: bob, black: alice, result: .whiteWins,
                   date: Date(timeIntervalSince1970: 2_000), contentHash: "g2"),
        ]
        
        let histories = Glicko1.histories(from: records)
        let aliceFinal = try #require(histories["alice"]?.last?.rating)
        let bobFinal = try #require(histories["bob"]?.last?.rating)
        
        expectClose(aliceFinal.mean, 1433.3384)
        expectClose(bobFinal.mean, 1566.6616)
        expectClose(aliceFinal.deviation, 260.2732)
        expectClose(bobFinal.deviation, 260.2732)
    }
    
    /// The determinism contract: input array order is irrelevant.
    @Test func foldIgnoresInputOrder() {
        let records = [
            record(white: alice, black: bob, result: .whiteWins,
                   date: Date(timeIntervalSince1970: 1_000), contentHash: "g1"),
            record(white: bob, black: alice, result: .whiteWins,
                   date: Date(timeIntervalSince1970: 2_000), contentHash: "g2"),
            record(white: alice, black: bob, result: .draw,
                   date: Date(timeIntervalSince1970: 3_000), contentHash: "g3"),
        ]
        
        #expect(Glicko1.histories(from: records) == Glicko1.histories(from: records.reversed()))
    }
    
    /// Rated means decided *and* both sides resolved: an ongoing game and
    /// a win over `"?"` both stay out of the ladder entirely.
    @Test func foldSkipsOngoingAndHalfResolvedRecords() {
        let histories = Glicko1.histories(from: [
            record(white: alice, black: bob, result: .ongoing,
                   date: Date(timeIntervalSince1970: 1_000), contentHash: "g1"),
            record(white: alice, black: nil, result: .whiteWins,
                   date: Date(timeIntervalSince1970: 2_000), contentHash: "g2"),
        ])
        
        #expect(histories.isEmpty)
    }
    
    @Test func historySamplesCarryEffectiveDates() throws {
        let first = Date(timeIntervalSince1970: 1_000)
        let second = Date(timeIntervalSince1970: 2_000)
        let histories = Glicko1.histories(from: [
            record(white: alice, black: bob, result: .whiteWins, date: first, contentHash: "g1"),
            record(white: alice, black: bob, result: .draw, date: second, contentHash: "g2"),
        ])
        
        let aliceHistory = try #require(histories["alice"])
        #expect(aliceHistory.map(\.date) == [first, second])
        #expect(aliceHistory.count == 2)
    }
}
