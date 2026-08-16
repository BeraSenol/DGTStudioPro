import Foundation

/// Per-player aggregates over `GameRecord`s, plus the two contracts the destinations lean on:
/// `index(of:)` and `rankingOrder`. W/D/L counts decided games only; `winRate` is wins
/// over decided - an ongoing import can never move a percentage.
struct PlayerStats: Sendable, Hashable, Identifiable {
    
    // MARK: Stored Properties
    
    let key: String
    let name: String
    let games: Int
    let whiteWins: Int
    let whiteDraws: Int
    let whiteLosses: Int
    let blackWins: Int
    let blackDraws: Int
    let blackLosses: Int
    let matesDelivered: Int
    /// Motif mates delivered - counts from the motif, so it can exceed `matesDelivered`
    /// while the two `#` spellings disagree (standing open item).
    let specialMatesDelivered: Int
    let firstPlayed: Date
    let lastPlayed: Date
    
    // MARK: Computed Properties
    
    var id: String { key }
    var wins: Int { whiteWins + blackWins }
    var draws: Int { whiteDraws + blackDraws }
    var losses: Int { whiteLosses + blackLosses }
    var decided: Int { wins + draws + losses }
    var winRate: Double { decided > 0 ? Double(wins) / Double(decided) : 0 }
    
    // MARK: Index
    
    /// Groups by resolved side, key-ascending (the deterministic baseline; destinations re-sort).
    /// Unresolved sides contribute nothing.
    static func index(of records: [GameRecord]) -> [PlayerStats] {
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
    /// deliberately.
    static func headToHead(
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

    // MARK: Opponents and Form (13 Aug 2026)

    /// One opponent's record, oriented from the subject's side - `wins` means the subject won.
    struct Opponent: Sendable, Hashable, Identifiable {
        let key: String
        let name: String
        let wins: Int
        let draws: Int
        let losses: Int

        var id: String { key }
        var decided: Int { wins + draws + losses }
    }

    /// A decided game's outcome from the subject's side. Deliberately not `GameResult`: that enum is
    /// white-relative and carries `.ongoing`, and both properties are wrong here - a form strip reads
    /// from one player's seat, and an unfinished game has no outcome to show.
    enum Outcome: Sendable, Hashable {
        case win, draw, loss
    }

    /// Everyone `key` has met, most-played first. Ties break on `key` ascending for `rankingOrder`'s
    /// reason - the final tiebreak must be locale-free or two equally-played opponents can swap
    /// places between launches.
    ///
    /// Ongoing games are skipped and self-play contributes nothing, both matching `headToHead`:
    /// three foldings of "who did this player beat" that disagreed would be worse than one that is
    /// narrow. A player who has only ever played themselves returns an empty array, not a row of
    /// zeroes against their own name.
    static func opponents(of key: String, in records: [GameRecord]) -> [Opponent] {
        var tallies: [String: Opponent] = [:]

        for record in records.sorted(by: GameRecord.chronologicalOrder) {
            guard
                record.result != .ongoing,
                let white = record.white,
                let black = record.black,
                white.key != black.key
            else { continue }

            let subjectIsWhite: Bool
            if white.key == key {
                subjectIsWhite = true
            } else if black.key == key {
                subjectIsWhite = false
            } else {
                continue
            }

            let other = subjectIsWhite ? black : white
            let existing = tallies[other.key]
                ?? Opponent(key: other.key, name: other.name, wins: 0, draws: 0, losses: 0)

            var wins = existing.wins, draws = existing.draws, losses = existing.losses
            switch record.result {
            case .whiteWins: subjectIsWhite ? (wins += 1) : (losses += 1)
            case .blackWins: subjectIsWhite ? (losses += 1) : (wins += 1)
            case .draw:      draws += 1
            case .ongoing:   continue   // unreachable; keeps the switch total
            }

            tallies[other.key] = Opponent(
                key: existing.key, name: existing.name,
                wins: wins, draws: draws, losses: losses
            )
        }

        return tallies.values.sorted {
            $0.decided != $1.decided ? $0.decided > $1.decided : $0.key < $1.key
        }
    }

    /// The subject's last `limit` decided results, **oldest first** - the order a form strip is read
    /// in, so the view never has to reverse it and cannot reverse it twice.
    ///
    /// The cap is applied at the end, so this is the *most recent* window: taking the prefix would
    /// silently show a player's debut whenever their history outgrew the limit, which looks
    /// identical to working and is wrong in exactly the case the strip exists for.
    static func form(of key: String, in records: [GameRecord], limit: Int = 10) -> [Outcome] {
        guard limit > 0 else { return [] }

        let outcomes: [Outcome] = records
            .sorted(by: GameRecord.chronologicalOrder)
            .compactMap { record in
                guard
                    record.result != .ongoing,
                    let white = record.white,
                    let black = record.black,
                    // Self-play is skipped for `opponents`' reason rather than a new one: the seat guard refuses
                    // it at the editing door and admits it at import, so these records exist, and one
                    // of them would otherwise report a win and a loss for the same person.
                    white.key != black.key
                else { return nil }

                let subjectIsWhite: Bool
                if white.key == key {
                    subjectIsWhite = true
                } else if black.key == key {
                    subjectIsWhite = false
                } else {
                    return nil
                }

                switch record.result {
                case .whiteWins: return subjectIsWhite ? .win : .loss
                case .blackWins: return subjectIsWhite ? .loss : .win
                case .draw:      return .draw
                case .ongoing:   return nil   // unreachable; keeps the switch total
                }
            }

        return Array(outcomes.suffix(limit))
    }

    // MARK: Ranking
    
    /// Wins ↓, win rate ↓, `key` ↑ - the key, not the display name: the final tiebreak must
    /// be locale-free to stay deterministic.
    static func rankingOrder(_ lhs: PlayerStats, _ rhs: PlayerStats) -> Bool {
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
