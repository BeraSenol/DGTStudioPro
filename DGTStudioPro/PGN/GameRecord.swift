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
/// Grown in M-prs.5: the Library-metadata fields exist because `TagRule`
/// reads them, and they landed with the rules and tests that consume
/// them.
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
    
    // The M-prs.5 growth, as promised in the type comment: the fields
    // `TagRule` reads. Trailing with defaults so the slice-2 fixtures and
    // call order stay source-stable; the projection passes every field
    // explicitly, so the defaults are fixture ergonomics, not hiding
    // places.
    internal let event: String
    internal let site: String
    internal let name: String
    internal let round: Int?
    internal let plyCount: Int
    internal let hasAnalysis: Bool
    internal let isTimed: Bool
    
    internal init(
        white: Side?,
        black: Side?,
        result: GameResult,
        endedInMate: Bool,
        date: Date?,
        importedAt: Date,
        contentHash: String,
        event: String = "",
        site: String = "",
        name: String = "",
        round: Int? = nil,
        plyCount: Int = 0,
        hasAnalysis: Bool = false,
        isTimed: Bool = false
    ) {
        self.white = white
        self.black = black
        self.result = result
        self.endedInMate = endedInMate
        self.date = date
        self.importedAt = importedAt
        self.contentHash = contentHash
        self.event = event
        self.site = site
        self.name = name
        self.round = round
        self.plyCount = plyCount
        self.hasAnalysis = hasAnalysis
        self.isTimed = isTimed
    }
    
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
