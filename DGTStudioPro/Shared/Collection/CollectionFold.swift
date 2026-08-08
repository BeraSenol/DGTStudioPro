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
///   - **A batch analysis** called `modelContext.save()` once per ply
///     (`GameAnalysisDriver`, as it stood), and a save invalidates every
///     `@Query` in the app — so an 80-ply game re-folded the whole Library 80
///     times if Players happened to be open. That was the sharpest of the
///     three, because it is the one where the app is already busy. D71′ has
///     since moved the save to once per exit, which retires the multiplier at
///     its source; this key remains what makes the fold indifferent to save
///     cadence at all, whichever way that decision moves next.
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
/// **The rule is that `Row` mirrors `GameRecord` field for field, and it is
/// stated as a rule because the first version did not.** `contentHash` folds
/// event, site, date, round, both seat tags, the result and the movetext (the
/// one-hash invariant), so it moves whenever anything *it* covers moves — a
/// rename rehashes through `retag`, a metadata edit through `applyEdit`. Every
/// other field here exists because the projection reads something the hash
/// deliberately excludes, and the hash's own exclusion list (D24′, D58′) is
/// therefore the checklist for this type:
///
///   - `checkmate` — `PlayerStats.specialMatesDelivered` and
///     `TagRule.checkmateType` read it.
///   - `opening` — `TagRule.opening` reads it. Classification is outside the
///     hash by D24′ and D34′.
///   - `white` / `black` — the **resolved links**, which the hash does not
///     cover because it folds the seat *tags*. `PlayerStats.index` keys the
///     whole ladder on these.
///   - `name` / `isTimed` — `TagRule.name` and `TagRule.timed`.
///
/// **This was wrong on three of those four when it shipped, and the shape of
/// the miss is worth more than the fix.** The key carried `contentHash` plus
/// `checkmate`, and the reasoning that produced it was correct as far as it
/// went: it asked what `PlayerStats` reads, found `specialCheckmate`, and
/// stopped — while `classify(_:using:)` writes **four** columns in one call and
/// `specialCheckmate` is nil for every game that is not a smothered or
/// back-rank mate. So `backfillClassifications` stamped an ECO code on a game,
/// the hash did not move, the checkmate did not move, and the memo handed back
/// a record whose `opening` was still nil — an `opening contains Sicilian`
/// smart tag failing to match a row whose ECO column, reading the model
/// directly, showed the code. `backfillPlayerLinks` had the same shape one
/// door over, and worse: it runs from `PlayersDestination.onAppear` under a
/// comment promising the ladder works on a cold launch, and the memo was
/// defeating exactly that.
///
/// The lesson the old text already carried and did not apply to itself:
/// **adding a field here is cheap; forgetting one is a stale fold nothing
/// complains about.** The remedy is the mirror rule above — a reader checks
/// this type by reading `GameRecord`'s stored properties beside it, which is a
/// question with an answer, where "did I think of everything?" is not.
///
/// **Exact, not hashed.** The obvious spelling is a `Hasher` fingerprint —
/// allocation-free, one `Int` to compare. It was rejected: a 64-bit digest is
/// one collision away from a silently stale ladder, and "silently" is the
/// operative word, because the failure renders perfectly and looks like data.
/// Comparing the rows costs a pointer-equal `String ==` per game — both sides
/// come from the same model instances, so the fast path is what actually runs —
/// which is still two orders of magnitude under one blob decode.
///
/// Building the key decodes nothing: no `moves`, no `evaluations`, no blob off
/// the model. It does read the two player relationships, which is the one cost
/// that is not free and is stated rather than buried — see `Row.white`.
internal struct CollectionFoldKey: Equatable, Sendable {

    /// One game's contribution, as values — so a suite can build a key without
    /// a container (D10′'s posture applied to a cache key).
    ///
    /// **Everything after `checkmate` is defaulted**, on `GameRecord`'s own
    /// precedent and for its reason: the fixtures and the call order stay
    /// source-stable while the app's one construction below passes every field
    /// explicitly. The defaults are fixture ergonomics, not hiding places — a
    /// row built with none of them is a row claiming a game with no opening, no
    /// links, no name and no clock, which is a real state rather than a
    /// shortcut.
    internal struct Row: Equatable, Sendable {
        internal let contentHash: String
        internal let checkmate: SpecialCheckmate?
        internal let opening: ECOOpening?
        internal let name: String
        internal let isTimed: Bool

        /// The resolved players' identifiers, not their names.
        ///
        /// **Identity is enough because a `Player`'s name cannot move under
        /// it.** `GameRecord.Side` carries `normalizedName` and `name`; the
        /// first is derived from the second and the second is fixed at
        /// creation by D9′'s first-seen-casing rule. The only transition the
        /// hash misses is therefore nil → linked (`backfillPlayerLinks`), and
        /// an identifier reports that without materializing two strings per
        /// game per render.
        ///
        /// **Accepted cost, named because it is the one thing here that is not
        /// a stored scalar:** this faults the relationship on every key build,
        /// where before only a cache *miss* paid it. It is bounded by the row
        /// cache — `Player` rows number in the dozens against hundreds of
        /// games, and they are already registered in the context by the time
        /// any destination renders. Known-costs census.
        internal let white: PersistentIdentifier?
        internal let black: PersistentIdentifier?

        internal init(
            contentHash: String,
            checkmate: SpecialCheckmate?,
            opening: ECOOpening? = nil,
            name: String = "",
            isTimed: Bool = false,
            white: PersistentIdentifier? = nil,
            black: PersistentIdentifier? = nil
        ) {
            self.contentHash = contentHash
            self.checkmate = checkmate
            self.opening = opening
            self.name = name
            self.isTimed = isTimed
            self.white = white
            self.black = black
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
    ///
    /// **Every argument is passed explicitly, defaults notwithstanding.** This
    /// is the one place the mirror rule is enforceable by eye: the argument
    /// list below should read against `PGN.gameRecord`'s, and a field added
    /// there without one here is the defect this type exists to prevent.
    internal init(games: [PGN]) {
        self.init(
            rows: games.map {
                Row(
                    contentHash: $0.contentHash,
                    checkmate: $0.specialCheckmate,
                    opening: $0.opening,
                    name: $0.name,
                    isTimed: $0.timeControl != nil,
                    white: $0.whitePlayer?.persistentModelID,
                    black: $0.blackPlayer?.persistentModelID
                )
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
