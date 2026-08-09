import Testing
import Foundation
// `MemberImportVisibility` is on (D43′), so the container the link test builds
// needs this here — a transitive import through `@testable` does not carry
// members. The value-level suite below still touches no SwiftData type.
import SwiftData
@testable import DGTStudioPro

/// `CollectionFoldKey`'s algebra, over values. Nonisolated — load-bearing, not stylistic.
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

    /// The field easiest to drop: classification lives *outside* the content hash, so a backfill
    /// changes what `PlayerStats` counts while every hash stays byte-identical — a key built from
    /// `contentHash` alone misses it.
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

    /// The half a real backfill hits most: an ordinary line gets three ECO columns and a nil motif.
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

/// The memo box over real models. `@MainActor` for the `PGN`s, not the cache — nothing here
/// asserts the cache's isolation.
@MainActor
@Suite("Collection Fold — Cache")
struct CollectionFoldCacheTests {

    // MARK: Key over models

    /// **The pin the analysis fix rests on**: writing evaluations does not move the key, so a batch
    /// does not re-fold the Library per ply.
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

    /// The ECO half over models — `classify` writes three columns beside the motif.
    @Test("An ECO stamp moves the key, over models")
    func ecoStampMovesTheKeyOverModels() {
        let game = PGN(moves: ["e4", "c5"], contentHash: "fixed")
        let before = CollectionFoldKey(games: [game])

        game.ecoCode = "B20"
        game.ecoFamily = "Sicilian Defense"

        #expect(CollectionFoldKey(games: [game]) != before)
        #expect(game.specialCheckmate == nil, "the motif must stay nil, or this proves nothing")
    }

    /// A resolved link moves the key with no hash change: the hash folds seat *tags*; the ladder
    /// keys on the *link*. The tags never move here, so green cannot be the hash doing the work.
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
