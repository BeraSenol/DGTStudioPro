//
//  PGN+Export.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/07/2026.
//

import Foundation

/// The export seam (D17′/D24′) — the model's side of `PGNSerializer`, kept
/// out of the serializer so that stays a pure function of values with a
/// fixture-free suite. The `PGN+GameRecord` pattern.
extension PGN {
    
    /// This game in the DGT reference shape, ready to write.
    internal var pgnText: String {
        PGNSerializer.text(
            roster: RosterSummary(self),
            board: board,
            timeControl: timeControl,
            moves: moves
        )
    }
    
    /// The suggested filename for this game at `index` (1-based) in an export.
    internal func exportFileName(index: Int) -> String {
        PGNSerializer.fileName(white: white, black: black, index: index)
    }
}
