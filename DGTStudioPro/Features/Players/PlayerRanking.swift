import Foundation

/// How the ladder is ordered — which is to say, what rank **1** means (D62′).
///
/// **This makes D11′ the default rather than the only answer.** That decision
/// fixed the Rankings order as wins ↓, win rate ↓, key ↑ and argued for it: the
/// ladder should reward showing up and winning, not a percentage a
/// three-game player can top. All of that still holds — it is why `.wins` is
/// the shipped default and why it delegates to `PlayerStats.rankingOrder`
/// rather than restating the chain. What changed is only that the other two
/// readings are now reachable instead of being arguments in a document.
///
/// **Ranking is not sorting, and the two are deliberately separate.** A column
/// sort decides the sequence rows appear in; this decides the *number on the
/// badge*, which is a fact about the player and travels with them into every
/// ordering (that sentence is D48′'s and survives unchanged). Change the method
/// and the badges renumber; change the sort and they do not.
///
/// Every case ends in the same total tiebreak — `key` ascending, which is
/// unique per player and locale-free. D10′'s rule is that a fold's output is
/// only as deterministic as its ordering, so each of these chains down to
/// something that cannot tie; a method that bottomed out in win rate would
/// reorder two identical players between launches.
internal enum PlayerRanking: String, CaseIterable, Identifiable, Sendable {

    /// D11′'s comparator, unchanged and undisplaced.
    case wins    = "wins"
    /// Win rate first, which is the reading D11′ rejected as the *default* and
    /// never claimed was worthless — a small-sample player tops it, and that is
    /// the point of asking for it deliberately.
    case winRate = "winRate"
    /// Glicko-1 mean, the only method that reads a number this enum's other two
    /// cases cannot see.
    case rating  = "rating"

    internal var id: String { rawValue }

    internal var displayName: String {
        switch self {
        case .wins:    "Rank by Wins"
        case .winRate: "Rank by Win %"
        case .rating:  "Rank by Rating"
        }
    }

    /// What the toolbar's menu label reads once a method is chosen — the noun
    /// alone, because the menu already says what it is a menu of.
    internal var shortName: String {
        switch self {
        case .wins:    "Wins"
        case .winRate: "Win %"
        case .rating:  "Rating"
        }
    }

    // MARK: Ordering

    /// One player's ranking inputs.
    ///
    /// A pair rather than `PlayerStats` alone, and that is the structural
    /// consequence of adding `.rating`: a rating is **not** a stat. It comes
    /// from `Glicko1.histories`, a separate fold over the same records, so
    /// `PlayerStats.rankingOrder`'s signature — two `PlayerStats` — cannot
    /// express the third method. Widening `PlayerStats` to carry a rating was
    /// the alternative and was rejected at D10′'s line: the stats fold and the
    /// rating fold are independent by design, and merging them so one
    /// comparator could see both would make every `PlayerStats` consumer carry
    /// a Glicko dependency it has no use for.
    internal typealias Entry = (stats: PlayerStats, rating: Glicko1.Rating?)

    /// Strict ordering: `true` when `lhs` ranks **above** `rhs`.
    internal func precedes(_ lhs: Entry, _ rhs: Entry) -> Bool {
        switch self {
        case .wins:
            // Delegated, never restated. D11′'s chain lives at
            // `PlayerStats.rankingOrder` and this case is the reason that
            // function still has a caller in production.
            return PlayerStats.rankingOrder(lhs.stats, rhs.stats)

        case .winRate:
            if lhs.stats.winRate != rhs.stats.winRate {
                return lhs.stats.winRate > rhs.stats.winRate
            }
            // Wins second, so among equal percentages the player who has done
            // it more often leads — the same instinct D11′ put first, applied
            // where it no longer decides the headline.
            if lhs.stats.wins != rhs.stats.wins {
                return lhs.stats.wins > rhs.stats.wins
            }
            return lhs.stats.key < rhs.stats.key

        case .rating:
            // **Unrated players rank last, always**, and this is the arm worth
            // reading twice. A nil rating is not a low rating: it means the
            // player has no *decided* games against another named player, so
            // Glicko has never had an input for them. Sorting them as 1500
            // would drop them into the middle of the ladder ahead of real
            // players who have earned less, which reads as a bug. Last is the
            // honest place for "no opinion".
            switch (lhs.rating, rhs.rating) {
            case let (left?, right?) where left.mean != right.mean:
                return left.mean > right.mean
            case (nil, .some):
                return false
            case (.some, nil):
                return true
            default:
                break
            }
            if lhs.stats.wins != rhs.stats.wins {
                return lhs.stats.wins > rhs.stats.wins
            }
            return lhs.stats.key < rhs.stats.key
        }
    }

    /// Assigns 1-based ranks under this method.
    ///
    /// The whole ladder in one place, so `PlayersDestination` threads a method
    /// rather than knowing how ranks are made. Sorting *then* enumerating is
    /// what keeps rank a consequence of the order rather than a value anyone
    /// has to maintain.
    internal func ranked(_ entries: [Entry]) -> [RankedPlayer] {
        entries
            .sorted(by: precedes)
            .enumerated()
            .map { RankedPlayer(rank: $0.offset + 1, stats: $0.element.stats, rating: $0.element.rating) }
    }
}
