import Foundation

/// What rank **1** means - the wins ladder is the default rather than the only answer; its
/// case delegates to `PlayerStats.rankingOrder` rather than restating the chain.
enum PlayerRanking: String, CaseIterable, Identifiable, Sendable {

    /// The comparator, unchanged and undisplaced.
    case wins    = "wins"
    /// The reading rejected as the *default* and never called worthless - a small-sample
    /// player tops it, which is the point of asking deliberately.
    case winRate = "winRate"
    /// Glicko-1 mean - the one method reading a number the other two cannot see.
    case rating  = "rating"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wins:    "Rank by Wins"
        case .winRate: "Rank by Win %"
        case .rating:  "Rank by Rating"
        }
    }

    /// The toolbar label once chosen - the noun alone; the menu already says what it is a menu of.
    var shortName: String {
        switch self {
        case .wins:    "Wins"
        case .winRate: "Win %"
        case .rating:  "Rating"
        }
    }

    // MARK: Ordering

    /// A pair, not `PlayerStats` alone - the structural consequence of `.rating`: a rating is not a
    /// stat; it comes from a separate fold, and widening `PlayerStats` would hand every consumer a
    /// Glicko dependency.
    typealias Entry = (stats: PlayerStats, rating: Glicko1.Rating?)

    /// Strict ordering: `true` when `lhs` ranks **above** `rhs`.
    func precedes(_ lhs: Entry, _ rhs: Entry) -> Bool {
        switch self {
        case .wins:
            // Delegated, never restated - this case is why `rankingOrder` still has a production caller.
            return PlayerStats.rankingOrder(lhs.stats, rhs.stats)

        case .winRate:
            if lhs.stats.winRate != rhs.stats.winRate {
                return lhs.stats.winRate > rhs.stats.winRate
            }
            // Wins second among equal percentages - the instinct, applied where it no longer decides
            // the headline.
            if lhs.stats.wins != rhs.stats.wins {
                return lhs.stats.wins > rhs.stats.wins
            }
            return lhs.stats.key < rhs.stats.key

        case .rating:
            // **Unrated ranks last, always**: a nil rating is no opinion, not a low one - sorting it as
            // 1500 would drop it mid-ladder ahead of players who earned less.
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

    /// 1-based ranks under this method - the whole ladder in one place, so rank stays a consequence
    /// of the order, never a value anyone assigns.
    func ranked(_ entries: [Entry]) -> [RankedPlayer] {
        entries
            .sorted(by: precedes)
            .enumerated()
            .map { RankedPlayer(rank: $0.offset + 1, stats: $0.element.stats, rating: $0.element.rating) }
    }
}
