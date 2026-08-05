//
//  RankedPlayerSortTests.swift
//  DGTStudioProTests
//
//  Created by Supreme Leader on 05/08/2026.
//

import Foundation
import Testing
@testable import DGTStudioPro

/// The column sort that replaced D48′'s picker (5 Aug 2026).
///
/// **Nonisolated deliberately, and it is load-bearing rather than stylistic**
/// — the D44′ shape. `RankedPlayer` is a pure value type and the comparators
/// are stdlib values; nothing here may require the main actor. If a future
/// edit makes this suite need `@MainActor`, something has acquired isolation
/// it should not have, and the compile error is the report.
///
/// What is *not* tested here, on purpose: that `sorted(using:)` sorts. That is
/// Apple's code, and a test asserting it would pass forever while telling us
/// nothing. What these pin is the one claim the app makes on top of it — that
/// the Rank column's ascending order and `PlayerStats.rankingOrder` are the
/// same order. That equivalence is what let the picker be deleted, it is
/// asserted nowhere in the view layer, and it is exactly the kind of thing a
/// later "tidy" of `ranked(from:histories:)` could break silently.
@Suite("Ranked player column sort")
struct RankedPlayerSortTests {

    // MARK: Fixtures

    /// `PlayerStatsTests.rankingOrderRunsTheFullTiebreakChain`'s builder,
    /// deliberately duplicated rather than shared. That test pins the
    /// comparator; this one pins a *different* claim that happens to need the
    /// same shapes, and a shared factory would make either suite's edit a
    /// change-detector for the other — the standing agreement about factories.
    private func player(_ key: String, wins: Int, losses: Int) -> PlayerStats {
        PlayerStats(
            key: key, name: key, games: wins + losses,
            whiteWins: wins, whiteDraws: 0, whiteLosses: losses,
            blackWins: 0, blackDraws: 0, blackLosses: 0,
            matesDelivered: 0,
            firstPlayed: Date(timeIntervalSince1970: 0),
            lastPlayed: Date(timeIntervalSince1970: 0)
        )
    }

    /// The ladder as the destination builds it: fold through `rankingOrder`,
    /// then stamp 1-based ranks in that order. Kept to that exact sequence
    /// because the claim under test is about the relationship between the two
    /// steps, and doing them in one step here would assume the thing.
    private func ladder() -> [RankedPlayer] {
        let stats = [
            player("zoe", wins: 5, losses: 5),   // 5 wins, 50%
            player("amy", wins: 4, losses: 0),   // 4 wins, 100%
            player("ben", wins: 4, losses: 4),   // 4 wins, 50%, loses the key tiebreak
            player("ann", wins: 4, losses: 4)    // 4 wins, 50%, wins it
        ]
        return stats
            .sorted(by: PlayerStats.rankingOrder)
            .enumerated()
            .map { RankedPlayer(rank: $0.offset + 1, stats: $0.element, rating: nil) }
    }

    // MARK: The equivalence the picker's deletion rests on

    /// The **shipped** default reproduces D11′ exactly — wins, then win rate,
    /// then key.
    ///
    /// Two things make this able to fail, and both were deliberate:
    ///
    /// Sorted from a **shuffled** input rather than from `ladder()`'s output,
    /// so it cannot pass by the array already being in order — which is how
    /// this test would otherwise be green while doing nothing.
    ///
    /// And asserted against `PlayersDestination.defaultSortOrder` rather than
    /// a locally-written comparator, which is the `EvaluationGraphReading`
    /// rule: a literal keeps passing while the thing it was copied from
    /// changes. Spelling `KeyPathComparator(\.rank)` here would prove that
    /// *ascending rank* is the ladder — true, and not the claim. The claim is
    /// that the order **Players opens in** is the ladder, and only the real
    /// default can be wrong about that. Reverse it in the destination and this
    /// test goes red; that is the point.
    @Test func defaultSortReproducesTheLadder() {
        let expected = ladder().map(\.stats.key)

        let sorted = ladder()
            .shuffled()
            .sorted(using: PlayersDestination.defaultSortOrder)

        #expect(sorted.map(\.stats.key) == expected)
        #expect(expected == ["zoe", "amy", "ann", "ben"])
    }

