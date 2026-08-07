import Testing
import Foundation
// `MemberImportVisibility` is on (D43′), so the container the link test builds
// needs this here — a transitive import through `@testable` does not carry
// members. The value-level suite below still touches no SwiftData type.
import SwiftData
@testable import DGTStudioPro

/// `CollectionFoldKey`'s algebra, over values.
///
/// **Nonisolated, and that is load-bearing rather than stylistic** — the
/// `RosterSummaryTests` lesson (D44′). The key is a pure value type and a suite
/// standing in the main actor could not tell the difference; this one can.
@Suite("Collection Fold — Key")
struct CollectionFoldKeyTests {

    /// Mirrors `Row`'s own defaulting, so a test names only the field it is
    /// about and every other one stays at the "nothing stamped yet" value.
    private static func row(
        _ hash: String,
        _ checkmate: SpecialCheckmate? = nil,
        opening: ECOOpening? = nil,
        name: String = "",
        isTimed: Bool = false
    ) -> CollectionFoldKey.Row {
        .init(
            contentHash: hash,
            checkmate: checkmate,
            opening: opening,
            name: name,
            isTimed: isTimed
        )
    }

    /// `ECOOpening`'s rehydrating initializer takes `variation` without a
    /// default — deliberately, since D35′ makes nil the one spelling of "no
    /// variation" and a default would let a caller mean it by omission.
    private static func opening(
        _ code: String,
        _ family: String,
        _ variation: String? = nil
    ) -> ECOOpening {
        ECOOpening(code: code, family: family, variation: variation)
    }

    @Test("An empty library equals an empty library")
    func emptyKeysAreEqual() {
        #expect(CollectionFoldKey(rows: []) == CollectionFoldKey(rows: []))
    }

    @Test("Identical content produces an equal key")
    func identicalContentIsEqual() {
        let rows = [Self.row("a"), Self.row("b", .smothered)]
        #expect(CollectionFoldKey(rows: rows) == CollectionFoldKey(rows: rows))
    }

    @Test("An edited game moves the key")
    func aChangedContentHashMovesTheKey() {
        #expect(
            CollectionFoldKey(rows: [Self.row("a")])
            != CollectionFoldKey(rows: [Self.row("a-edited")])
        )
    }

    /// **The field that is easiest to drop, and the reason it is here.**
    /// Classification lives *outside* the content hash by D24′ and D34′, so a
    /// backfill stamping mate motifs changes what `PlayerStats` counts while
    /// every hash stays byte-identical. A key built from `contentHash` alone
    /// looks obviously sufficient and would freeze the Special Mates column
    /// against a fold that had genuinely changed.
    ///
    /// **This test was titled "A classification backfill moves the key" and
    /// covered only the motif**, which is the narrower half of one call:
    /// `PGNStore.classify(_:using:)` writes `ecoCode`, `ecoFamily`,
    /// `ecoVariation` *and* `specialCheckmate` together, and the motif is nil
    /// for every game that is not a smothered or back-rank mate. So the title
    /// quantified over a backfill while the body exercised the rarer of its two
    /// outcomes, and the ECO half — which had no case at all — was broken. The
    /// title now names what it checks; `anEcoStampMovesTheKey` below is the
    /// other half.
    @Test("A stamped mate motif moves the key with no hash change")
    func aChangedCheckmateMovesTheKey() {
        #expect(
            CollectionFoldKey(rows: [Self.row("a", nil)])
            != CollectionFoldKey(rows: [Self.row("a", .smothered)])
        )
        #expect(
            CollectionFoldKey(rows: [Self.row("a", .backRank)])
            != CollectionFoldKey(rows: [Self.row("a", .smothered)])
        )
    }

    /// The half the suite was missing, and the one a real backfill hits most.
    ///
    /// A game classified as an ordinary line gets three ECO columns and a nil
    /// motif, so the test above stays green while `TagRule.opening` filters
    /// against a record whose `opening` is still nil. Asserted across all three
    /// columns rather than on the code alone: `TagRule.opening` matches
    /// `ECOOpening.fullName`, which reads family and variation too.
    @Test("An ECO stamp moves the key, motif or no motif")
    func anEcoStampMovesTheKey() {
        #expect(
            CollectionFoldKey(rows: [Self.row("a")])
            != CollectionFoldKey(rows: [
                Self.row("a", nil, opening: Self.opening("B20", "Sicilian Defense"))
            ])
        )
        // Variation too, because `TagRule.opening` matches `fullName` rather
        // than the code — a key watching `ecoCode` alone would pass the line
        // above and still freeze a `contains Smith-Morra` rule.
        #expect(
            CollectionFoldKey(rows: [
                Self.row("a", nil, opening: Self.opening("B20", "Sicilian Defense"))
            ])
            != CollectionFoldKey(rows: [
                Self.row(
                    "a", nil,
                    opening: Self.opening("B20", "Sicilian Defense", "Smith-Morra Gambit")
                )
            ])
        )
    }

    /// `PGN.name` is outside the hash by design and `backfillEmptyNames()`
    /// rewrites it; `timeControl` is outside by D24′ and Get Info's Equipment
    /// section edits it without moving the hash. `TagRule.name` and
    /// `TagRule.timed` read both.
    @Test("Name and clock move the key with no hash change")
    func nameAndClockMoveTheKey() {
        #expect(
            CollectionFoldKey(rows: [Self.row("a", nil, name: "1. Bera vs Reinaud")])
            != CollectionFoldKey(rows: [Self.row("a", nil, name: "1. Bera vs Heylen")])
        )
        #expect(
            CollectionFoldKey(rows: [Self.row("a", nil, isTimed: false)])
            != CollectionFoldKey(rows: [Self.row("a", nil, isTimed: true)])
        )
    }

    /// Both destinations fold an *ordered* array, so a key that ignored order
    /// would hand back a fold computed from a different sequence.
    @Test("Order is part of the key")
    func orderIsPartOfTheKey() {
        #expect(
            CollectionFoldKey(rows: [Self.row("a"), Self.row("b")])
            != CollectionFoldKey(rows: [Self.row("b"), Self.row("a")])
        )
    }

    @Test("An imported or deleted game moves the key")
    func countMovesTheKey() {
        let one = CollectionFoldKey(rows: [Self.row("a")])
        #expect(one != CollectionFoldKey(rows: [Self.row("a"), Self.row("b")]))
        #expect(one != CollectionFoldKey(rows: []))
    }
}

