import Foundation
import SwiftData

/// A cheap exact answer to "have the fold's inputs changed?" — both destinations fold the whole
/// Library in `body`, and re-folds ran at pointer rate over an unchanged library.
/// **`evaluations` is deliberately absent**: not an input to either fold, and hashing it would
/// re-fold the Library once per ply during a batch. A consumer that needs it keys its own
/// signal (the Library's `FoldKey` adds queue counters).
internal struct CollectionFoldKey: Equatable, Sendable {

    /// One game's contribution, as values — a suite builds a key without a container. Everything
    /// after `checkmate` is defaulted for fixture ergonomics; the hash covers all of it.
    internal struct Row: Equatable, Sendable {
        internal let contentHash: String
        internal let checkmate: SpecialCheckmate?
        internal let opening: ECOOpening?
        internal let name: String
        internal let isTimed: Bool

        /// Resolved players' *identifiers*, not names — identity is enough because a name cannot move
        /// under a row (rename retags and re-resolves; first-seen casing pins the rest). The one missed
        /// transition is nil → linked, which the backfill's own pass republishes anyway.
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

    /// Construction over the `@Query` array. Order-sensitive by construction, correctly: both
    /// destinations fold an ordered array, and a reordering is a different fold input.
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

/// One-entry memo for a fold a `View` body needs on the same pass its inputs change.
/// **A box, not `@State`** — mutation during render is exactly the licence a memo needs and
/// exactly what `@State` forbids; `.onChange` lands a frame late. One entry, not an LRU: both
/// call sites read one value per pass.
internal final class CollectionFoldCache<Key: Equatable, Value> {

    private var stored: (key: Key, value: Value)?

    internal init() {}

    /// Computes only when `key` differs from the stored one. `compute` is not `@escaping` — runs
    /// before return or not at all, so closing over the render pass is cycle-free.
    internal func value(for key: Key, compute: () -> Value) -> Value {
        if let stored, stored.key == key { return stored.value }
        let fresh = compute()
        stored = (key, fresh)
        return fresh
    }

    /// For the suites: "a hit is a hit" cannot be pinned through a door that computes on demand.
    internal func isCached(_ key: Key) -> Bool {
        stored?.key == key
    }
}
