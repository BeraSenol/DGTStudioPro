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
    /// The asymmetry is the decision: a game that came from a numbered file goes
    /// back out under the number it came in with, so export → re-import is a
    /// round trip through the filesystem rather than a renumbering of it. A game
    /// with no ordinal still has to be *called* something, and its position in
    /// the batch is the only number available.
    ///
    /// **This changes bytes D24′ pinned**, deliberately: that pin reads the
    /// reference files as the authority on shape, and the shape has an ordinal
    /// whose *source* the pin never specified. Reading it off the folder is the
    /// strictest reading of "where the standard and the files disagree, the
    /// files win".
    ///
    /// Named consequence: a multi-game export can write non-contiguous filenames
    /// (47, 48, 91) or repeat one, because library indices are neither gapless
    /// nor unique. That is the folder's own state reflected rather than a defect
    /// — D32′ already decided a same-named file is overwritten silently.
    internal func exportFileName(index: Int) -> String {
        PGNSerializer.fileName(
            white: white,
            black: black,
            index: libraryIndex ?? index
        )
    }
}
