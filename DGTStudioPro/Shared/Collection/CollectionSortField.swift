import SwiftUI

/// A destination's sortable columns, named so something other than a table
/// header can choose one.
///
/// **This exists because a `Picker` cannot hold a `KeyPathComparator`.** Until
/// the View Options panel, sorting had exactly one door — clicking a `Table`
/// header — and `[KeyPathComparator<Row>]` was a perfectly good currency for
/// it, because the only thing that ever produced one was the table itself. A
/// panel has to *offer* the choices, which means they need identity, a display
/// name, and a stable spelling. None of those is derivable from a key path.
///
/// **And the round trip is the hard half, not the enum.** The table still
/// writes comparators back through its binding, so the panel and the header
/// have to agree about what "sorted by Date" means when the *other* one set
/// it. `matching(_:)` is that agreement, and it works because key paths are
/// `Equatable` — the panel reads the header's choice by comparing the
/// comparator's `keyPath` against each case's, rather than by keeping a
/// parallel copy of the current sort that could drift. One source, two
/// doors, which is the `CollapsibleSection` rule applied to sorting.
internal protocol CollectionSortField: RawRepresentable, CaseIterable, Hashable, Sendable
where RawValue == String {

    /// The row type the sort orders. Unconstrained on purpose — `PGN` is a
    /// `@Model` class and `RankedPlayer` is a value, and this grammar has no
    /// opinion about either.
    associatedtype Row

    /// The column header's own label, so a panel and a table cannot call the
    /// same sort two different things.
    var displayName: String { get }

    /// The identity `matching(_:)` compares on. Stated separately from
    /// `comparator` because a comparator carries an *order* as well, and the
    /// question "which field is this" must not depend on the direction.
    var keyPath: PartialKeyPath<Row> { get }

    var comparator: KeyPathComparator<Row> { get }

    /// The destination's shipped sort, stated here rather than in the store so
    /// an absent or unreadable preference and a fresh install land on the same
    /// order.
    static var defaultField: Self { get }
    static var defaultIsReverse: Bool { get }
}

extension CollectionSortField {

    /// Which field a table header just chose, or nil if it chose a column this
    /// enum does not name.
    ///
    /// **Nil is a real answer and must stay one.** The Library's Analysis
    /// column is unsortable, and a future column could be added with a
    /// `sortUsing:` and no case here — in which case the panel should show
    /// *no* selection rather than silently claiming the sort is something
    /// else. Pinned by `anUnknownKeyPathMatchesNoField`.
    internal static func matching(_ keyPath: PartialKeyPath<Row>) -> Self? {
        allCases.first { $0.keyPath == keyPath }
    }
}

/// A field plus a direction — one sort, in the form both doors can hold.
///
/// A `[KeyPathComparator]` is what `Table` speaks and it is a poor thing to
/// persist: it is not `Codable`, and an array says the destination supports
/// multi-level sorting, which neither of them does. This is the single sort
/// they actually have, and `comparators` is the adapter at the table's edge.
internal struct CollectionSort<Field: CollectionSortField>: Equatable, Sendable {

    internal var field: Field
    internal var isReverse: Bool

    internal init(field: Field, isReverse: Bool) {
        self.field = field
        self.isReverse = isReverse
    }

    internal static var `default`: Self {
        Self(field: Field.defaultField, isReverse: Field.defaultIsReverse)
    }

    /// What `Table` binds to.
    internal var comparators: [KeyPathComparator<Field.Row>] {
        var comparator = field.comparator
        comparator.order = isReverse ? .reverse : .forward
        return [comparator]
    }

    /// What a header click means, read back through `matching(_:)`.
    ///
    /// Failable rather than defaulting: a comparator this grammar cannot name
    /// should leave the panel showing nothing, not quietly rewrite the user's
    /// sort to the default the moment they click an unmapped column.
    internal init?(comparators: [KeyPathComparator<Field.Row>]) {
        guard let first = comparators.first,
              let field = Field.matching(first.keyPath) else { return nil }
        self.init(field: field, isReverse: first.order == .reverse)
    }

    // MARK: Persistence

    /// One string per destination rather than a field key and a direction key.
    ///
    /// `StorageKeys` is already carrying two dead keys and says in as many
    /// words that a third would stop being a footnote — four new ones for two
    /// sorts would be that point twice over. The pair is one fact and travels
    /// as one value; the separator is a colon because no raw value here
    /// contains one, which `everyFieldRawValueIsSeparatorSafe` pins rather
    /// than trusts.
    internal var storedValue: String {
        "\(field.rawValue):\(isReverse ? "reverse" : "forward")"
    }

    /// **An unreadable stored value is dropped, not repaired** — D45′'s rule
    /// for a retired `InspectorSection` raw value, and for the same reason.
    /// Retiring a column should cost no migration; the next write evicts the
    /// stale spelling, and until then the destination opens on its default.
    internal init?(storedValue: String) {
        let parts = storedValue.split(separator: ":", maxSplits: 1)
        guard parts.count == 2,
              let field = Field(rawValue: String(parts[0])) else { return nil }
        switch parts[1] {
        case "reverse": self.init(field: field, isReverse: true)
        case "forward": self.init(field: field, isReverse: false)
        default:        return nil
        }
    }
}

// MARK: - Library

