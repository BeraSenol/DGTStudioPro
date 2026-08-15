import Foundation

/// A Library game projected to the pure value the cores consume — `PlayerStats` and
/// `Glicko1` never touch `@Model`s. Sides are the *resolved* links, never raw tags: `"?"` and
/// unbackfilled rows are both "no player".
struct GameRecord: Sendable, Hashable {
    
    struct Side: Sendable, Hashable {
        /// `Player.normalizedName` — opaque to the cores.
        let key: String
        /// `Player.name` — first-seen display casing.
        let name: String
    }
    
    let white: Side?
    let black: Side?
    let result: GameResult
    /// The PGN convention: the last SAN carries `#`. No legality re-derivation.
    let endedInMate: Bool
    let date: Date?
    let importedAt: Date
    let contentHash: String
    
    // The fields `TagRule` reads; trailing defaults are fixture ergonomics — the projection passes
    // every field explicitly.
    let event: String
    let site: String
    let name: String
    let round: Int?
    let plyCount: Int
    let hasAnalysis: Bool
    let isTimed: Bool

    // The *stored* classification, never the moves it was derived from — movetext on records would
    // make every fold carry it for nothing.
    let opening: ECOOpening?
    let specialCheckmate: SpecialCheckmate?

    init(
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
        isTimed: Bool = false,
        opening: ECOOpening? = nil,
        specialCheckmate: SpecialCheckmate? = nil
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
        self.opening = opening
        self.specialCheckmate = specialCheckmate
    }
    
    // MARK: Chronology
    
    /// The one effective-date rule: undated games order by when
    /// they entered the Library.
    var effectiveDate: Date { date ?? importedAt }
    
    /// The recorded ordering contract for every fold: `effectiveDate` ↑, then `importedAt`, then
    /// `contentHash` — a fold's output is only as deterministic as its order, so the chain down to
    /// a total tiebreak is the contract.
    static func chronologicalOrder(_ lhs: GameRecord, _ rhs: GameRecord) -> Bool {
        if lhs.effectiveDate != rhs.effectiveDate { return lhs.effectiveDate < rhs.effectiveDate }
        if lhs.importedAt != rhs.importedAt { return lhs.importedAt < rhs.importedAt }
        return lhs.contentHash < rhs.contentHash
    }
}
