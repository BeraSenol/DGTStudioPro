import SwiftUI

/// A destination's sortable columns, named so something other than a table header can choose
/// one — a `Picker` cannot hold a `KeyPathComparator`. The round trip (panel sets, header shows,
/// header sets, panel shows) is the hard half.
protocol CollectionSortField: RawRepresentable, CaseIterable, Hashable, Sendable
where RawValue == String {

    /// The row type. Unconstrained on purpose — `PGN` is a `@Model` class, `RankedPlayer` a value.
    associatedtype Row

    /// The column header's own label — a panel must not call the same sort something else.
    var displayName: String { get }

    /// The identity `matching(_:)` compares on. Separate from `comparator`, which also carries an
    /// *order* — "which field" must not depend on direction.
    var keyPath: PartialKeyPath<Row> { get }

    var comparator: KeyPathComparator<Row> { get }

    /// The shipped sort, stated here so an unreadable preference and a fresh install agree.
    static var defaultField: Self { get }
    static var defaultIsReverse: Bool { get }
}

extension CollectionSortField {

    /// Which field a header chose, or nil for a column this enum does not name — **nil is a real
    /// answer** (the Analysis column is deliberately unmapped). Pinned.
    static func matching(_ keyPath: PartialKeyPath<Row>) -> Self? {
        allCases.first { $0.keyPath == keyPath }
    }
}

/// A field plus a direction. `[KeyPathComparator]` is what `Table` speaks and a poor thing to
/// persist: not `Codable`, and an array claims multi-level sorting neither destination has.
struct CollectionSort<Field: CollectionSortField>: Equatable, Sendable {

    var field: Field
    var isReverse: Bool

    init(field: Field, isReverse: Bool) {
        self.field = field
        self.isReverse = isReverse
    }

    static var `default`: Self {
        Self(field: Field.defaultField, isReverse: Field.defaultIsReverse)
    }

    /// What `Table` binds to.
    var comparators: [KeyPathComparator<Field.Row>] {
        var comparator = field.comparator
        comparator.order = isReverse ? .reverse : .forward
        return [comparator]
    }

    /// Failable rather than defaulting: an unmapped comparator should leave the panel showing
    /// nothing, not quietly rewrite the user's sort.
    init?(comparators: [KeyPathComparator<Field.Row>]) {
        guard let first = comparators.first,
              let field = Field.matching(first.keyPath) else { return nil }
        self.init(field: field, isReverse: first.order == .reverse)
    }

    // MARK: Persistence

    /// One string per destination (field + direction, colon-separated — no raw value contains one,
    /// pinned). Four keys for two values would double the dead-key risk `StorageKeys` records.
    var storedValue: String {
        "\(field.rawValue):\(isReverse ? "reverse" : "forward")"
    }

    /// An unreadable stored value is dropped, not repaired (the rule): retiring a column costs
    /// no migration; the next write evicts.
    init?(storedValue: String) {
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

/// The Library table's sortable columns. Raw values are **hand-written persistence contracts**
/// (`StorageKeys.librarySort`) — the trap; pinned on literals.
enum LibrarySortField: String, CollectionSortField {
    case index         = "index"
    case white         = "white"
    case black         = "black"
    case result        = "result"
    case eco           = "eco"
    case checkmateType = "checkmateType"
    case event         = "event"
    case date          = "date"
    case round         = "round"

    typealias Row = PGN

    /// The column headers verbatim — `#`, not "Index": two names for one column otherwise.
    var displayName: String {
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

    var keyPath: PartialKeyPath<PGN> {
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

    var comparator: KeyPathComparator<PGN> {
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

    /// `#` descending — the shipped launch order; `theLibraryDefaultMatchesTheDestination` goes red
    /// if this and `LibraryDestination.defaultSortOrder` diverge.
    static var defaultField: Self { .index }
    static var defaultIsReverse: Bool { true }
}

// MARK: - Players

/// The Players table's columns — same persistence contract. **`rank` is a sort, not the ranking
/// method** (the ranking method decides what rank 1 means; this decides row order).
enum PlayersSortField: String, CollectionSortField {
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

    typealias Row = RankedPlayer

    var displayName: String {
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

    var keyPath: PartialKeyPath<RankedPlayer> {
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

    var comparator: KeyPathComparator<RankedPlayer> {
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

    /// Rank ascending — the ladder; `defaultSortReproducesTheLadder` pins it.
    static var defaultField: Self { .rank }
    static var defaultIsReverse: Bool { false }
}
