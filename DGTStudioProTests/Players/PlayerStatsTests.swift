//
//  PlayerStatsTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import Testing
import Foundation
@testable import DGTStudioPro

/// The counting rules of D10′/D11′, pinned (nonisolated — pure fold):
/// per-color splits, ongoing-counts-as-appearance-only, mate credit to
/// the winner, effective-date first/last, unresolved sides ignored, and
/// the recorded Rankings comparator with its full tiebreak chain.
@Suite("Player Stats")
struct PlayerStatsTests {
    
    // MARK: Helpers
    
    private let alice = GameRecord.Side(key: "alice", name: "Alice")
    private let bob   = GameRecord.Side(key: "bob",   name: "Bob")
    
    private func record(
        white: GameRecord.Side?,
        black: GameRecord.Side?,
        result: GameResult,
        endedInMate: Bool = false,
        date: Date? = nil,
        importedAt: Date = Date(timeIntervalSince1970: 1_000),
        contentHash: String = "hash"
    ) -> GameRecord {
        GameRecord(
            white: white, black: black, result: result, endedInMate: endedInMate,
            date: date, importedAt: importedAt, contentHash: contentHash
        )
    }
    
    private func stats(for key: String, in index: [PlayerStats]) throws -> PlayerStats {
        try #require(index.first { $0.key == key })
    }
    
    // MARK: Counting
    
    @Test func splitsResultsByColor() throws {
        let index = PlayerStats.index(of: [
            record(white: alice, black: bob, result: .whiteWins),
            record(white: alice, black: bob, result: .draw),
            record(white: bob, black: alice, result: .whiteWins),
            record(white: bob, black: alice, result: .blackWins),
        ])
        
        let aliceStats = try stats(for: "alice", in: index)
        #expect(aliceStats.games == 4)
        #expect(aliceStats.whiteWins == 1 && aliceStats.whiteDraws == 1 && aliceStats.whiteLosses == 0)
        #expect(aliceStats.blackWins == 1 && aliceStats.blackDraws == 0 && aliceStats.blackLosses == 1)
        #expect(aliceStats.wins == 2 && aliceStats.draws == 1 && aliceStats.losses == 1)
        #expect(aliceStats.decided == 4)
    }
    
    /// An ongoing game is an appearance, never a percentage: `games`
    /// includes it, W/D/L and `winRate` don't.
    @Test func ongoingCountsAsAppearanceOnly() throws {
        let index = PlayerStats.index(of: [
            record(white: alice, black: bob, result: .whiteWins),
            record(white: alice, black: bob, result: .ongoing),
        ])
        
        let aliceStats = try stats(for: "alice", in: index)
        #expect(aliceStats.games == 2)
        #expect(aliceStats.decided == 1)
        #expect(aliceStats.winRate == 1.0)
    }
    
    /// A player seen only in an ongoing game still exists — they're in
    /// the Library (the seed's Ruy Lopez case).
    @Test func ongoingOnlyPlayerIsStillIndexed() throws {
        let index = PlayerStats.index(of: [
            record(white: alice, black: bob, result: .ongoing)
        ])
        
        let aliceStats = try stats(for: "alice", in: index)
        #expect(aliceStats.games == 1)
        #expect(aliceStats.decided == 0)
        #expect(aliceStats.winRate == 0)
    }
    
    @Test func mateCreditGoesToTheWinnerOnly() throws {
        let index = PlayerStats.index(of: [
            record(white: alice, black: bob, result: .blackWins, endedInMate: true),
            record(white: alice, black: bob, result: .whiteWins),   // plain win, no mate
        ])
        
        #expect(try stats(for: "bob", in: index).matesDelivered == 1)
        #expect(try stats(for: "alice", in: index).matesDelivered == 0)
    }
    
    @Test func firstAndLastPlayedUseEffectiveDates() throws {
        let index = PlayerStats.index(of: [
            record(white: alice, black: bob, result: .draw,
                   date: Date(timeIntervalSince1970: 5_000)),
            // Undated — importedAt is its effective date, and it's earliest.
            record(white: alice, black: bob, result: .draw,
                   importedAt: Date(timeIntervalSince1970: 100), contentHash: "early"),
        ])
        
        let aliceStats = try stats(for: "alice", in: index)
        #expect(aliceStats.firstPlayed == Date(timeIntervalSince1970: 100))
        #expect(aliceStats.lastPlayed == Date(timeIntervalSince1970: 5_000))
    }
    
    @Test func unresolvedSidesContributeNothing() throws {
        let index = PlayerStats.index(of: [
            record(white: nil, black: bob, result: .whiteWins)   // "?" beat Bob
        ])
        
        #expect(index.count == 1)
        let bobStats = try stats(for: "bob", in: index)
        #expect(bobStats.games == 1 && bobStats.losses == 1)
    }
    
    @Test func indexIsKeyAscending() {
        let index = PlayerStats.index(of: [
            record(white: bob, black: alice, result: .draw)
        ])
        
        #expect(index.map(\.key) == ["alice", "bob"])
    }
    
    // MARK: Ranking (D11′)
    
    /// Wins outrank win rate outranks key — each link exercised at a
    /// boundary where the next one would disagree.
    @Test func rankingOrderRunsTheFullTiebreakChain() {
        func player(_ key: String, wins: Int, losses: Int) -> PlayerStats {
            PlayerStats(
                key: key, name: key, games: wins + losses,
                whiteWins: wins, whiteDraws: 0, whiteLosses: losses,
                blackWins: 0, blackDraws: 0, blackLosses: 0,
                matesDelivered: 0,
                firstPlayed: Date(timeIntervalSince1970: 0),
                lastPlayed: Date(timeIntervalSince1970: 0)
            )
        }
        
        let manyWins   = player("zoe", wins: 5, losses: 5)   // 5 wins, 50%
        let efficient  = player("amy", wins: 4, losses: 0)   // 4 wins, 100%
        let grinder    = player("ben", wins: 4, losses: 4)   // 4 wins, 50%
        let grinderTwin = player("ann", wins: 4, losses: 4)  // ties into the key
        
        let ranked = [grinder, efficient, grinderTwin, manyWins]
            .sorted(by: PlayerStats.rankingOrder)
        
        #expect(ranked.map(\.key) == ["zoe", "amy", "ann", "ben"])
    }
}
