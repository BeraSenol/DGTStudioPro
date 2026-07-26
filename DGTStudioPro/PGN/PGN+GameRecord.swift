//
//  PGN+GameRecord.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import Foundation

/// The projection seam (D10′): the only place the M-prs cores' input
/// touches the model layer, split out — the `LiveGame+Draft` pattern —
/// so `GameRecord` itself stays a passive pure value with no SwiftData
/// import. A pure read; call sites map `@Query` results
/// (`games.map(\.gameRecord)`) after the player-link backfill has run.
extension PGN {
    
    /// The one effective-date rule (D11′), at the model. `GameRecord` owns it
    /// for the pure folds, but a view sorting *models* needs the same answer,
    /// and `PlayersDestination` re-derived `date ?? importedAt` inline — the
    /// second implementation the rule exists to prevent, under a comment that
    /// named the rule it wasn't using.
    internal var effectiveDate: Date { date ?? importedAt }
    
    internal var gameRecord: GameRecord {
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
            hasAnalysis: !evaluations.isEmpty,
            isTimed: timeControl != nil
        )
    }
}
