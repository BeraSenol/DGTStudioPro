import Testing
import Foundation
@testable import DGTStudioPro

/// The counting rules of pinned (nonisolated - pure fold):
/// per-color splits, ongoing-counts-as-appearance-only, mate credit to
/// the winner, effective-date first/last, unresolved sides ignored, and
/// the recorded ladder comparator with its full tiebreak chain.
@Suite("Player Stats")
struct PlayerStatsTests {
    
    // MARK: Helpers
    
    private let alice = GameRecord.Side(key: "alice", name: "Alice")
    private let bob   = GameRecord.Side(key: "bob",   name: "Bob")
    
    private func record(
        white: GameRecord.Side?,
        black: GameRecord.Side?,
        result: GameResult,
        endedInMate: Bool = false,
        specialCheckmate: SpecialCheckmate? = nil,
        date: Date? = nil,
        importedAt: Date = Date(timeIntervalSince1970: 1_000),
        contentHash: String = "hash"
    ) -> GameRecord {
        GameRecord(
            white: white, black: black, result: result, endedInMate: endedInMate,
            date: date, importedAt: importedAt, contentHash: contentHash,
            specialCheckmate: specialCheckmate
        )
    }
    
    private func stats(for key: String, in index: [PlayerStats]) throws -> PlayerStats {
        try #require(index.first { $0.key == key })
    }
    
    // MARK: Counting
    
    @Test func splitsResultsByColor() throws {
        let index = PlayerStats.index(of: [
            record(white: alice, black: bob, result: .whiteWins),
            record(white: alice, black: bob, result: .draw),
            record(white: bob, black: alice, result: .whiteWins),
            record(white: bob, black: alice, result: .blackWins),
        ])
        
        let aliceStats = try stats(for: "alice", in: index)
        #expect(aliceStats.games == 4)
        #expect(aliceStats.whiteWins == 1 && aliceStats.whiteDraws == 1 && aliceStats.whiteLosses == 0)
        #expect(aliceStats.blackWins == 1 && aliceStats.blackDraws == 0 && aliceStats.blackLosses == 1)
        #expect(aliceStats.wins == 2 && aliceStats.draws == 1 && aliceStats.losses == 1)
        #expect(aliceStats.decided == 4)
    }
    
    /// An ongoing game is an appearance, never a percentage: `games`
    /// includes it, W/D/L and `winRate` don't.
    @Test func ongoingCountsAsAppearanceOnly() throws {
        let index = PlayerStats.index(of: [
            record(white: alice, black: bob, result: .whiteWins),
            record(white: alice, black: bob, result: .ongoing),
        ])
        
        let aliceStats = try stats(for: "alice", in: index)
        #expect(aliceStats.games == 2)
        #expect(aliceStats.decided == 1)
        #expect(aliceStats.winRate == 1.0)
    }
    
    /// A player seen only in an ongoing game still exists - they're in
    /// the Library (the seed's Ruy Lopez case).
    @Test func ongoingOnlyPlayerIsStillIndexed() throws {
        let index = PlayerStats.index(of: [
            record(white: alice, black: bob, result: .ongoing)
        ])
        
        let aliceStats = try stats(for: "alice", in: index)
        #expect(aliceStats.games == 1)
        #expect(aliceStats.decided == 0)
        #expect(aliceStats.winRate == 0)
    }
    
    @Test func mateCreditGoesToTheWinnerOnly() throws {
        let index = PlayerStats.index(of: [
            record(white: alice, black: bob, result: .blackWins, endedInMate: true),
            record(white: alice, black: bob, result: .whiteWins),   // plain win, no mate
        ])
        
        #expect(try stats(for: "bob", in: index).matesDelivered == 1)
        #expect(try stats(for: "alice", in: index).matesDelivered == 0)
    }
    
    @Test func firstAndLastPlayedUseEffectiveDates() throws {
        let index = PlayerStats.index(of: [
            record(white: alice, black: bob, result: .draw,
                   date: Date(timeIntervalSince1970: 5_000)),
            // Undated - importedAt is its effective date, and it's earliest.
            record(white: alice, black: bob, result: .draw,
                   importedAt: Date(timeIntervalSince1970: 100), contentHash: "early"),
        ])
        
        let aliceStats = try stats(for: "alice", in: index)
        #expect(aliceStats.firstPlayed == Date(timeIntervalSince1970: 100))
        #expect(aliceStats.lastPlayed == Date(timeIntervalSince1970: 5_000))
    }
    
