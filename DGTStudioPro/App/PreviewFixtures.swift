import Foundation

/// Shared Players preview fixtures. Records, not memberwise stats: stats and ladder are
/// *derived* (D10′), so previews build through the same folds. **Not `#if DEBUG`** — previews
/// are stripped at link time, and the guard once broke six canvases in release schemes.
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
    
    /// A small rivalry set: a dominant player, an even pair, a provisional newcomer, and an
    /// unresolved seat (the "unknowns never inform" rule).
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
    
    /// Reaches the upper win bands `records()` never produces — 10+ / 5–9 / 1–4 / none at once.
    /// Built by appending games, not hand-writing stats: the folds stay in the loop.
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
    
    /// The shared ladder construction — one implementation, so a fold change shows in every canvas.
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

    /// A `CollectionViewOptions` on a wiped scratch suite. **Never `.standard`** — a canvas reading
    /// the developer's icon size renders wrong, and one writing it edits real preferences. Wiped on
    /// every call. `subject:` is required — defaulting it to nil hid the unlatched branch.
    @MainActor
    internal static func viewOptions(
        subject: CollectionViewOptionsSubject? = nil,
        iconSize: CGFloat? = nil,
        spacing: CGFloat? = nil
    ) -> CollectionViewOptions {
        let suite = "preview.collectionViewOptions"
        // `?? .standard` is unreachable in practice (`init?(suiteName:)` fails only for reserved
        // names) and preferred over `!` here: a trap in a preview helper takes the whole canvas down.
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)

        let options = CollectionViewOptions(defaults: defaults)
        options.activeSubject = subject
        if let iconSize { options.iconSize = iconSize }
        if let spacing { options.spacing = spacing }
        return options
    }
}
