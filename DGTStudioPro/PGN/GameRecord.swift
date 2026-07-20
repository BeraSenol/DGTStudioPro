//
//  GameRecord.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import Foundation

/// A Library game projected to the pure value the M-prs cores consume
/// (Decision D10′): `PlayerStats` and `Glicko1` never touch `@Model`s,
/// so their suites run nonisolated with no store fixture — the
/// `DGTAutoConnectPolicy` / `AnalysisQueue` precedent, applied to the
/// Library domain. The model-touching conversion lives in
/// `PGN+GameRecord.swift`, keeping this file import-Foundation-only.
///
/// Sides carry the *resolved* identity (`Player.normalizedName` as `key`,
/// `Player.name` as display), not raw tags: identity was decided once by
/// `PGNStore.resolvePlayer(named:)`, and re-deriving it here would be a
/// second implementation waiting to drift. A nil side is a `"?"`
/// placeholder or a not-yet-backfilled row — either way, no player.
///
/// Deliberately lean: fields grow in M-prs.5 when `TagRule` starts
/// reading this projection, landing with the rules (and tests) that
/// consume them.
internal struct GameRecord: Sendable, Hashable {
    
    internal struct Side: Sendable, Hashable {
        /// `Player.normalizedName` — opaque to the cores.
        internal let key: String
        /// `Player.name` — first-seen display casing.
        internal let name: String
    }
    
    internal let white: Side?
    internal let black: Side?
    internal let result: GameResult
    /// The PGN convention: the last SAN carries `#`. No legality re-derivation.
    internal let endedInMate: Bool
    internal let date: Date?
    internal let importedAt: Date
    internal let contentHash: String
    
    // MARK: Chronology
    
    /// The one effective-date rule (D11′): undated games order by when
    /// they entered the Library.
    internal var effectiveDate: Date { date ?? importedAt }
    
    /// The recorded ordering contract for every fold over game records —
    /// `Glicko1.histories` sorts with this, and `PlayerStats` uses
    /// `effectiveDate` for first/last played. Ascending `effectiveDate`,
    /// tie-broken by `importedAt`, then `contentHash`: a rating fold's
    /// output is only as deterministic as its order, so the full chain
    /// down to a total tiebreak is the contract, not a nicety.
    internal static func chronologicalOrder(_ lhs: GameRecord, _ rhs: GameRecord) -> Bool {
        if lhs.effectiveDate != rhs.effectiveDate { return lhs.effectiveDate < rhs.effectiveDate }
        if lhs.importedAt != rhs.importedAt { return lhs.importedAt < rhs.importedAt }
        return lhs.contentHash < rhs.contentHash
    }
}