    @Test func unresolvedSidesContributeNothing() throws {
        let index = PlayerStats.index(of: [
            record(white: nil, black: bob, result: .whiteWins)   // "?" beat Bob
        ])
        
        #expect(index.count == 1)
        let bobStats = try stats(for: "bob", in: index)
        #expect(bobStats.games == 1 && bobStats.losses == 1)
    }
    
    @Test func indexIsKeyAscending() {
        let index = PlayerStats.index(of: [
            record(white: bob, black: alice, result: .draw)
        ])
        
        #expect(index.map(\.key) == ["alice", "bob"])
    }
    
    // MARK: Head to Head (3 Aug 2026)

    /// Orientation - cheap to get wrong, plausible when wrong: swapping the arguments must mirror
    /// the record, a property no symmetric fold passes.
    @Test func headToHeadIsOrientedToTheFirstPlayer() throws {
        let records = [
            record(white: alice, black: bob, result: .whiteWins),   // Alice
            record(white: bob, black: alice, result: .blackWins),   // Alice
            record(white: alice, black: bob, result: .draw),
            record(white: bob, black: alice, result: .whiteWins),   // Bob
        ]

        let forAlice = try #require(PlayerStats.headToHead("alice", "bob", in: records))
        #expect(forAlice.wins == 2)
        #expect(forAlice.draws == 1)
        #expect(forAlice.losses == 1)

        let forBob = try #require(PlayerStats.headToHead("bob", "alice", in: records))
        #expect(forBob.wins == 1)
        #expect(forBob.draws == 1)
        #expect(forBob.losses == 2)
    }

    /// Only their own games count. A fold that matched on "either seat is
    /// Alice" rather than on the pair would absorb the Carol game and answer
    /// a question nobody asked.
    @Test func headToHeadIgnoresGamesAgainstOthers() throws {
        let carol = GameRecord.Side(key: "carol", name: "Carol")
        let records = [
            record(white: alice, black: bob, result: .whiteWins),
            record(white: alice, black: carol, result: .whiteWins),
            record(white: carol, black: bob, result: .whiteWins),
        ]

        // Not named `record`: that would shadow the fixture helper of the
        // same name for the rest of the scope.
        let meeting = try #require(PlayerStats.headToHead("alice", "bob", in: records))
        #expect(meeting.wins == 1)
        #expect(meeting.draws == 0)
        #expect(meeting.losses == 0)
    }

    /// Never met is nil, not 0–0–0 - the subtitle must be able to say nothing
    /// rather than print a record for a rivalry that doesn't exist. An
    /// all-zero tuple would render as "Alice 0–0–0 Bob", which reads as a
    /// result.
    @Test func headToHeadIsNilWhenTheyHaveNeverMet() {
        let records = [record(white: alice, black: nil, result: .whiteWins)]
        #expect(PlayerStats.headToHead("alice", "bob", in: records) == nil)
        #expect(PlayerStats.headToHead("alice", "alice", in: records) == nil)
    }

    /// `*` is not a result, so an undecided meeting counts in
    /// none of the three columns - the totals may sum to less than the games
    /// played, deliberately.
    @Test func headToHeadExcludesUndecidedGames() throws {
        let records = [
            record(white: alice, black: bob, result: .ongoing),
            record(white: alice, black: bob, result: .whiteWins),
        ]

        // Not named `record`: that would shadow the fixture helper of the
        // same name for the rest of the scope.
        let meeting = try #require(PlayerStats.headToHead("alice", "bob", in: records))
        #expect(meeting.wins == 1)
        #expect(meeting.draws == 0)
        #expect(meeting.losses == 0)
    }

    /// A self-play row is not a meeting. Counted naively it would be a win
    /// *and* a loss for the same person, which is the shape
    /// `selfPlayRewritesBothSeats` guards on the retag side.
    @Test func headToHeadIgnoresSelfPlay() {
        let records = [record(white: alice, black: alice, result: .whiteWins)]
        #expect(PlayerStats.headToHead("alice", "alice", in: records) == nil)
    }

    // MARK: Opponents and Form (13 Aug 2026)

    private let carol = GameRecord.Side(key: "carol", name: "Carol")

    /// Distinct dates, because `chronologicalOrder` falls through to
    /// `importedAt` then `contentHash` - the fixture's defaults are identical
    /// on all three, so an order test built on them would pass on whatever
    /// order the input happened to have.
    private func dated(_ day: Int) -> Date {
        Date(timeIntervalSince1970: Double(day) * 86_400)
    }

