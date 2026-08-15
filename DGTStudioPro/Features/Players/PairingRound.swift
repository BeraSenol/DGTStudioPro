import Foundation

/// The New Game round prefill (D16′): latest round among games pairing these two, plus one.
/// The pair matches as a *set*; "latest" is the numeric maximum — a late-imported old game
/// can't wind the rivalry counter backwards; unknowns never inform.
enum PairingRound {
    
    /// The suggested Round for a new game between `first` and `second`
    /// (both `Player.normalizedName` keys): latest pairing round + 1, or
    /// nil when the pairing has no numbered history.
    static func nextRound(
        between first: String,
        and second: String,
        in records: [GameRecord]
    ) -> Int? {
        // Pair-as-set, without building a set per record. Self-pairing stays
        // total: with `first == second` the first clause matches a game a
        // player played against themselves, and an `a` vs `a` game still
        // fails an `a` vs `b` query — the two cases `PairingRoundTests` pins.
        let latest = records
            .compactMap { record -> Int? in
                guard let white = record.white, let black = record.black else { return nil }
                let isThisPairing =
                (white.key == first && black.key == second)
                || (white.key == second && black.key == first)
                return isThisPairing ? record.round : nil
            }
            .max()
        return latest.map { $0 + 1 }
    }
}
