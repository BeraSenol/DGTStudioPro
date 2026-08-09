import Foundation

/// Glicko-1 (D11′): per-player deviation replaces Elo's one-size K. Locked: initial 1500/350,
/// floor 30, cap 350, c = 0 (a pure deterministic fold — no wall-clock input), one game per
/// period, provisional while RD > 110. Reference values pinned at full double precision.
internal enum Glicko1 {
    
    // MARK: Parameters (D11′)
    
    internal static let initialMean = 1500.0
    internal static let initialDeviation = 350.0
    internal static let deviationFloor = 30.0
    internal static let deviationCap = 350.0
    internal static let provisionalDeviationThreshold = 110.0
    
    private static let q = log(10.0) / 400.0
    
    // MARK: Types
    
    internal struct Rating: Sendable, Hashable {
        /// The paper's r — the mean of the modeled skill distribution.
        internal var mean: Double
        /// The paper's RD.
        internal var deviation: Double
        
        internal static let initial = Rating(mean: initialMean, deviation: initialDeviation)
        
        internal var isProvisional: Bool { deviation > provisionalDeviationThreshold }
        
        /// The one display rule — "1662" or "1662*" — centralized because it was about to exist in four
        /// views. "Unrated" (nil) stays at call sites: only they know their layout. The `*` never
        /// collides with the result token: this one always trails digits.
        internal var displaySummary: String {
            let rounded = Int(mean.rounded())
            return isProvisional ? "\(rounded)*" : "\(rounded)"
        }
    }
    
    internal struct Outcome: Sendable {
        /// The opponent's rating *before* this period.
        internal let opponent: Rating
        /// 1 win, 0.5 draw, 0 loss.
        internal let score: Double
    }
    
    /// One history point; `date` is the game's `effectiveDate`.
    internal struct Sample: Sendable, Hashable {
        internal let date: Date
        internal let rating: Rating
    }
    
    // MARK: Period Update
    
    /// The period update; empty outcomes return the input unchanged (c = 0 makes idle a no-op).
    internal static func updated(_ player: Rating, against outcomes: [Outcome]) -> Rating {
        guard !outcomes.isEmpty else { return player }
        
        var dSquaredInverse = 0.0
        var adjustment = 0.0
        for outcome in outcomes {
            let gOpponent = g(outcome.opponent.deviation)
            let expected = expectedScore(
                of: player.mean,
                against: outcome.opponent.mean,
                opponentDeviation: outcome.opponent.deviation
            )
            dSquaredInverse += gOpponent * gOpponent * expected * (1 - expected)
            adjustment += gOpponent * (outcome.score - expected)
        }
        dSquaredInverse *= q * q
        
        let denominator = 1 / (player.deviation * player.deviation) + dSquaredInverse
        let mean = player.mean + (q / denominator) * adjustment
        let deviation = (1 / denominator).squareRoot()
        
        return Rating(
            mean: mean,
            deviation: min(max(deviation, deviationFloor), deviationCap)
        )
    }
    
    // MARK: The Fold
    
    /// Histories over records, keyed like `PlayerStats`. Order-of-input independent (sorted by
    /// `chronologicalOrder`). Rated = decided *and* both seats resolved; participants update
    /// simultaneously from pre-game states.
    internal static func histories(from records: [GameRecord]) -> [String: [Sample]] {
        var current: [String: Rating] = [:]
        var histories: [String: [Sample]] = [:]
        
        for record in records.sorted(by: GameRecord.chronologicalOrder) {
            guard
                record.result != .ongoing,
                let white = record.white,
                let black = record.black
            else { continue }
            
            let whiteScore: Double
            switch record.result {
            case .whiteWins: whiteScore = 1
            case .blackWins: whiteScore = 0
            case .draw:      whiteScore = 0.5
            case .ongoing:   continue   // unreachable; keeps the switch total
            }
            
            let whiteBefore = current[white.key, default: .initial]
            let blackBefore = current[black.key, default: .initial]
            
            let whiteAfter = updated(
                whiteBefore,
                against: [Outcome(opponent: blackBefore, score: whiteScore)]
            )
            let blackAfter = updated(
                blackBefore,
                against: [Outcome(opponent: whiteBefore, score: 1 - whiteScore)]
            )
            
            current[white.key] = whiteAfter
            current[black.key] = blackAfter
            histories[white.key, default: []].append(Sample(date: record.effectiveDate, rating: whiteAfter))
            histories[black.key, default: []].append(Sample(date: record.effectiveDate, rating: blackAfter))
        }
        
        return histories
    }
    
    // MARK: Private Helpers
    
    /// The paper's g(RD): dampens an opponent's influence by their own uncertainty.
    private static func g(_ deviation: Double) -> Double {
        1 / (1 + 3 * q * q * deviation * deviation / (Double.pi * Double.pi)).squareRoot()
    }
    
    /// The paper's E: expected score against an opponent, deviation-damped.
    private static func expectedScore(
        of mean: Double,
        against opponentMean: Double,
        opponentDeviation: Double
    ) -> Double {
        1 / (1 + pow(10, -g(opponentDeviation) * (mean - opponentMean) / 400))
    }
}