/// The memo box, and the one property of `CollectionFoldKey` that can only be
/// asked of real models.
///
/// **`@MainActor` for the `PGN`s, not for the cache** — `AnalysisGlyphStateTests`'
/// reason, and the distinction matters because of D44′. `CollectionFoldCache`
/// is deliberately un-isolated (see its declaration), so nothing here asserts
/// anything about its isolation and a reader should not infer that it does. The
/// annotation is about the `@Model`s these tests construct.
@MainActor
@Suite("Collection Fold — Cache")
struct CollectionFoldCacheTests {

    // MARK: Key over models

    /// **The pin the analysis fix rests on.**
    ///
    /// `GameAnalysisDriver` writes one evaluation and calls
    /// `modelContext.save()` per ply, and a save invalidates every `@Query` in
    /// the app. If `evaluations` were in the key, an 80-ply pass would re-fold
    /// the whole Library 80 times — which is the behaviour the key exists to
    /// stop, and which nothing else in the suite would notice.
    ///
    /// Asserted from the side that would break it: the array is genuinely
    /// mutated between the two reads, so an implementation that folded it in
    /// goes red here rather than passing by never being exercised.
    @Test("Writing evaluations does not move the key")
    func evaluationsAreOutsideTheKey() {
        let game = PGN(moves: ["e4", "e5"], contentHash: "fixed")
        let before = CollectionFoldKey(games: [game])

        game.evaluations = [.centipawns(31), .centipawns(-12)]

        #expect(CollectionFoldKey(games: [game]) == before)
    }

    /// The other half of the same claim, so the test above cannot pass by the
    /// key being insensitive to everything.
    @Test("A stamped mate motif does move the key, over models")
    func classificationMovesTheKeyOverModels() {
        let game = PGN(moves: ["e4"], contentHash: "fixed")
        let before = CollectionFoldKey(games: [game])

        game.specialCheckmate = .backRank

        #expect(CollectionFoldKey(games: [game]) != before)
    }

    /// The ECO half of the same call, over models — `classify(_:using:)` writes
    /// three opening columns beside the motif and the motif is nil for any game
    /// that is not a smothered or back-rank mate.
    ///
    /// Over models rather than values because that is where the miss lived: the
    /// value-level suite could have carried an `opening` case from the start and
    /// still passed with `init(games:)` dropping the field on the floor. This is
    /// the one that would have gone red.
    @Test("An ECO stamp moves the key, over models")
    func ecoStampMovesTheKeyOverModels() {
        let game = PGN(moves: ["e4", "c5"], contentHash: "fixed")
        let before = CollectionFoldKey(games: [game])

        game.ecoCode = "B20"
        game.ecoFamily = "Sicilian Defense"

        #expect(CollectionFoldKey(games: [game]) != before)
        #expect(game.specialCheckmate == nil, "the motif must stay nil, or this proves nothing")
    }