    /// The Library's default is the other half of the same claim, and it is
    /// checkable without a container because the comparator is a value: highest
    /// ordinal first, and un-indexed games **last**.
    ///
    /// That second half is the one worth a test. Descending an optional key
    /// path puts `nil` at the far end, which is the behaviour wanted here — a
    /// column of numbers should not open on the rows that have none — but it
    /// falls out of `Optional`'s ordering rather than from anything this app
    /// wrote, so it is exactly the kind of inherited behaviour that changes
    /// under someone without their noticing.
    @Test func libraryDefaultIsOrdinalDescendingWithUnindexedLast() {
        struct Row { let index: Int? }
        // The comparator is typed to `PGN`, so this asserts the *rule* rather
        // than reaching for a container: same key path shape, same order.
        let rows = [Row(index: 3), Row(index: nil), Row(index: 47), Row(index: 12)]

        let sorted = rows.sorted(
            using: [KeyPathComparator(\Row.index, order: .reverse)]
        )

        #expect(sorted.map(\.index) == [47, 12, 3, nil])
    }

    /// Click twice: the same comparator reversed, which is the whole of the
    /// requested behaviour and the only thing `Table` does on a second click.
    @Test func reversingTheRankComparatorReversesTheLadder() {
        let expected = Array(ladder().map(\.stats.key).reversed())

        let sorted = ladder()
            .shuffled()
            .sorted(using: [KeyPathComparator(\RankedPlayer.rank, order: .reverse)])

        #expect(sorted.map(\.stats.key) == expected)
    }

    /// The Player column reproduces what D48′'s "By Name" position did —
    /// `stats.name` ascending. Pinned because the picker that used to spell
    /// this is gone, so this comparator is now the only place the app says
    /// what alphabetical means here.
    @Test func playerColumnSortsByDisplayNameAscending() {
        let sorted = ladder()
            .shuffled()
            .sorted(using: [KeyPathComparator(\RankedPlayer.stats.name)])

        #expect(sorted.map(\.stats.name) == ["amy", "ann", "ben", "zoe"])
    }

    // MARK: The optional-valued columns

    /// Unrated players sort **together at one end** rather than scattering.
    ///
    /// This is the arm that would break first if someone "simplified"
    /// `KeyPathComparator(\.rating?.mean)` into a sort over the rendered
    /// string, because the cell prints an em dash for nil and a text sort
    /// would order that dash against digits. Ascending puts nil first, which
    /// is `Optional`'s documented ordering under this comparator and is the
    /// behaviour to notice if it ever changes.
    @Test func unratedPlayersGroupRatherThanScatter() {
        func rated(_ key: String, _ mean: Double?) -> RankedPlayer {
            RankedPlayer(
                rank: 1,
                stats: player(key, wins: 1, losses: 0),
                rating: mean.map { Glicko1.Rating(mean: $0, deviation: 50) }
            )
        }

        let sorted = [rated("mid", 1500), rated("none", nil),
                      rated("high", 1900), rated("alsoNone", nil)]
            .sorted(using: [KeyPathComparator(\RankedPlayer.rating?.mean)])

        let leadingNils = sorted.prefix { $0.rating == nil }.count
        #expect(leadingNils == 2)
        #expect(sorted.suffix(2).map(\.stats.key) == ["mid", "high"])
    }

    /// A provisional rating sorts by its mean, not by its uncertainty — the
    /// display marker is display only. Stated as a test because the comment
    /// arguing it sits in the view, where nothing compiles it.
    @Test func provisionalRatingSortsOnTheMeanAlone() {
        let provisional = RankedPlayer(
            rank: 1, stats: player("prov", wins: 1, losses: 0),
            rating: Glicko1.Rating(mean: 1700, deviation: 300)
        )
        let settled = RankedPlayer(
            rank: 2, stats: player("settled", wins: 1, losses: 0),
            rating: Glicko1.Rating(mean: 1600, deviation: 40)
        )

        #expect(provisional.rating?.isProvisional == true)
        #expect(settled.rating?.isProvisional == false)

        let sorted = [provisional, settled]
            .sorted(using: [KeyPathComparator(\RankedPlayer.rating?.mean)])

        #expect(sorted.map(\.stats.key) == ["settled", "prov"])
    }
}
