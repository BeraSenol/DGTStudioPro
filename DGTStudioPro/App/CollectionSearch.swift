//
//  CollectionSearch.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 02/08/2026.
//

import Foundation

/// Live-search matching for the collection destinations' toolbar search
/// fields (2 Aug 2026).
///
/// The fold is D30′'s, deliberately: `PlayerName.folded` + `lowercased()`,
/// the same normalization the smart-tag string rules apply to both sides of
/// a comparison. Search is therefore case-insensitive and
/// whitespace-tolerant, and **preserves diacritics** — "Bücher" is found by
/// "bücher" and not by "bucher" — because that is the identity rule the
/// whole app plays by (D9′), and a search folding more aggressively than
/// the tags would find games no smart-tag rule can express.
internal enum SearchMatch {

    /// One side of a comparison, normalized.
    internal static func folded(_ text: String) -> String {
        PlayerName.folded(text).lowercased()
    }

    /// Whitespace-separated terms of a query. Folding first collapses
    /// whitespace runs, so a plain single-space split is complete.
    internal static func terms(in query: String) -> [String] {
        folded(query).split(separator: " ").map(String.init)
    }

    /// True when **every** term occurs in **at least one** field — AND over
    /// terms, OR over fields, `contains` per pair: the grammar every macOS
    /// search field teaches ("carlsen 1-0" narrows, it doesn't union). An
    /// empty or whitespace-only query matches everything, so callers gate
    /// on emptiness for clarity, not correctness.
    ///
    /// The one-shot spelling. It folds the query per call, which is right
    /// for a single ask and waste inside a filter loop — both destinations
    /// fold once through `Query` and match many times (4 Aug 2026).
    internal static func matches(query: String, fields: [String]) -> Bool {
        Query(query).matches(fields: fields)
    }

    /// A query folded once, matched many times.
    ///
    /// `matches(query:fields:)` used to re-fold and re-split the same query
    /// string for every row a filter asked about — per game, per keystroke,
    /// in the most body-invalidation-prone destinations in the app. The
    /// needles never change between rows; only the fields do. This is the
    /// same grammar with the query half hoisted, and the one-shot form above
    /// now delegates here, so there is still exactly one matcher.
    internal struct Query {
        internal let needles: [String]

        internal init(_ text: String) {
            self.needles = SearchMatch.terms(in: text)
        }

        /// Empty matches everything — the matcher's own contract. Callers
        /// test it only to skip the walk, never for correctness.
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

// `LibrarySearchScope` lived here until 2 Aug 2026, retired the day it
// shipped: field scopes on the Library search never earned their bar. A
// query already names its field — "1-0" is a result, "C60" an opening, a
// surname a player — so the flat field set answers everything the scopes
// did with one fewer control. Re-adding it means finding a query the flat
// set answers *wrongly*, not reverting a diff. (Players' scope below
// survives because rated-ness isn't text at all.)

// MARK: Token Semantics

/// The rule both token vocabularies below obey, stated once because it is the
/// part a reader has to trust and cannot see: **OR within a facet, AND across
/// facets.**
///
/// Two result tokens widen (1-0 *or* 0-1 — "show me decisive games"); a result
/// token and an analysis token narrow (decisive *and* unanalyzed). That is how
/// every faceted filter behaves, and it is the only reading under which adding
/// a second token of the same kind isn't a no-op that empties the list.
///
/// No tokens means no filtering. That falls out of the representation rather
/// than needing an `.all` case to carry it — the trick D45′ uses by storing
/// the *collapsed* sections, and the reason `PlayersSearchToken` has three
/// cases where its scope-bar ancestor had four.

/// The Library search field's tokens — the two non-text facets of a game.
///
/// Replaced the `resultFilter` / `analysisFilter` pair of optionals on
/// 3 Aug 2026. The optionals were single-valued by construction: "1-0 or 0-1"
/// was unrepresentable, and nil was doing double duty as "any". Tokens are a
/// collection, so both went away — at the cost that the caller now has to say
/// what two tokens of one kind mean, which is what the note above settles.
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

    /// The chip's text. Results pair the word with PGN's own vocabulary —
    /// the raw value is the thing on disk, and a chip reading "White Wins"
    /// with no "1-0" makes the user translate.
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

    /// Whether `tokens` admit a game with this result and analysis state.
    ///
    /// Takes the two facts rather than a `PGN` so the rule stays a pure
    /// function over values (D10′) — the caller reads `AnalysisGlyph.isAnalyzed`,
    /// which is the app's one spelling of "analyzed?" and must not be
    /// second-guessed here.
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
        // An absent facet must not veto. Written as "empty means yes" rather
        // than as a chain of optionals because the failure mode of the other
        // spelling is silent: one forgotten `isEmpty` and every game with an
        // analysis token disappears the moment you add a result token.
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

/// The Players search field's tokens — rated-ness, because a player's name is
/// their only text: the query searches it, and these slice by the one
/// non-text fact worth slicing on.
///
/// Was `PlayersSearchScope`, a four-case scope bar, until 3 Aug 2026. Two
/// changes came with the move to tokens. The bar only existed while the field
/// was focused, so a rating filter vanished from view the moment you dismissed
/// search — a chip stays put and stays removable. And `.all` is **deleted**
/// rather than kept: an empty token list is what "all" means now, so the case
/// could never be selected, and a case nothing can produce is the shape D40′
/// spent a milestone learning to recognise.
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

    /// Provisional is a subset of rated (deviation above the display
    /// threshold — `Glicko1.Rating.isProvisional`), so the two overlap by
    /// design: "Rated" answers *who has a number*, "Provisional" answers
    /// *whose number is still settling*. Selecting both is therefore the same
    /// as selecting Rated, which is the correct behaviour for an OR and worth
    /// knowing before it looks like a bug.
    internal func admits(_ rating: Glicko1.Rating?) -> Bool {
        switch self {
        case .rated:       rating != nil
        case .provisional: rating?.isProvisional == true
        case .unrated:     rating == nil
        }
    }

    /// OR across the selected tokens; no tokens admits everyone.
    internal static func admit(
        _ tokens: [PlayersSearchToken],
        rating: Glicko1.Rating?
    ) -> Bool {
        tokens.isEmpty || tokens.contains { $0.admits(rating) }
    }
}