    /// Numbers come out oriented to the subject, both seats, like `headToHead`.
    @Test func opponentRecordsAreOrientedToTheSubject() throws {
        let records = [
            record(white: alice, black: bob, result: .whiteWins),   // Alice
            record(white: bob, black: alice, result: .blackWins),   // Alice
            record(white: alice, black: bob, result: .draw),
            record(white: bob, black: alice, result: .whiteWins),   // Bob
        ]

        let forAlice = try #require(PlayerStats.opponents(of: "alice", in: records).first)
        #expect(forAlice.key == "bob")
        #expect(forAlice.wins == 2 && forAlice.draws == 1 && forAlice.losses == 1)

        let forBob = try #require(PlayerStats.opponents(of: "bob", in: records).first)
        #expect(forBob.wins == 1 && forBob.draws == 1 && forBob.losses == 2)
    }

    /// Most-played first. Built with the light opponent *earlier* in the input,
    /// so an implementation that kept insertion order fails rather than passes
    /// by luck.
    @Test func opponentsAreMostPlayedFirst() {
        let records = [
            record(white: alice, black: carol, result: .whiteWins),
            record(white: alice, black: bob, result: .whiteWins),
            record(white: alice, black: bob, result: .draw),
            record(white: alice, black: bob, result: .blackWins),
        ]

        let opponents = PlayerStats.opponents(of: "alice", in: records)
        #expect(opponents.map(\.key) == ["bob", "carol"])
        #expect(opponents[0].decided == 3)
        #expect(opponents[1].decided == 1)
    }

    /// Equal counts break on `key` ascending, and the claim is only worth
    /// anything if it survives a reshuffle - two orderings of one input,
    /// `rankingOrder`'s own standard.
    @Test func equallyPlayedOpponentsBreakOnKey() {
        let first = [
            record(white: alice, black: carol, result: .whiteWins),
            record(white: alice, black: bob, result: .whiteWins),
        ]
        let second = Array(first.reversed())

        #expect(PlayerStats.opponents(of: "alice", in: first).map(\.key) == ["bob", "carol"])
        #expect(PlayerStats.opponents(of: "alice", in: second).map(\.key) == ["bob", "carol"])
    }

    /// Ongoing contributes nothing and self-play is not an opponent - the two
    /// exclusions `headToHead` already makes, kept identical rather than
    /// re-decided.
    @Test func opponentsSkipUndecidedAndSelfPlay() {
        let records = [
            record(white: alice, black: bob, result: .ongoing),
            record(white: alice, black: alice, result: .whiteWins),
            record(white: alice, black: bob, result: .whiteWins),
        ]

        let opponents = PlayerStats.opponents(of: "alice", in: records)
        #expect(opponents.count == 1)
        #expect(opponents[0].decided == 1)
    }

    /// A player who has only ever played themselves has no opponents at all -
    /// not a row of zeroes against their own name.
    @Test func onlySelfPlayLeavesNoOpponents() {
        let records = [record(white: alice, black: alice, result: .whiteWins)]
        #expect(PlayerStats.opponents(of: "alice", in: records).isEmpty)
    }

    /// Oldest first, so the view renders left to right without reversing.
    /// Input is shuffled relative to the dates: the fold sorts, the caller
    /// does not.
    @Test func formReadsOldestFirst() {
        let records = [
            record(white: alice, black: bob, result: .draw, date: dated(2)),
            record(white: bob, black: alice, result: .whiteWins, date: dated(3)),
            record(white: alice, black: bob, result: .whiteWins, date: dated(1)),
        ]

        #expect(PlayerStats.form(of: "alice", in: records) == [.win, .draw, .loss])
    }

    /// The cap takes the **most recent** window. A prefix would show a
    /// player's debut the moment their history outgrew the limit, which looks
    /// identical to working.
    @Test func formCapTakesTheMostRecentGames() {
        let records = (1...6).map { day in
            record(
                white: alice, black: bob,
                result: day > 3 ? .whiteWins : .blackWins,
                date: dated(day)
            )
        }

        #expect(PlayerStats.form(of: "alice", in: records, limit: 3) == [.win, .win, .win])
        #expect(PlayerStats.form(of: "alice", in: records, limit: 100).count == 6)
        #expect(PlayerStats.form(of: "alice", in: records, limit: 0).isEmpty)
    }

    /// Same two exclusions as `opponents`, for the same reason: a self-play
    /// row would be a win and a loss for one person, and `*` is not a result.
    @Test func formSkipsUndecidedAndSelfPlay() {
        let records = [
            record(white: alice, black: bob, result: .ongoing, date: dated(1)),
            record(white: alice, black: alice, result: .whiteWins, date: dated(2)),
            record(white: alice, black: bob, result: .whiteWins, date: dated(3)),
        ]

        #expect(PlayerStats.form(of: "alice", in: records) == [.win])
    }

