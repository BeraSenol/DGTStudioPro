import Foundation
import SwiftData

// MARK: Memo Keys

/// The Library's memoization currency, split out of the destination: the keys that decide when the
/// `GameRecord` projection and the narrowed row set are rebuilt. Nested so the names stay
/// `LibraryDestination.FoldKey` - the key-completeness suite constructs them directly.
extension LibraryDestination {

    /// Memo key for the `GameRecord` projection: content plus an analysis signal.
    /// The signal is the queue's counters, never the `evaluations` array - an array read would defeat the memo.
    /// Not private, so the key-completeness suite can construct one.
    struct FoldKey: Equatable {
        let content: CollectionFoldKey
        let running: PersistentIdentifier?
        let completed: Int
        let hasFailures: Bool
    }

    /// The narrowing inputs as one value: the projection's key plus everything filter,
    /// search and sort read. A missed input here is stale rows on screen - the suite pins the
    /// field list, which is the only defence a memo key has.
    struct NarrowKey: Equatable {
        let fold: FoldKey
        let filter: LibraryFilter.Signature?
        let query: String
        let tokens: [LibrarySearchToken]
        let sort: [KeyPathComparator<PGN>]
    }

    /// Narrowed pairs and their sorted projection, cached as one unit - the sort was the last
    /// unconditional per-render O(n log n) (the ECO comparator rehydrates per comparison, censused).
    struct NarrowResult {
        let pairs: [(game: PGN, record: GameRecord)]
        let sorted: [PGN]
    }
}
