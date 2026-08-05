import Foundation

/// Glicko-1 (Glickman), the amateur-friendly rating (D11′): the per-player
/// deviation replaces Elo's one-size K, so a fresh player converges in a
/// handful of games while an established one barely moves on an upset.
///
/// Locked parameters and deliberate deviations from the paper:
/// - Initial 1500 / RD 350, RD floor 30, cap 350, draws score 0.5.
/// - **c = 0** — no RD inflation over time. The paper grows uncertainty
///   between periods via wall-clock; dropping it makes the whole system a
///   pure deterministic fold over ordered records (no "now" input), the
///   same testability contract as everything else here. Revisit only if
///   inactivity decay ever matters for a household ladder.
/// - **Rating period = one game** in the fold (the FICS-style degenerate
///   case). `updated(_:against:)` still takes an *array* because it is
///   the textbook multi-opponent period formula — which is exactly what
///   lets the tests pin Glickman's canonical worked example directly.
/// - `isProvisional` while deviation exceeds 110 — our chosen display
///   threshold for "too few games to trust", not an external standard.
///
/// This is the secondary stat: Rankings *order* is total wins
/// (`PlayerStats.rankingOrder`); this fold supplies the number beside it
/// and the trend line behind it.
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
        
        /// The one display rule for a rating — "1662" or "1662*" —
        /// centralized because it was about to exist in four views.
        /// "Unrated" (the nil case) stays at call sites: only they know
        /// whether nil means no player or no rated games.
        ///
        /// **The marker was the word "(provisional)" until 5 Aug 2026**, when
        /// the Players table gained a Rating column: thirteen characters of
        /// parenthetical in a 120 pt cell truncate, and a rating that reads
        /// "1662 (provisi…" is worse than no marker at all. The asterisk is
        /// also the convention a chess reader already knows, so it needs no
        /// legend — which the word did not, but the word was only ever
        /// affordable in the two roomy surfaces that existed before the
        /// column.
        ///
        /// **`*` means something else in this app, and that is worth naming
        /// rather than discovering.** It is PGN's ongoing-result token, which
        /// Decision #3 refuses at the archive door and D55′ folds to an em
        /// dash on display. The two never meet: this one always trails digits
        /// inside a Rating cell, that one stands alone in a Result cell. A
        /// genuine collision would be a *result* surface reaching for this
        /// glyph, and the separation is the reason to state it here.
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
    
    /// One point of a player's rating history; `date` is the game's
    /// `effectiveDate`.
    internal struct Sample: Sendable, Hashable {
        internal let date: Date
        internal let rating: Rating
    }
    
    // MARK: Period Update
    
    /// The Glicko-1 period update. Empty outcomes return the input
    /// unchanged (with c = 0 an idle period is a no-op by construction).
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
    
    /// Rating histories over a set of game records, keyed like
    /// `PlayerStats` by the resolved player key. Order-of-input
    /// independent: records are sorted by `GameRecord.chronologicalOrder`
    /// before folding — the determinism contract.
    ///
    /// A record is **rated** only when its result is decided *and* both
    /// sides are resolved (you can't update against an unknown opponent's
    /// rating; a win over `"?"` is a win in `PlayerStats`, not here).
    /// Both participants update **simultaneously** from their pre-game
    /// ratings — sequential updates would make the outcome depend on
    /// which side you processed first.
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
    
    /// The paper's g(RD): dampens an opponent's influence by their own
    /// uncertainty.
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
