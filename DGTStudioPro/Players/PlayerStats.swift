//
//  PlayerStats.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import Foundation

/// Per-player aggregates over a set of `GameRecord`s, plus the two
/// contracts the destinations lean on: `index(of:)` (the grouping fold)
/// and `rankingOrder` (D11′'s recorded Rankings comparator).
///
/// Counting rules, recorded:
/// - `games` counts every appearance, ongoing included — the honest
///   "games in the Library" number, which is why a player seen only in
///   an ongoing game still exists in the index.
/// - The W/D/L splits count decided games only; `winRate` is wins over
///   decided (0 with none decided), so an ongoing import can never move
///   a percentage.
/// - `matesDelivered` credits the *winner* of a game whose last move
///   carries `#` — result and mate flag together identify the deliverer.
/// - `firstPlayed`/`lastPlayed` use `effectiveDate`, the same fallback
///   rule the rating fold orders by. Non-optional: a player only exists
///   through at least one record.
internal struct PlayerStats: Sendable, Hashable, Identifiable {
    
    // MARK: Stored Properties
    
    internal let key: String
    internal let name: String
    internal let games: Int
    internal let whiteWins: Int
    internal let whiteDraws: Int
    internal let whiteLosses: Int
    internal let blackWins: Int
    internal let blackDraws: Int
    internal let blackLosses: Int
    internal let matesDelivered: Int
    internal let firstPlayed: Date
    internal let lastPlayed: Date
    
    // MARK: Computed Properties
    
    internal var id: String { key }
    internal var wins: Int { whiteWins + blackWins }
    internal var draws: Int { whiteDraws + blackDraws }
    internal var losses: Int { whiteLosses + blackLosses }
    internal var decided: Int { wins + draws + losses }
    internal var winRate: Double { decided > 0 ? Double(wins) / Double(decided) : 0 }
    
    // MARK: Index
    
    /// Groups records by resolved side. Output is key-ascending — the
    /// deterministic baseline order; destinations re-sort for display.
    /// Unresolved sides contribute nothing (a `"?"` vs. Nepo game is one
    /// appearance for Nepo and none for the placeholder).
    internal static func index(of records: [GameRecord]) -> [PlayerStats] {
        var accumulators: [String: Accumulator] = [:]
        
        for record in records {
            if let side = record.white {
                accumulators[side.key, default: Accumulator(side: side, record: record)]
                    .absorb(record, as: .white)
            }
            if let side = record.black {
                accumulators[side.key, default: Accumulator(side: side, record: record)]
                    .absorb(record, as: .black)
            }
        }
        
        return accumulators.values
            .map(\.stats)
            .sorted { $0.key < $1.key }
    }
    
    // MARK: Ranking (D11′)
    
    /// The recorded Rankings order: total wins descending, win rate
    /// descending, then `key` ascending — the key rather than the display
    /// name because the final tiebreak must be locale-free to stay
    /// deterministic.
    internal static func rankingOrder(_ lhs: PlayerStats, _ rhs: PlayerStats) -> Bool {
        if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
        if lhs.winRate != rhs.winRate { return lhs.winRate > rhs.winRate }
        return lhs.key < rhs.key
    }
    
    // MARK: Accumulator
    
    private enum Color { case white, black }
    
    private struct Accumulator {
        let key: String
        let name: String
        var games = 0
        var whiteWins = 0, whiteDraws = 0, whiteLosses = 0
        var blackWins = 0, blackDraws = 0, blackLosses = 0
        var matesDelivered = 0
        var firstPlayed: Date
        var lastPlayed: Date
        
        init(side: GameRecord.Side, record: GameRecord) {
            self.key = side.key
            self.name = side.name
            self.firstPlayed = record.effectiveDate
            self.lastPlayed = record.effectiveDate
        }
        
        mutating func absorb(_ record: GameRecord, as color: Color) {
            games += 1
            firstPlayed = min(firstPlayed, record.effectiveDate)
            lastPlayed = max(lastPlayed, record.effectiveDate)
            
            switch (record.result, color) {
            case (.whiteWins, .white):
                whiteWins += 1
                if record.endedInMate { matesDelivered += 1 }
            case (.whiteWins, .black): blackLosses += 1
            case (.blackWins, .black):
                blackWins += 1
                if record.endedInMate { matesDelivered += 1 }
            case (.blackWins, .white): whiteLosses += 1
            case (.draw, .white): whiteDraws += 1
            case (.draw, .black): blackDraws += 1
            case (.ongoing, _): break   // counted in `games` only
            }
        }
        
        var stats: PlayerStats {
            PlayerStats(
                key: key, name: name, games: games,
                whiteWins: whiteWins, whiteDraws: whiteDraws, whiteLosses: whiteLosses,
                blackWins: blackWins, blackDraws: blackDraws, blackLosses: blackLosses,
                matesDelivered: matesDelivered,
                firstPlayed: firstPlayed, lastPlayed: lastPlayed
            )
        }
    }
}