    /// `backfillPlayerLinks()` resolves a seat the content hash cannot see: the
    /// hash folds the seat **tags**, and the link is a relationship filled in
    /// afterwards. `PlayerStats.index(of:)` keys the whole ladder on the link,
    /// and the backfill runs from `PlayersDestination.onAppear` — so a key blind
    /// to this froze the ladder in the state it had *before* the pass that
    /// exists to populate it.
    ///
    /// **Inserted into a container, unlike its siblings above**, because
    /// `persistentModelID` on an uninserted model is a temporary identifier and
    /// this test's whole subject is that the identifier changes for the right
    /// reason. The tag strings never move here, so a green result cannot be the
    /// hash doing the work.
    @Test("Resolving a seat link moves the key with no hash change")
    func aResolvedLinkMovesTheKeyOverModels() throws {
        let container = try ModelContainer(
            for: PGN.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let game = PGN(moves: ["e4"], contentHash: "fixed")
        let player = Player(name: "Bera Senol")
        context.insert(game)
        context.insert(player)

        let hashBefore = game.contentHash
        let before = CollectionFoldKey(games: [game])

        game.whitePlayer = player

        #expect(CollectionFoldKey(games: [game]) != before)
        #expect(game.contentHash == hashBefore, "the hash must not move, or this proves nothing")
    }

    /// `PGN.name` is outside the hash and `backfillEmptyNames()` rewrites it;
    /// `timeControl` is outside by D24′ and Get Info's Equipment section edits
    /// it. `TagRule.name` and `TagRule.timed` read both off the record.
    @Test("Name and clock move the key, over models")
    func nameAndClockMoveTheKeyOverModels() {
        let game = PGN(moves: ["e4"], contentHash: "fixed")

        let beforeName = CollectionFoldKey(games: [game])
        game.name = "1. Bera vs Reinaud"
        #expect(CollectionFoldKey(games: [game]) != beforeName)

        let beforeClock = CollectionFoldKey(games: [game])
        game.timeControl = "600+5"
        #expect(CollectionFoldKey(games: [game]) != beforeClock)
    }

    // MARK: Cache behaviour

    private static func key(_ hash: String) -> CollectionFoldKey {
        CollectionFoldKey(rows: [.init(contentHash: hash, checkmate: nil)])
    }

    @Test("The first read computes")
    func theFirstReadComputes() {
        let cache = CollectionFoldCache<CollectionFoldKey, Int>()
        var computations = 0

        #expect(!cache.isCached(Self.key("a")))
        let value = cache.value(for: Self.key("a")) {
            computations += 1
            return 7
        }

        #expect(value == 7)
        #expect(computations == 1)
        #expect(cache.isCached(Self.key("a")))
    }

    /// The whole point of the type: an unchanged Library is folded once, not
    /// once per render.
    @Test("A repeated key does not recompute")
    func aRepeatedKeyDoesNotRecompute() {
        let cache = CollectionFoldCache<CollectionFoldKey, Int>()
        var computations = 0

        for _ in 0..<5 {
            _ = cache.value(for: Self.key("a")) {
                computations += 1
                return computations
            }
        }

        #expect(computations == 1)
    }

    @Test("A moved key recomputes, and the new value is what is returned")
    func aMovedKeyRecomputes() {
        let cache = CollectionFoldCache<CollectionFoldKey, String>()

        #expect(cache.value(for: Self.key("a")) { "first" } == "first")
        #expect(cache.value(for: Self.key("b")) { "second" } == "second")
        #expect(!cache.isCached(Self.key("a")))
        // And the moved-to key is now the cached one, so the next read of it
        // is a hit rather than a third computation.
        #expect(cache.isCached(Self.key("b")))
    }

    /// A cache that only ever grew would answer the previous question
    /// correctly and still return a stale fold after the key moved back — the
    /// one-entry contract stated as a test rather than as a comment.
    @Test("Returning to an evicted key recomputes rather than resurrecting")
    func areturnedKeyRecomputes() {
        let cache = CollectionFoldCache<CollectionFoldKey, String>()
        var computations = 0

        _ = cache.value(for: Self.key("a")) { computations += 1; return "a1" }
        _ = cache.value(for: Self.key("b")) { computations += 1; return "b1" }
        let third = cache.value(for: Self.key("a")) { computations += 1; return "a2" }

        #expect(computations == 3)
        #expect(third == "a2")
    }
}
