import Foundation

/// Per-player aggregates over `GameRecord`s, plus the two contracts the destinations lean on:
/// `index(of:)` and `rankingOrder` (D11′). W/D/L counts decided games only; `winRate` is wins
/// over decided — an ongoing import can never move a percentage.
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
    /// Motif mates delivered (D19′) — counts from the motif, so it can exceed `matesDelivered`
    /// while the two `#` spellings disagree (standing open item).
    internal let specialMatesDelivered: Int
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
    
    /// Groups by resolved side, key-ascending (the deterministic baseline; destinations re-sort).
    /// Unresolved sides contribute nothing.
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
    
    // MARK: Head to Head (3 Aug 2026)

    /// W–D–L **from `first`'s side** over their mutual games; nil when they never met, and nil for
    /// a player against themselves. Ordered pair in, oriented numbers out. `*` is not a result here
    /// (Decision #3's stance).
    internal static func headToHead(
        _ first: String,
        _ second: String,
        in records: [GameRecord]
    ) -> (wins: Int, draws: Int, losses: Int)? {
        guard first != second else { return nil }
        var wins = 0, draws = 0, losses = 0, met = false

        for record in records {
            guard let white = record.white?.key, let black = record.black?.key else { continue }
            let firstIsWhite: Bool
            if white == first && black == second {
                firstIsWhite = true
            } else if white == second && black == first {
                firstIsWhite = false
            } else {
                continue
            }
            met = true
            switch record.result {
            case .whiteWins: firstIsWhite ? (wins += 1) : (losses += 1)
            case .blackWins: firstIsWhite ? (losses += 1) : (wins += 1)
            case .draw:      draws += 1
            case .ongoing:   break
            }
        }

        return met ? (wins, draws, losses) : nil
    }

    // MARK: Ranking (D11′)
    
    /// D11′: wins ↓, win rate ↓, `key` ↑ — the key, not the display name: the final tiebreak must
    /// be locale-free to stay deterministic.
    internal static func rankingOrder(_ lhs: PlayerStats, _ rhs: PlayerStats) -> Bool {
        if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
        if lhs.winRate != rhs.winRate { return lhs.winRate > rhs.winRate }
        return lhs.key < rhs.key
    }
    
    // MARK: Accumulator
    
    private struct Accumulator {
        let key: String
        let name: String
        var games = 0
        var whiteWins = 0, whiteDraws = 0, whiteLosses = 0
        var blackWins = 0, blackDraws = 0, blackLosses = 0
        var matesDelivered = 0
        var specialMatesDelivered = 0
        var firstPlayed: Date
        var lastPlayed: Date
        
        init(side: GameRecord.Side, record: GameRecord) {
            self.key = side.key
            self.name = side.name
            self.firstPlayed = record.effectiveDate
            self.lastPlayed = record.effectiveDate
        }
        
        mutating func absorb(_ record: GameRecord, as color: PieceColor) {
            games += 1
            firstPlayed = min(firstPlayed, record.effectiveDate)
            lastPlayed = max(lastPlayed, record.effectiveDate)
            
            switch (record.result, color) {
            case (.whiteWins, .white):
                whiteWins += 1
                if record.endedInMate { matesDelivered += 1 }
                if record.specialCheckmate != nil { specialMatesDelivered += 1 }
            case (.whiteWins, .black): blackLosses += 1
            case (.blackWins, .black):
                blackWins += 1
                if record.endedInMate { matesDelivered += 1 }
                if record.specialCheckmate != nil { specialMatesDelivered += 1 }
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
                specialMatesDelivered: specialMatesDelivered,
                firstPlayed: firstPlayed, lastPlayed: lastPlayed
            )
        }
    }
}
