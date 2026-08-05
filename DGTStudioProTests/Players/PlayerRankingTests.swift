//
//  PlayerRankingTests.swift
//  DGTStudioProTests
//
//  Created by Supreme Leader on 05/08/2026.
//

import Foundation
import Testing
@testable import DGTStudioPro

/// The three ranking methods (D62′).
///
/// **Nonisolated**, matching its subject: `PlayerRanking` is a pure value type
/// over two other pure value types, and a suite that needed the main actor
/// would mean one of the three had stopped being pure.
///
/// What each test is really pinning is a *product* claim rather than an
/// arithmetic one — which player a reader sees at rank 1, and why — so the
/// fixtures are built to make the three methods disagree. A fixture where they
/// all agree would pass under any comparator and prove nothing.
@Suite("Player ranking methods")
struct PlayerRankingTests {

    // MARK: Fixtures

    private func player(_ key: String, wins: Int, losses: Int) -> PlayerStats {
        PlayerStats(
            key: key, name: key, games: wins + losses,
            whiteWins: wins, whiteDraws: 0, whiteLosses: losses,
            blackWins: 0, blackDraws: 0, blackLosses: 0,
            matesDelivered: 0, specialMatesDelivered: 0,
            firstPlayed: Date(timeIntervalSince1970: 0),
            lastPlayed: Date(timeIntervalSince1970: 0)
        )
    }

    private func entry(
        _ key: String, wins: Int, losses: Int, rating: Double?
    ) -> PlayerRanking.Entry {
        (
            stats: player(key, wins: wins, losses: losses),
            rating: rating.map { Glicko1.Rating(mean: $0, deviation: 50) }
        )
    }

    /// Three players chosen so no two methods agree on the leader.
    ///
    /// - `grinder` has the most **wins** (8) at a middling rate.
    /// - `sharp` has the best **win rate** (100%) on three games.
    /// - `strong` has the best **rating** while leading neither other column.
    private func disagreeingField() -> [PlayerRanking.Entry] {
        [
            entry("grinder", wins: 8, losses: 8, rating: 1500),
            entry("sharp",   wins: 3, losses: 0, rating: 1550),
            entry("strong",  wins: 5, losses: 3, rating: 1700)
        ]
    }

    // MARK: Each method leads with its own column

    @Test func winsRanksTheMostWinsFirst() {
        let ladder = PlayerRanking.wins.ranked(disagreeingField())
        #expect(ladder.first?.stats.key == "grinder")
    }

    @Test func winRateRanksTheBestPercentageFirst() {
        let ladder = PlayerRanking.winRate.ranked(disagreeingField())
        #expect(ladder.first?.stats.key == "sharp")
    }

    @Test func ratingRanksTheHighestRatedFirst() {
        let ladder = PlayerRanking.rating.ranked(disagreeingField())
        #expect(ladder.first?.stats.key == "strong")
    }

    /// The three genuinely disagree on this field, which is what makes the
    /// three assertions above mean something rather than coincide.
    @Test func theThreeMethodsProduceThreeDifferentLeaders() {
        let leaders = PlayerRanking.allCases.map {
            $0.ranked(disagreeingField()).first?.stats.key
        }
        #expect(Set(leaders.compactMap { $0 }).count == 3)
    }

    // MARK: `.wins` is D11′, not a copy of it

    /// Asserted against `PlayerStats.rankingOrder` itself rather than a
    /// hand-written expected order — the `EvaluationGraphReading` rule. A
    /// literal would keep passing if D11′'s chain changed and this case did
    /// not, which is the divergence delegation exists to prevent.
    @Test func winsReproducesTheD11Ladder() {
        let entries = disagreeingField()
        let expected = entries.map(\.stats)
            .sorted(by: PlayerStats.rankingOrder)
            .map(\.key)

        #expect(PlayerRanking.wins.ranked(entries).map(\.stats.key) == expected)
    }

    // MARK: Unrated players

    /// A nil rating is "no opinion", not a low one, so it ranks **last** —
    /// never sorted as if it were the 1500 starting value, which would drop an
    /// unplayed player into the middle of the ladder ahead of real players who
    /// have earned less.
    @Test func unratedPlayersRankLastUnderRating() {
        let entries = [
            entry("unrated", wins: 9, losses: 0, rating: nil),
            entry("weak",    wins: 1, losses: 9, rating: 1200),
            entry("strong",  wins: 5, losses: 1, rating: 1700)
        ]

        let ladder = PlayerRanking.rating.ranked(entries)

        #expect(ladder.map(\.stats.key) == ["strong", "weak", "unrated"])
    }

    /// Two unrated players still order deterministically, by the same wins-then
    /// key chain everything else falls through to.
    @Test func twoUnratedPlayersStillOrderDeterministically() {
        let entries = [
            entry("bravo", wins: 1, losses: 0, rating: nil),
            entry("alpha", wins: 4, losses: 0, rating: nil)
        ]
        #expect(PlayerRanking.rating.ranked(entries).map(\.stats.key) == ["alpha", "bravo"])
    }

    // MARK: Totality — D10′'s rule

    /// Every method bottoms out in a tiebreak that cannot tie, so the ladder is
    /// reproducible across launches.
    ///
    /// Sorted from a **shuffled** input and compared against a second shuffle,
    /// because an order that happened to be stable for one arrangement proves
    /// nothing about the comparator.
    @Test(arguments: PlayerRanking.allCases)
    func everyMethodIsTotal(_ method: PlayerRanking) {
        // Identical in every ranked column but the key — the only thing left to
        // separate them.
        let entries = ["delta", "alpha", "charlie", "bravo"].map {
            entry($0, wins: 3, losses: 3, rating: 1500)
        }

        let first = method.ranked(entries.shuffled()).map(\.stats.key)
        let second = method.ranked(entries.shuffled()).map(\.stats.key)

        #expect(first == second)
        #expect(first == ["alpha", "bravo", "charlie", "delta"])
    }

    // MARK: Ranks

    /// Ranks are 1-based, dense and distinct — the property the badge and
    /// `AccessibilityID.rankingRow` both assume.
    @Test(arguments: PlayerRanking.allCases)
    func ranksAreDenseAndOneBased(_ method: PlayerRanking) {
        let ladder = method.ranked(disagreeingField())
        #expect(ladder.map(\.rank) == [1, 2, 3])
    }

    @Test func anEmptyFieldRanksToNothing() {
        #expect(PlayerRanking.wins.ranked([]).isEmpty)
    }
}