/// The Library table's sortable columns.
///
/// Raw values are **hand-written and are a persistence contract** — they land
/// in `UserDefaults` under `StorageKeys.librarySort`. The D36′ trap in a new
/// place: letting them follow the Swift case names would mean a rename that
/// reads as a refactor silently resetting the user's sort. Pinned on the
/// literals by `libraryFieldRawValuesAreStable`.
///
/// `Analysis` is absent because its column is unsortable — there is no
/// `sortUsing:` on it, so no header can ever produce it.
internal enum LibrarySortField: String, CollectionSortField {
    case index         = "index"
    case white         = "white"
    case black         = "black"
    case result        = "result"
    case eco           = "eco"
    case checkmateType = "checkmateType"
    case event         = "event"
    case date          = "date"
    case round         = "round"

    internal typealias Row = PGN

    /// The column headers verbatim. `#` rather than "Index" because that is
    /// what the table says, and a panel naming it differently would be two
    /// names for one column.
    internal var displayName: String {
        switch self {
        case .index:         "#"
        case .white:         "White"
        case .black:         "Black"
        case .result:        "Result"
        case .eco:           "ECO"
        case .checkmateType: "Checkmate Type"
        case .event:         "Event"
        case .date:          "Date"
        case .round:         "Round"
        }
    }

    internal var keyPath: PartialKeyPath<PGN> {
        switch self {
        case .index:         \PGN.libraryIndex
        case .white:         \PGN.whiteDisplayName
        case .black:         \PGN.blackDisplayName
        case .result:        \PGN.result.rawValue
        case .eco:           \PGN.opening?.code
        case .checkmateType: \PGN.specialCheckmate?.rawValue
        case .event:         \PGN.event
        case .date:          \PGN.effectiveDate
        case .round:         \PGN.round
        }
    }

    internal var comparator: KeyPathComparator<PGN> {
        switch self {
        case .index:         KeyPathComparator(\PGN.libraryIndex)
        case .white:         KeyPathComparator(\PGN.whiteDisplayName)
        case .black:         KeyPathComparator(\PGN.blackDisplayName)
        case .result:        KeyPathComparator(\PGN.result.rawValue)
        case .eco:           KeyPathComparator(\PGN.opening?.code)
        case .checkmateType: KeyPathComparator(\PGN.specialCheckmate?.rawValue)
        case .event:         KeyPathComparator(\PGN.event)
        case .date:          KeyPathComparator(\PGN.effectiveDate)
        case .round:         KeyPathComparator(\PGN.round)
        }
    }

    /// `#` descending — the shipped launch order, and the one property that
    /// must not move: `LibraryDestination.defaultSortOrder` is the same
    /// statement one file over, and `theLibraryDefaultMatchesTheDestination`
    /// goes red if they diverge.
    internal static var defaultField: Self { .index }
    internal static var defaultIsReverse: Bool { true }
}

// MARK: - Players

/// The Players table's sortable columns.
///
/// Same persistence contract as `LibrarySortField` above.
///
/// **`rank` is a sort, not the ranking method.** D62′ decides what rank 1
/// *means* and persists separately; this decides whether the list is shown in
/// rank order. Both can be set and they answer different questions — the badge
/// travels with the player into every ordering.
internal enum PlayersSortField: String, CollectionSortField {
    case rank         = "rank"
    case name         = "name"
    case games        = "games"
    case wins         = "wins"
    case draws        = "draws"
    case losses       = "losses"
    case winRate      = "winRate"
    case specialMates = "specialMates"
    case rating       = "rating"
    case lastPlayed   = "lastPlayed"

    internal typealias Row = RankedPlayer

    internal var displayName: String {
        switch self {
        case .rank:         "Rank"
        case .name:         "Player"
        case .games:        "Games"
        case .wins:         "Wins"
        case .draws:        "Draws"
        case .losses:       "Losses"
        case .winRate:      "Win %"
        case .specialMates: "Special Mates"
        case .rating:       "Rating"
        case .lastPlayed:   "Last Played"
        }
    }

    internal var keyPath: PartialKeyPath<RankedPlayer> {
        switch self {
        case .rank:         \RankedPlayer.rank
        case .name:         \RankedPlayer.stats.name
        case .games:        \RankedPlayer.stats.games
        case .wins:         \RankedPlayer.stats.wins
        case .draws:        \RankedPlayer.stats.draws
        case .losses:       \RankedPlayer.stats.losses
        case .winRate:      \RankedPlayer.stats.winRate
        case .specialMates: \RankedPlayer.stats.specialMatesDelivered
        case .rating:       \RankedPlayer.rating?.mean
        case .lastPlayed:   \RankedPlayer.stats.lastPlayed
        }
    }

    internal var comparator: KeyPathComparator<RankedPlayer> {
        switch self {
        case .rank:         KeyPathComparator(\RankedPlayer.rank)
        case .name:         KeyPathComparator(\RankedPlayer.stats.name)
        case .games:        KeyPathComparator(\RankedPlayer.stats.games)
        case .wins:         KeyPathComparator(\RankedPlayer.stats.wins)
        case .draws:        KeyPathComparator(\RankedPlayer.stats.draws)
        case .losses:       KeyPathComparator(\RankedPlayer.stats.losses)
        case .winRate:      KeyPathComparator(\RankedPlayer.stats.winRate)
        case .specialMates: KeyPathComparator(\RankedPlayer.stats.specialMatesDelivered)
        case .rating:       KeyPathComparator(\RankedPlayer.rating?.mean)
        case .lastPlayed:   KeyPathComparator(\RankedPlayer.stats.lastPlayed)
        }
    }

    /// Rank ascending — the D11′ ladder, which `PlayersDestination`'s own
    /// default states independently and `defaultSortReproducesTheLadder`
    /// already pins against `PlayerRanking.wins`.
    internal static var defaultField: Self { .rank }
    internal static var defaultIsReverse: Bool { false }
}
