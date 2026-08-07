import Foundation

/// Shared preview fixtures for the Players surfaces.
///
/// Why records rather than memberwise `PlayerStats`: the stats and ladder
/// are *derived* (D10′), so previews build them through the same pure folds
/// production uses — a change to the comparator or the Glicko fold shows up
/// in the canvas instead of silently diverging from a hand-written fixture.
///
/// **Not `#if DEBUG`, and the guard's removal on 6 Aug 2026 is the point.**
/// This file carried one, with the reason "keeps it out of the shipping
/// binary" — and it broke every Release build in the project's history,
/// which is to say the first one. `#Preview` **compiles in Release**; it is
/// stripped at link time, not excluded at compile time. So six preview blocks
/// across the Players surfaces referenced a symbol that did not exist there,
/// and nothing caught it because ⌘U and ⌘R both build Debug and Profile (⌘I)
/// had never been run.
///
/// The guard was optimising for a shipping binary this app does not have —
/// one person, one Mac, no release, no App Store, which is a standing input to
/// every trade here. Removing it costs a few hundred bytes nobody ships and
/// fixes the class rather than the instance. **The rule that replaces it: no
/// symbol a `#Preview` touches may be `#if DEBUG`, unless every preview
/// touching it is guarded too.** This was the app target's only such region.
internal enum PreviewFixtures {
    
    /// Fixed epoch — previews must not shift with wall-clock time.
    private static func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: 1_720_000_000 + Double(offset) * 86_400)
    }
    
    private static func side(_ name: String) -> GameRecord.Side {
        GameRecord.Side(key: name.lowercased(), name: name)
    }
    
    private static func game(
        _ white: String,
        _ black: String,
        _ result: GameResult,
        day offset: Int,
        round: Int? = nil,
        mate: Bool = false
    ) -> GameRecord {
        GameRecord(
            white: side(white),
            black: side(black),
            result: result,
            endedInMate: mate,
            date: day(offset),
            importedAt: day(offset),
            contentHash: "\(white)-\(black)-\(offset)",
            event: "Club Championship",
            site: "Antwerp",
            name: "\(white) vs \(black)",
            round: round,
            plyCount: 40 + offset,
            hasAnalysis: offset.isMultiple(of: 2)
        )
    }
    
    /// A small rivalry set: one dominant player, one even pair, one
    /// newcomer with a single game (provisional RD), and an unresolved
    /// seat to exercise the "unknowns never inform" rule.
    internal static func records() -> [GameRecord] {
        [
            game("Bera", "Lorenzo", .whiteWins, day: 1, round: 1),
            game("Bera", "Lorenzo", .blackWins, day: 3, round: 2, mate: true),
            game("Bera", "Reinaud", .whiteWins, day: 5, round: 1),
            game("Lorenzo", "Reinaud", .draw, day: 7, round: 3),
            game("Reinaud", "Bera", .draw, day: 9, round: 2),
            game("Bera", "Novak", .whiteWins, day: 11, mate: true),
            game("Lorenzo", "Bera", .whiteWins, day: 13, round: 4),
            game("Reinaud", "Lorenzo", .blackWins, day: 15),
            GameRecord(
                white: side("Bera"), black: nil,
                result: .whiteWins, endedInMate: false,
                date: day(17), importedAt: day(17),
                contentHash: "unresolved-seat"
            )
        ]
    }
    
    internal static func playerStats() -> [PlayerStats] {
        PlayerStats.index(of: records()).sorted(by: PlayerStats.rankingOrder)
    }
    
    /// A larger set that reaches the upper win bands. `records()` only ever
    /// produces two of `PlayersColumnsView`'s four win brackets (D48′), so a boundary
    /// could be wrong in both directions unseen; this adds a dominant player
    /// on twelve wins and a mid-tier one on six, giving 10+ / 5–9 / 1–4 /
    /// none all at once. Built by appending *games*, not by hand-writing
    /// stats — the folds stay in the loop, same reason as the type comment.
    internal static func deepRecords() -> [GameRecord] {
        var records = self.records()
        for offset in 0..<12 {
            records.append(game("Vasil", "Novak", .whiteWins, day: 20 + offset))
        }
        for offset in 0..<6 {
            records.append(game("Ines", "Tomas", .whiteWins, day: 40 + offset))
        }
        return records
    }
    
    /// The ladder construction both fixtures share: rank by the D11′
    /// comparator, then attach each player's latest Glicko rating. One
    /// implementation so a change to either fold shows up in every canvas.
    private static func ladder(from records: [GameRecord]) -> [RankedPlayer] {
        let histories = Glicko1.histories(from: records)
        return PlayerStats.index(of: records)
            .sorted(by: PlayerStats.rankingOrder)
            .enumerated()
            .map { offset, stats in
                RankedPlayer(
                    rank: offset + 1,
                    stats: stats,
                    rating: histories[stats.key]?.last?.rating
                )
            }
    }
    
    internal static func rankedPlayers() -> [RankedPlayer] {
        ladder(from: records())
    }
    
    internal static func deepRankedPlayers() -> [RankedPlayer] {
        ladder(from: deepRecords())
    }
    
    internal static func topStats() -> PlayerStats { playerStats()[0] }

    /// A `CollectionViewOptions` on a wiped scratch suite.
    ///
    /// **Never `.standard`**, and here that rule has teeth in both
    /// directions. A canvas *reading* the developer's own icon size renders a
    /// layout nobody chose to test — the M1 ambient-`UserDefaults` leak. A
    /// canvas *writing* one is worse: these previews drive a live slider, so a
    /// canvas bound to the standard suite would edit the running app's
    /// preferences from Xcode.
    ///
    /// Wiped on every call rather than merely named, so a preview cannot
    /// inherit what the last one left behind — `UITestSeed.scratchDefaults`'
    /// discipline, outliving the suite it was written for (D51′).
    ///
    /// **`subject:` is not optional-by-accident, and defaulting it to nil was a
    /// defect rather than a convenience.** `activeSubject` is deliberately
    /// unpersisted session state (see its declaration), so a fixture built from
    /// a scratch suite has none — which meant the *Library — Icons* and
    /// *Library — Gallery* previews both rendered the **No Collection in
    /// Front** arm, identically to the preview named for it. Three canvases,
    /// one branch, and each read as evidence that its own branch was checked.
    ///
    /// Found 7 Aug 2026 while restyling the sliders those previews are the only
    /// witness for. The D51′ lesson in a new place: a preview witnessing
    /// something the view is not showing is worse than no preview.
    ///
    /// `iconSize` / `spacing` are overridable so a canvas can sit at an extreme
    /// — the label's width behaviour across a digit boundary is visual and
    /// nothing else can see it.
    @MainActor
    internal static func viewOptions(
        subject: CollectionViewOptionsSubject? = nil,
        iconSize: CGFloat? = nil,
        spacing: CGFloat? = nil
    ) -> CollectionViewOptions {
        let suite = "preview.collectionViewOptions"
        // A suite that will not open is a broken canvas, not a broken app, and
        // falling back to `.standard` here is exactly the leak above. An
        // in-memory volatile domain has no persistence to leak into.
        let defaults = UserDefaults(suiteName: suite) ?? UserDefaults(suiteName: nil) ?? .standard
        defaults.removePersistentDomain(forName: suite)

        let options = CollectionViewOptions(defaults: defaults)
        options.activeSubject = subject
        if let iconSize { options.iconSize = iconSize }
        if let spacing { options.spacing = spacing }
        return options
    }
}
