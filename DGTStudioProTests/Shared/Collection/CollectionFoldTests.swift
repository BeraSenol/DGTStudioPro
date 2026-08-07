import Testing
import Foundation
@testable import DGTStudioPro

/// `CollectionFoldKey`'s algebra, over values.
///
/// **Nonisolated, and that is load-bearing rather than stylistic** — the
/// `RosterSummaryTests` lesson (D44′). The key is a pure value type and a suite
/// standing in the main actor could not tell the difference; this one can.
@Suite("Collection Fold — Key")
struct CollectionFoldKeyTests {

    private static func row(
        _ hash: String,
        _ checkmate: SpecialCheckmate? = nil
    ) -> CollectionFoldKey.Row {
        .init(contentHash: hash, checkmate: checkmate)
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
    @Test("A classification backfill moves the key with no hash change")
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
