//
//  PreviewFixtures.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 23/07/2026.
//

#if DEBUG
import Foundation

/// Shared preview fixtures for the Players/Rankings surfaces.
///
/// Why records rather than memberwise `PlayerStats`: the stats and ladder
/// are *derived* (D10′), so previews build them through the same pure folds
/// production uses — a change to the comparator or the Glicko fold shows up
/// in the canvas instead of silently diverging from a hand-written fixture.
/// `#if DEBUG` keeps it out of the shipping binary.
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
    
    internal static func rankedPlayers() -> [RankedPlayer] {
        let histories = Glicko1.histories(from: records())
        return playerStats().enumerated().map { offset, stats in
            RankedPlayer(
                rank: offset + 1,
                stats: stats,
                rating: histories[stats.key]?.last?.rating
            )
        }
    }
    
    internal static func topStats() -> PlayerStats { playerStats()[0] }
}
#endif
