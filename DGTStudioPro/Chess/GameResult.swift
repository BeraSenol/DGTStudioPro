/// The four PGN result spellings. Filed in `Chess/` since 26 Aug 2026 (M18) - it was declared
/// at the top of `PGN/PGN.swift`, but five of its use sites are `Chess/MovetextEdit.swift` and
/// the chess core decides results before the store ever sees one; file it by meaning. The raw
/// values are the PGN standard's and ride the content hash (`result.rawValue` is a hash input),
/// so a respelling un-dedupes the archive against itself.
enum GameResult: String, CaseIterable, Codable, Sendable {
    case whiteWins = "1-0"
    case blackWins = "0-1"
    case draw      = "1/2-1/2"
    case ongoing   = "*"
}
