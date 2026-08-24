import Foundation
import SwiftData

/// Shared Library preview fixtures - the `PGN` half of `PreviewFixtures`. One set for every
/// Library canvas, so a fix lands in all of them rather than in one of five.
///
/// **A separate type on purpose.** `PreviewFixtures` is Foundation-only and builds everything
/// through the pure folds, which is what makes a Players canvas a witness that the folds still
/// work; a `@Model` fixture in that file would cost it the property.
///
/// **Not `#if DEBUG`** - previews compile in Release and are stripped at link time, so the guard
/// once broke six canvases in release schemes (`PreviewFixtures` carries the full account).
enum LibraryPreviewFixtures {
    
    /// A calendar day as a `Date`, in **UTC**.
    ///
    /// Deliberately not a second `"yyyy.MM.dd"` `DateFormatter`: `PGNParser` owns that spelling and
    /// its UTC pin is load-bearing for parse → `hashDateString` round-tripping. Components against a
    /// UTC calendar need no formatter at all, which is the only way not to have two.
    private static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        // `?? .distantPast` rather than `!`: a trap in a fixture takes the whole canvas down, and a
        // wrong-looking date is a visible failure where a dead canvas is a silent one.
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }
    
    /// The canonical set, in one fixed order - seven games over six columns at the default icon
    /// size, so a grid canvas gets a partial second row and wrap is exercisable.
    ///
    /// **The order is the contract**, not the count: every caller takes a prefix, so inserting in
    /// the middle silently re-cuts four canvases. Append.
    static func games() -> [PGN] {
        [
            PGN(event: "World Championship", site: "Dubai", round: 11,
                white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian", result: .whiteWins),
            PGN(event: "Tata Steel Masters", site: "Wijk aan Zee", round: 7,
                white: "Giri, Anish", black: "Caruana, Fabiano", result: .draw),
            PGN(event: "Norway Chess", site: "Stavanger", round: 3,
                white: "Firouzja, Alireza", black: "Ding, Liren", result: .blackWins),
            PGN(event: "Candidates Tournament", site: "Madrid", round: 14,
                white: "Nepomniachtchi, Ian", black: "Ding, Liren", result: .ongoing),
            PGN(event: "Candidates Tournament", site: "Madrid", round: 2,
                white: "Caruana, Fabiano", black: "Firouzja, Alireza", result: .draw),
            PGN(event: "Tata Steel Masters", site: "Wijk aan Zee", round: 1,
                white: "Ding, Liren", black: "Giri, Anish", result: .whiteWins),
            PGN(event: "Norway Chess", site: "Stavanger", round: 9,
                white: "Carlsen, Magnus", black: "Caruana, Fabiano", result: .whiteWins)
        ]
    }
    
    /// The first `count` of `games()` - fresh rows each call, never a shared array sliced twice.
    /// Clamped rather than trapping, for the reason `day(_:_:_:)` gives.
    static func games(_ count: Int) -> [PGN] {
        Array(games().prefix(max(0, count)))
    }
    
    /// The facts-row set for the columns detail: **one** game with every derived row populated
    /// (date, round, movetext, time control), two dated but moveless, and one neither - so a single
    /// canvas shows each fact row's value branch and its placeholder branch.
    static func datedGames() -> [PGN] {
        [
            // The only row where every derived fact has a value.
            PGN(event: "World Championship", site: "Dubai",
                date: day(2021, 12, 10),
                round: 11,
                white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian",
                moves: ["e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#"],
                result: .whiteWins,
                timeControl: "40/7200"),
            PGN(event: "Tata Steel Masters", site: "Wijk aan Zee",
                date: day(2024, 1, 20),
                round: 7,
                white: "Giri, Anish", black: "Caruana, Fabiano", result: .draw),
            PGN(event: "Norway Chess", site: "Stavanger",
                date: day(2023, 6, 3),
                round: 3,
                white: "Firouzja, Alireza", black: "Ding, Liren", result: .blackWins),
            // Undated as well as moveless, so Date's placeholder branch renders too.
            PGN(event: "Norway Chess", site: "Stavanger",
                date: nil,
                round: 5,
                white: "Carlsen, Magnus", black: "Firouzja, Alireza", result: .whiteWins)
        ]
    }
}
