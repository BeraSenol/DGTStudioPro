import Foundation

/// The projection seam - the only place the cores' input touches the model layer.
extension PGN {
    
    /// The one effective-date rule at the model - a view sorting *models* needs the same
    /// answer the pure folds use.
    var effectiveDate: Date { date ?? importedAt }
    
    var gameRecord: GameRecord {
        GameRecord(
            white: whitePlayer.map { GameRecord.Side(key: $0.normalizedName, name: $0.name) },
            black: blackPlayer.map { GameRecord.Side(key: $0.normalizedName, name: $0.name) },
            result: result,
            endedInMate: moves.last?.hasSuffix("#") == true,
            date: date,
            importedAt: importedAt,
            contentHash: contentHash,
            event: event,
            site: site,
            name: name,
            round: round,
            plyCount: moves.count,
            // `hasScoredPly`, not `!evaluations.isEmpty` - the last door on the old spelling.
            hasAnalysis: hasScoredPly,
            isTimed: timeControl != nil,
            opening: opening,
            specialCheckmate: specialCheckmate
        )
    }
}
