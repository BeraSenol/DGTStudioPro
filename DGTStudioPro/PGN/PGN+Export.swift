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
    
    /// The suggested filename for this game, numbered by its **library index**
    /// where it has one and by its position in this export otherwise (D58′).
    ///
    /// The fallback is what the parameter used to be unconditionally, and the
    /// asymmetry is the decision: a game that came from a numbered file goes
    /// back out under the number it came in with, so exporting and re-importing
    /// is a round trip through the filesystem rather than a renumbering of it.
    /// A game with no ordinal — pasted text, an unnumbered folder, anything
    /// imported before D58′ — still has to be *called* something, and its
    /// position in the batch is the only number available.
    ///
    /// **This changes bytes D24′ pinned**, and does so deliberately: that pin
    /// reads the reference files as the authority on shape, and the shape has
    /// an ordinal in it whose *source* the pin never specified. Reading it off
    /// the folder is the strictest available reading of "where the standard and
    /// the files disagree, the files win". The standing open item about whether
    /// the numbering matches DGT's own convention is unaffected — it was and
    /// remains unconfirmed.
    ///
    /// One consequence worth naming rather than discovering: a multi-game
    /// export can now write non-contiguous filenames (47, 48, 91) or repeat one,
    /// because library indices are neither gapless nor unique. That is the
    /// folder's own state being reflected rather than a defect — D32′ already
    /// decided that a same-named file is overwritten silently.
    internal func exportFileName(index: Int) -> String {
        PGNSerializer.fileName(
            white: white,
            black: black,
            index: libraryIndex ?? index
        )
    }
}