    /// A player nobody has records for folds to nothing rather than trapping.
    @Test func unknownSubjectFoldsToNothing() {
        let records = [record(white: alice, black: bob, result: .whiteWins)]
        #expect(PlayerStats.opponents(of: "nobody", in: records).isEmpty)
        #expect(PlayerStats.form(of: "nobody", in: records).isEmpty)
    }

    // MARK: Ranking

    /// Wins outrank win rate outranks key - each link exercised at a
    /// boundary where the next one would disagree.
    @Test func rankingOrderRunsTheFullTiebreakChain() {
        func player(_ key: String, wins: Int, losses: Int) -> PlayerStats {
            PlayerStats(
                key: key, name: key, games: wins + losses,
                whiteWins: wins, whiteDraws: 0, whiteLosses: losses,
                blackWins: 0, blackDraws: 0, blackLosses: 0,
                matesDelivered: 0, specialMatesDelivered: 0,
                firstPlayed: Date(timeIntervalSince1970: 0),
                lastPlayed: Date(timeIntervalSince1970: 0)
            )
        }
        
        let manyWins   = player("zoe", wins: 5, losses: 5)   // 5 wins, 50%
        let efficient  = player("amy", wins: 4, losses: 0)   // 4 wins, 100%
        let grinder    = player("ben", wins: 4, losses: 4)   // 4 wins, 50%
        let grinderTwin = player("ann", wins: 4, losses: 4)  // ties into the key
        
        let ranked = [grinder, efficient, grinderTwin, manyWins]
            .sorted(by: PlayerStats.rankingOrder)
        
        #expect(ranked.map(\.key) == ["zoe", "amy", "ann", "ben"])
    }

    // MARK: Special mates (5 Aug 2026)

    /// A motif mate credits the **winner**, exactly as `matesDelivered` does -
    /// the loser of a smothered mate did not deliver one.
    @Test func specialMateCreditsTheWinnerOnly() throws {
        let records = [
            record(white: alice, black: bob, result: .whiteWins,
                   endedInMate: true, specialCheckmate: .smothered)
        ]

        let index = PlayerStats.index(of: records)

        #expect(try stats(for: "alice", in: index).specialMatesDelivered == 1)
        #expect(try stats(for: "bob", in: index).specialMatesDelivered == 0)
    }

    /// An ordinary mate is a mate and not a special one - the column would be
    /// meaningless if every `#` counted.
    @Test func anOrdinaryMateIsNotSpecial() throws {
        let records = [record(white: alice, black: bob, result: .whiteWins, endedInMate: true)]

        // `aliceStats`, not `alice` - that name is the `GameRecord.Side`
        // fixture used two lines up, and a local of the same name in the same
        // scope is a use-before-declaration error rather than a shadow.
        let aliceStats = try stats(for: "alice", in: PlayerStats.index(of: records))

        #expect(aliceStats.matesDelivered == 1)
        #expect(aliceStats.specialMatesDelivered == 0)
    }

    /// Both motifs count, and they count together - the column is "how many
    /// motif mates", not one per motif.
    @Test func bothMotifsCountTowardTheSameTotal() throws {
        let records = [
            record(white: alice, black: bob, result: .whiteWins,
                   endedInMate: true, specialCheckmate: .smothered, contentHash: "a"),
            record(white: alice, black: bob, result: .whiteWins,
                   endedInMate: true, specialCheckmate: .backRank, contentHash: "b")
        ]

        #expect(try stats(for: "alice", in: PlayerStats.index(of: records)).specialMatesDelivered == 2)
    }

    /// The two counters read **different fields**: a record with `endedInMate: false` and a motif
    /// reports one special mate and zero mates - the fold does not nest one counter in the other
    /// (the `Qd2#!` divergence, pinned until the spellings are unified).
    @Test func matesAndSpecialMatesAreCountedFromDifferentFields() throws {
        let records = [
            record(white: alice, black: bob, result: .whiteWins,
                   endedInMate: false, specialCheckmate: .smothered)
        ]

        let aliceStats = try stats(for: "alice", in: PlayerStats.index(of: records))

        #expect(aliceStats.matesDelivered == 0)
        #expect(aliceStats.specialMatesDelivered == 1)
    }

    /// A drawn or ongoing game credits nobody, whatever the motif field says -
    /// the switch only reaches the counter on a decided result.
    @Test func onlyADecidedGameCreditsASpecialMate() throws {
        let records = [
            record(white: alice, black: bob, result: .draw, specialCheckmate: .smothered)
        ]
        #expect(try stats(for: "alice", in: PlayerStats.index(of: records)).specialMatesDelivered == 0)
    }
}
