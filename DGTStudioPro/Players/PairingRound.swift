//
//  PairingRound.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 21/07/2026.
//

import Foundation

/// M-lib.1 (D16′): the New Game dialog's round prefill — "the latest round
/// among archived games pairing these two players, plus one." A pure fold
/// over `GameRecord` in the D10′ shape: no SwiftData, no fixtures, opaque
/// identity keys (the caller resolves display text to `normalizedName`
/// keys; this fold only compares them).
///
/// The recorded rules:
/// - **F9 reading**: a record belongs to the pairing iff its two resolved
///   seat keys equal the queried pair *as a set* — either color
///   assignment counts, and a game against any third player never counts.
/// - **"Latest" is the numeric maximum**, not the chronologically last
///   game's round: rounds are the rivalry's counter, and re-importing an
///   old round-2 game must not wind an established round-7 pairing
///   backwards. (Sub-decision recorded with D16′ at delivery.)
/// - **Unknowns never inform** (the D12′ philosophy): a record with an
///   unresolved seat can't prove the pairing, and a pairing record with a
///   nil round contributes nothing to the maximum. A pairing with games
///   but no numbered rounds has no round history — nil, Round stays empty.
internal enum PairingRound {
    
    /// The suggested Round for a new game between `first` and `second`
    /// (both `Player.normalizedName` keys): latest pairing round + 1, or
    /// nil when the pairing has no numbered history.
    internal static func nextRound(
        between first: String,
        and second: String,
        in records: [GameRecord]
    ) -> Int? {
        let pairing: Set<String> = [first, second]
        let latest = records
            .compactMap { record -> Int? in
                guard
                    let white = record.white,
                    let black = record.black,
                    Set([white.key, black.key]) == pairing
                else { return nil }
                return record.round
            }
            .max()
        return latest.map { $0 + 1 }
    }
}
