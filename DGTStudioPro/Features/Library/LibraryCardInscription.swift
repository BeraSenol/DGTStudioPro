import Foundation

/// What the Library card writes on its document sheet - the View Options "Icon" picker's
/// vocabulary (23 Aug 2026, by request). Library-only: the Players card is a monogram with no
/// sheet to inscribe, which is why this is not a `CollectionViewOptionsSubject`-keyed pair.
///
/// Raw values are persisted under `StorageKeys.libraryCardInscription`; a stored spelling this
/// build no longer understands falls back to `.index` at the read - the retired-raw-value rule
/// the view modes and sorts already follow.
enum LibraryCardInscription: String, CaseIterable, Identifiable, Sendable {

    case index
    case result
    case date
    case round

    var id: Self { self }

    /// Picker labels. "Index", not the list column's "#" - a one-glyph menu row reads as a
    /// rendering fault, and the column header's constraint (34 pt) is not this menu's.
    var displayName: String {
        switch self {
        case .index:  "Index"
        case .result: "Result"
        case .date:   "Date"
        case .round:  "Round"
        }
    }

    // MARK: Content

    /// What the sheet draws - one line, or the date's two-tier calendar form (month abbreviated
    /// above, day large below, a tear-off calendar sheet).
    enum Content: Equatable {
        case single(String)
        case stacked(top: String, bottom: String)
    }

    /// Pure derivation from the four facts a card holds, so the mapping is pinnable without a
    /// view. The placeholder rule is the index's existing one: an absent value writes
    /// `RosterSummary.displayUnknown`, never an empty sheet - a blank sheet reads as a load
    /// failure, a dash as a fact about the game.
    ///
    /// `locale` is a parameter with the live default so the date arm is deterministic under
    /// test; production callers pass nothing.
    func content(
        index: Int?,
        result: GameResult,
        date: Date?,
        round: Int?,
        locale: Locale = .autoupdatingCurrent
    ) -> Content {
        switch self {
        case .index:
            return .single(index.map(String.init) ?? RosterSummary.displayUnknown)
        case .result:
            return .single(Self.compactResult(result))
        case .round:
            return .single(RosterSummary.displayRound(round))
        case .date:
            // `game.date`, nil for an undated file - the caption under the card reads the same
            // field through `displayDate`, so sheet and caption cannot disagree about whether
            // the game has a date.
            guard let date else { return .single(RosterSummary.displayUnknown) }
            let month = date.formatted(Date.FormatStyle(locale: locale).month(.abbreviated))
            let day = date.formatted(Date.FormatStyle(locale: locale).day())
            return .stacked(top: month.uppercased(with: locale), bottom: day)
        }
    }

    /// The card's compact result: **"½-½" for a draw, not the stored "1/2-1/2"** - the sheet's
    /// writable width is ~30 pt at the default glyph, and seven characters under
    /// `minimumScaleFactor` render as a smudge. The figure form is *this surface's* spelling
    /// only, the `Glicko1` precedent (its provisional marker became `*` for a 120 pt cell);
    /// every other surface keeps the PGN raw value, and the serializer never sees this string.
    static func compactResult(_ result: GameResult) -> String {
        switch result {
        case .whiteWins: "1-0"
        case .blackWins: "0-1"
        case .draw:      "½-½"
        case .ongoing:   GameResult.ongoing.rawValue
        }
    }
}
