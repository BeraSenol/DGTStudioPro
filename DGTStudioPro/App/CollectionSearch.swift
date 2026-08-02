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
    internal static func matches(query: String, fields: [String]) -> Bool {
        let needles = terms(in: query)
        guard !needles.isEmpty else { return true }
        let haystacks = fields.map(folded)
        return needles.allSatisfy { needle in
            haystacks.contains { $0.contains(needle) }
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

/// The Players search field's scopes — rated-ness, because a player's name
/// is their only text: the query searches it, and the scope slices by the
/// one non-text fact worth slicing on.
internal enum PlayersSearchScope: String, CaseIterable, Identifiable {
    case all
    case rated
    case provisional
    case unrated

    internal var id: String { rawValue }

    internal var displayName: String {
        switch self {
        case .all:         "All"
        case .rated:       "Rated"
        case .provisional: "Provisional"
        case .unrated:     "Unrated"
        }
    }

    /// Provisional is a subset of rated (deviation above the display
    /// threshold — `Glicko1.Rating.isProvisional`), so the two scopes
    /// overlap by design: "Rated" answers *who has a number*,
    /// "Provisional" answers *whose number is still settling*.
    internal func admits(_ rating: Glicko1.Rating?) -> Bool {
        switch self {
        case .all:         true
        case .rated:       rating != nil
        case .provisional: rating?.isProvisional == true
        case .unrated:     rating == nil
        }
    }
}
