import Foundation

/// The export seam (D17′/D24′) — the model's side of `PGNSerializer`, kept
/// out of the serializer so that stays a pure function of values with a
/// fixture-free suite. The `PGN+GameRecord` pattern.
extension PGN {
    
    /// This game in the DGT reference shape, ready to write.
    var pgnText: String {
        PGNSerializer.text(
            roster: RosterSummary(self),
            board: board,
            timeControl: timeControl,
            moves: moves
        )
    }
    
    /// The suggested filename — numbered by **library index** where present, batch position
    /// otherwise (D58′). This changes bytes D24′ pinned, deliberately: the pin never specified the
    /// ordinal's source, and the folder is the stricter reading.
    func exportFileName(index: Int) -> String {
        PGNSerializer.fileName(
            white: white,
            black: black,
            index: libraryIndex ?? index
        )
    }
}
