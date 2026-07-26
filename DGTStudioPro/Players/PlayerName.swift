//
//  PlayerName.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/07/2026.
//

import Foundation

/// The one rendering of a player name (D23′): PGN carries "Last, First",
/// every surface shows "First Last".
///
/// A pure formatter with a suite, in the `RecoveryGuidance` / `GameHeadline`
/// / `PairingRound` mould. Extracted off `PGN` because five clients consume
/// it and only one of them is the model — `PGNStore.resolvePlayer` (which
/// fixes `Player.name` in display form, so the whole Players/Rankings stack
/// inherits it), `RosterSummary`, `GameHeadline`, `PGN`'s own display
/// accessors, and the draft-resume alert.
///
/// Storage is deliberately untouched: tags stay in the form they arrived in,
/// because the content hash covers them and D24′ export round-trips them
/// byte for byte.
/// This type owns the boundary, not the database.
///
/// Rejected: a `tagForm(of:)` inverse ("Magnus Carlsen" → "Carlsen, Magnus").
/// Splitting a display name back into surname and given names is undecidable
/// without a comma to mark the seam, and a guess would corrupt the tag the
/// hash covers. Names travel one way.
internal enum PlayerName {
    
    /// **Idempotent by construction** — the output never contains a comma,
    /// so `displayForm(of: displayForm(of: x)) == displayForm(of: x)` for
    /// every input. Before D23′ the transform split on the first comma and
    /// left the remainder intact, so "Carlsen, Magnus, Jr" became
    /// "Magnus, Jr Carlsen" and a second pass rotated it again — which is
    /// why `RosterSummary` had to document "store tag form, transform
    /// exactly once" as a rule its callers must remember. Now a double
    /// application is a no-op and the rule is structural, which is the
    /// whole point: "always show First Last" cannot depend on every future
    /// display site getting the count right.
    internal static func displayForm(of raw: String) -> String {
        let parts = raw.split(
            separator: ",", maxSplits: 1, omittingEmptySubsequences: false
        )
        // No comma: already in display order, so this is a fold, not a flip.
        guard parts.count == 2 else { return folded(String(raw)) }
        
        let last = folded(String(parts[0]))
        // Any further comma belongs to a nonstandard tag ("Carlsen, Magnus,
        // Jr" — PGN separates multiple players with ":", not ","). Folding
        // it to a space is what keeps the output comma-free, and therefore
        // this function idempotent; the alternative ("Magnus Carlsen, Jr")
        // preserves a genealogical nicety at the cost of the invariant.
        let given = folded(parts[1].replacingOccurrences(of: ",", with: " "))
        
        if given.isEmpty { return last }
        if last.isEmpty { return given }
        return "\(given) \(last)"
    }
    
    /// Trim and collapse interior whitespace runs — `Player.normalizedKey`'s
    /// fold minus the lowercasing, so a display name and its identity key
    /// can never disagree about what "Magnus  Carlsen" is. The old transform
    /// trimmed with `.whitespaces` only and collapsed nothing, which let a
    /// run survive into `Player.name` and from there into every row, card,
    /// and monogram.
    private static func folded(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
