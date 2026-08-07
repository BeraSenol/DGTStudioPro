import Foundation
import SwiftData

/// A cheap, exact answer to "have the inputs to a collection fold changed?"
///
/// **Why this exists.** Both collection destinations fold the whole Library in
/// `body` — `PlayersDestination` projects every game into a `GameRecord` and
/// runs `Glicko1.histories` plus `PlayerStats.index` over the result, the
/// Library projects records for its tag filter and its backlog count. Those
/// folds are correct and their inputs change rarely; what changes constantly is
/// everything *else* that invalidates a destination body. Three triggers, all
/// of them measured off the code rather than off a stopwatch:
///
///   - **A rubber-band drag** writes the selection on every drag callback, so
///     the fold ran at pointer rate over a library that had not changed.
///   - **A search keystroke** invalidates the body, and both destinations
///     narrow *downstream* of the fold, so the fold ran per character.
///   - **A batch analysis** calls `modelContext.save()` once per ply
///     (`GameAnalysisDriver`), and a save invalidates every `@Query` in the
///     app — so an 80-ply game re-folded the whole Library 80 times if Players
///     happened to be open. That was the sharpest of the three, because it is
///     the one where the app is already busy.
///
/// **What the key deliberately does not cover, which is the whole point.**
/// `evaluations` is absent. It is not an input to either fold — `PlayerStats`
/// and `Glicko1` read results, seats, dates and the mate motif, and none of
/// them has ever asked what an engine thought. Excluding it is what makes a
/// running batch cost nothing here: the per-ply save still fires, the key still
/// compares equal, and the fold is not repeated. A consumer that genuinely
/// tracks analysis state (the Library's backlog count, a `TagRule.analyzed`
/// rule) must therefore compose this key with an analysis signal of its own —
/// `LibraryDestination.FoldKey` is the worked example, and it uses the queue's
/// own counters rather than re-reading the array this key skips.
///
/// **Two fields, and each earns its place.** `contentHash` folds event, site,
/// date, round, both seat tags, the result and the movetext (the one-hash
/// invariant), so it moves whenever anything a fold reads moves — a rename
/// rehashes through `retag`, a metadata edit through `applyEdit`.
/// `specialCheckmate` is the exception that forced a second field: D24′ and
/// D34′ keep classification *outside* the hash on purpose, and
/// `PlayerStats.specialMatesDelivered` reads it, so a classification backfill
/// would otherwise change the ladder without moving the key. Adding a field
/// here is cheap; forgetting one is a stale ladder nothing complains about.
///
/// **Exact, not hashed.** The obvious spelling is a `Hasher` fingerprint —
/// allocation-free, one `Int` to compare. It was rejected: a 64-bit digest is
/// one collision away from a silently stale ladder, and "silently" is the
/// operative word, because the failure renders perfectly and looks like data.
/// Comparing the rows costs a pointer-equal `String ==` per game — both sides
/// come from the same model instances, so the fast path is what actually runs —
/// which is still two orders of magnitude under one blob decode.
///
/// Building the key touches only stored scalars: no `moves`, no `evaluations`,
/// no relationship traversal. That is the property that makes it worth building
/// on every render.
internal struct CollectionFoldKey: Equatable, Sendable {

    /// One game's contribution, as values — so a suite can build a key without
    /// a container (D10′'s posture applied to a cache key).
    internal struct Row: Equatable, Sendable {
        internal let contentHash: String
        internal let checkmate: SpecialCheckmate?

        internal init(contentHash: String, checkmate: SpecialCheckmate?) {
            self.contentHash = contentHash
            self.checkmate = checkmate
        }
    }

    private let rows: [Row]

    internal init(rows: [Row]) {
        self.rows = rows
    }
}

extension CollectionFoldKey {

    /// The app's construction, over the `@Query` array a destination already
    /// holds.
    ///
    /// Order-sensitive by construction, and that is correct rather than
    /// incidental: both destinations fold an ordered array, and a reordering
    /// that produced an equal key would be a fold reused against a sequence it
    /// was not computed from.
    internal init(games: [PGN]) {
        self.init(
            rows: games.map {
                Row(contentHash: $0.contentHash, checkmate: $0.specialCheckmate)
            }
        )
    }
}

/// A one-entry memo for a fold that a `View` body needs on the same pass its
/// inputs change.
///
/// **A box, not `@State`** — the `IconGridWidthBox` / `IconGridFrameStore`
/// idiom this project already uses in both icons grids. A reference type held
/// in `@State` can be written from inside `body` without invalidating anything,
/// which is exactly the licence a memo needs and exactly the thing `@State`
/// forbids.
///
/// **Not `.onChange` into `@State`, and the reason is a frame.** The
/// alternative arrangement — observe the inputs, recompute in a change
/// handler, store the result — renders one pass stale every time the inputs
/// move, because `body` runs before the handler does. A destination that
/// painted last render's ladder for one frame after an import would be a worse
/// bug than the cost this replaces.
///
/// **One entry, not an LRU.** Both call sites read exactly one value per pass
/// and the key changes only when the Library does, so a second slot would
/// never be hit. Keeping it at one also keeps the staleness question answerable
/// by reading nine lines.
///
/// `Key` is generic rather than fixed to `CollectionFoldKey` because the two
/// destinations depend on different things: Players folds over content alone,
/// while the Library also tracks analysis. Each states its own dependency as a
/// type, which is the documentation as much as the mechanism — a fold whose key
/// omits something it reads is the one defect this cannot catch for you.
///
/// **Non-`Sendable` and deliberately un-isolated**, matching
/// `IconGridFrameStore` exactly. `@MainActor` was the first spelling and does
/// not compile where it is used: a destination's `init` is nonisolated (the app
/// target's default, D27′), so the `@State` default-value expression would be
/// calling a main-actor initializer from a nonisolated context. Isolation is
/// unnecessary anyway — the type never escapes a view body, and under mode 6
/// its non-`Sendable`ness is what enforces that rather than an annotation.
internal final class CollectionFoldCache<Key: Equatable, Value> {

    private var stored: (key: Key, value: Value)?

    internal init() {}

    /// The memoized value, computing it only when `key` differs from the one
    /// the stored value was computed under.
    ///
    /// `compute` is not `@escaping` and is never retained — it runs before this
    /// returns or not at all, so a caller may close over the whole render pass
    /// without a cycle.
    internal func value(for key: Key, compute: () -> Value) -> Value {
        if let stored, stored.key == key { return stored.value }
        let fresh = compute()
        stored = (key, fresh)
        return fresh
    }

    /// Whether the next `value(for:compute:)` under this key would recompute.
    ///
    /// Exists for the suites rather than for the app: the property worth
    /// pinning is *that a hit is a hit*, and a cache whose only door computes
    /// on demand cannot be asked that question without also answering it.
    internal func isCached(_ key: Key) -> Bool {
        stored?.key == key
    }
}
