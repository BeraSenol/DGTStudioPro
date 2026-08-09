import Foundation

/// Live-search matching for the collection search fields. The fold is D30′'s — the identity
/// rule the rest of the app already lives by ("Bücher" is found by "bücher", not "bucher").
internal enum SearchMatch {

    /// One side of a comparison, normalized.
    internal static func folded(_ text: String) -> String {
        PlayerName.folded(text).lowercased()
    }

    /// Whitespace-separated terms; folding collapses runs first, so a single-space split is complete.
    internal static func terms(in query: String) -> [String] {
        folded(query).split(separator: " ").map(String.init)
    }

    /// AND over terms, OR over fields, `contains` per pair — the grammar every macOS search field
    /// teaches. Empty matches everything; callers gate on emptiness for clarity, not correctness.
    internal static func matches(query: String, fields: [String]) -> Bool {
        Query(query).matches(fields: fields)
    }

    /// A query folded once, matched many times — the one-shot form re-folded per row per keystroke.
    /// Delegates, so there is still exactly one matcher.
    internal struct Query {
        internal let needles: [String]

        internal init(_ text: String) {
            self.needles = SearchMatch.terms(in: text)
        }

        /// Empty matches everything; callers test only to skip the walk.
        internal var isEmpty: Bool { needles.isEmpty }

        internal func matches(fields: [String]) -> Bool {
            guard !needles.isEmpty else { return true }
            let haystacks = fields.map(SearchMatch.folded)
            return needles.allSatisfy { needle in
                haystacks.contains { $0.contains(needle) }
            }
        }
    }
}

// MARK: Token Semantics
/// The rule both vocabularies obey: **OR within a facet, AND across facets** — how every
/// faceted filter behaves, and the only reading where adding a chip never widens the set.

/// The Library's two non-text facets. Replaced a pair of single-valued optionals — "1-0 or 0-1"
/// was inexpressible.
internal enum LibrarySearchToken: Hashable, Identifiable, CaseIterable {
    case result(GameResult)
    case analyzed
    case unanalyzed

    internal static var allCases: [LibrarySearchToken] {
        GameResult.allCases.map(Self.result) + [.analyzed, .unanalyzed]
    }

    internal var id: String {
        switch self {
        case .result(let result): "result.\(result.rawValue)"
        case .analyzed:           "analyzed"
        case .unanalyzed:         "unanalyzed"
        }
    }

    /// The chip's text; results pair the word with PGN's own vocabulary — a chip without "1-0"
    /// makes the user translate.
    internal var displayName: String {
        switch self {
        case .result(.whiteWins): "White Wins (1-0)"
        case .result(.blackWins): "Black Wins (0-1)"
        case .result(.draw):      "Draw (1/2)"
        case .result(.ongoing):   "Ongoing (*)"
        case .analyzed:           "Analyzed"
        case .unanalyzed:         "Not Analyzed"
        }
    }

    internal var symbol: String {
        switch self {
        case .result:     "flag.checkered"
        case .analyzed:   "gear.badge.checkmark"
        case .unanalyzed: "gear.badge.xmark"
        }
    }

    /// Whether tokens admit this result + analysis state. Takes the facts, not a `PGN` — the caller
    /// reads the app's one spelling of "analyzed?", not second-guessed here.
    internal static func admit(
        _ tokens: [LibrarySearchToken],
        result: GameResult,
        isAnalyzed: Bool
    ) -> Bool {
        guard !tokens.isEmpty else { return true }

        let results = tokens.compactMap { token -> GameResult? in
            if case .result(let value) = token { return value }
            return nil
        }
        // An absent facet must not veto — "empty means yes" over chained optionals, whose failure mode
        // is silent.
        let resultAdmits = results.isEmpty || results.contains(result)

        let wantsAnalyzed = tokens.contains(.analyzed)
        let wantsUnanalyzed = tokens.contains(.unanalyzed)
        let analysisAdmits =
            (!wantsAnalyzed && !wantsUnanalyzed)
            || (wantsAnalyzed && isAnalyzed)
            || (wantsUnanalyzed && !isAnalyzed)

        return resultAdmits && analysisAdmits
    }
}

/// The Players tokens — rated-ness, the one non-text fact worth slicing on.
internal enum PlayersSearchToken: String, CaseIterable, Identifiable {
    case rated
    case provisional
    case unrated

    internal var id: String { rawValue }

    internal var displayName: String {
        switch self {
        case .rated:       "Rated"
        case .provisional: "Provisional"
        case .unrated:     "Unrated"
        }
    }

    internal var symbol: String {
        switch self {
        case .rated:       "chart.line.uptrend.xyaxis"
        case .provisional: "hourglass"
        case .unrated:     "minus.circle"
        }
    }

    /// Provisional ⊂ rated by design: "Rated" answers who has a number, "Provisional" whose is
    /// still settling. Selecting both == Rated — correct for an OR, worth knowing before it looks
    /// like a bug.
    internal func admits(_ rating: Glicko1.Rating?) -> Bool {
        switch self {
        case .rated:       rating != nil
        case .provisional: rating?.isProvisional == true
        case .unrated:     rating == nil
        }
    }

    /// OR across selected tokens; none admits everyone.
    internal static func admit(
        _ tokens: [PlayersSearchToken],
        rating: Glicko1.Rating?
    ) -> Bool {
        tokens.isEmpty || tokens.contains { $0.admits(rating) }
    }
}
