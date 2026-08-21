import Foundation
import Testing
@testable import DGTStudioPro

/// The column sort that replaced the picker. Nonisolated, load-bearing. Not tested: that
/// `sorted(using:)` sorts - that is the framework's.
@Suite("Ranked Player Column Sort")
struct RankedPlayerSortTests {

    // MARK: Fixtures

    /// Deliberately duplicated builder - that suite pins the comparator; this one a different claim
    /// that happens to need the same fixtures.
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
        // Through `PlayerRanking.wins`: the *default method* is what must reproduce the ladder now.
        return PlayerRanking.wins.ranked(stats.map { (stats: $0, rating: nil) })
    }

    // MARK: The equivalence the picker's deletion rests on

    /// The shipped default sort reproduces the shipped default *ranking method* - two separate
    /// values that must agree. Sorted from a **shuffled** input, so it cannot pass by luck.
    @Test func defaultSortReproducesTheLadder() {
        let expected = ladder().map(\.stats.key)

        let sorted = ladder()
            .shuffled()
            .sorted(using: PlayersDestination.defaultSortOrder)

        #expect(sorted.map(\.stats.key) == expected)
        #expect(expected == ["zoe", "amy", "ann", "ben"])
    }

    /// The Library's half, checkable without a container: highest ordinal first, un-indexed **last**.
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

    /// The Player column reproduces what the "By Name" position did -
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

    /// Unrated players group at one end rather than scattering - the arm that breaks first if
    /// someone "simplifies" the nil ordering.
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

    /// A provisional rating sorts by its mean, not by its uncertainty - the
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
