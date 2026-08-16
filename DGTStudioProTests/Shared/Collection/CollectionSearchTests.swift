import Foundation
import Testing
@testable import DGTStudioPro

/// Nonisolated deliberately - the search types are pure values, and the
/// suite's isolation matches its subject.
struct SearchMatchTests {

    @Test func emptyAndWhitespaceQueriesMatchEverything() {
        #expect(SearchMatch.matches(query: "", fields: ["anything"]))
        #expect(SearchMatch.matches(query: "   ", fields: []))
    }

    @Test func containsIsCaseInsensitive() {
        #expect(SearchMatch.matches(query: "CARLSEN", fields: ["Magnus Carlsen"]))
        #expect(SearchMatch.matches(query: "carlsen", fields: ["MAGNUS CARLSEN"]))
    }

    @Test func whitespaceFoldsOnBothSides() {
        #expect(SearchMatch.matches(query: "  magnus   carlsen ", fields: ["Magnus  Carlsen"]))
    }

    /// The semantics, pinned on purpose: the fold preserves
    /// diacritics, so search agrees with player identity and smart-tag
    /// matching about which strings are the same string.
    @Test func diacriticsArePreservedByTheFold() {
        #expect(SearchMatch.matches(query: "bücher", fields: ["Bücher"]))
        #expect(!SearchMatch.matches(query: "bucher", fields: ["Bücher"]))
    }

    /// AND over terms, OR over fields: every term must land somewhere, and
    /// different terms may land in different fields.
    @Test func everyTermMustLandInSomeField() {
        let fields = ["Magnus Carlsen", "1-0", "World Championship"]
        #expect(SearchMatch.matches(query: "carlsen 1-0", fields: fields))
        #expect(SearchMatch.matches(query: "world carlsen", fields: fields))
        #expect(!SearchMatch.matches(query: "carlsen 0-1", fields: fields))
    }

    @Test func absentTermFails() {
        #expect(!SearchMatch.matches(query: "kasparov", fields: ["Magnus Carlsen"]))
        #expect(!SearchMatch.matches(query: "kasparov", fields: []))
    }

    /// `Query` is the hoisted spelling (4 Aug 2026) - needles fold at
    /// construction, so a filter loop folds the query exactly once however
    /// many rows it walks. The one-shot `matches(query:fields:)` delegates
    /// here, which is what keeps this one grammar rather than two agreeing
    /// ones - so the pins are on the *hoist* itself: construction does the
    /// folding, and matching consumes the already-folded needles.
    @Test func queryFoldsAtConstructionAndMatchesFromNeedles() {
        let query = SearchMatch.Query("  BÜCHER   1-0 ")
        #expect(query.needles == ["bücher", "1-0"])
        #expect(!query.isEmpty)
        #expect(query.matches(fields: ["Bücher", "1-0"]))
        #expect(!query.matches(fields: ["Bucher", "1-0"]))

        let blank = SearchMatch.Query("   ")
        #expect(blank.isEmpty)
        #expect(blank.matches(fields: []))
    }
}

/// Was `PlayersSearchScopeTests`. The per-case assertions survive verbatim
/// minus `.all`, which was deleted with the scope bar - an empty token list
/// is what "all" means now, so the case could never be selected.
struct PlayersSearchTokenTests {

    /// Deviations either side of the provisional threshold (110): the
    /// token's answers are derived from `isProvisional`, not restated.
    private let provisional = Glicko1.Rating(mean: 1500, deviation: 218.6)
    private let settled = Glicko1.Rating(mean: 1620, deviation: 45)

    @Test func nilRatingIsUnratedOnly() {
        #expect(!PlayersSearchToken.rated.admits(nil))
        #expect(!PlayersSearchToken.provisional.admits(nil))
        #expect(PlayersSearchToken.unrated.admits(nil))
    }

    /// Provisional is a subset of rated - both tokens admit it, which is
    /// the documented overlap, not a defect.
    @Test func provisionalRatingIsRatedAndProvisional() {
        #expect(PlayersSearchToken.rated.admits(provisional))
        #expect(PlayersSearchToken.provisional.admits(provisional))
        #expect(!PlayersSearchToken.unrated.admits(provisional))
    }

    @Test func settledRatingIsRatedOnly() {
        #expect(PlayersSearchToken.rated.admits(settled))
        #expect(!PlayersSearchToken.provisional.admits(settled))
        #expect(!PlayersSearchToken.unrated.admits(settled))
    }

    /// **No tokens admits everyone**, which is the case that replaced `.all`.
    /// If this ever regressed to "empty matches nothing", the Players list
    /// would come up blank on a fresh launch - visible instantly, but only
    /// if someone launches; the test is what catches it first.
    @Test func noTokensAdmitsEveryone() {
        #expect(PlayersSearchToken.admit([], rating: nil))
        #expect(PlayersSearchToken.admit([], rating: settled))
    }

    /// OR, not AND. Rated and Unrated are disjoint, so under an AND reading
    /// selecting both would empty the list - the shape that makes a
    /// multi-select filter feel broken.
    @Test func multipleTokensUnionRatherThanIntersect() {
        let both: [PlayersSearchToken] = [.rated, .unrated]
        #expect(PlayersSearchToken.admit(both, rating: settled))
        #expect(PlayersSearchToken.admit(both, rating: nil))

        #expect(!PlayersSearchToken.admit([.unrated], rating: settled))
        #expect(!PlayersSearchToken.admit([.rated], rating: nil))
    }
}

/// The Library's faceted rule: **OR within a facet, AND across facets**.
/// Every test here exists because the other reading is plausible and its
/// failure is a list that silently empties.
struct LibrarySearchTokenTests {

    @Test func noTokensAdmitEverything() {
        #expect(LibrarySearchToken.admit([], result: .draw, isAnalyzed: false))
        #expect(LibrarySearchToken.admit([], result: .whiteWins, isAnalyzed: true))
    }

    /// Two results widen. Under an AND reading this is unsatisfiable - a
    /// game has one result - so "decisive games" would show nothing at all.
    @Test func twoResultTokensUnion() {
        let decisive: [LibrarySearchToken] = [.result(.whiteWins), .result(.blackWins)]
        #expect(LibrarySearchToken.admit(decisive, result: .whiteWins, isAnalyzed: false))
        #expect(LibrarySearchToken.admit(decisive, result: .blackWins, isAnalyzed: true))
        #expect(!LibrarySearchToken.admit(decisive, result: .draw, isAnalyzed: false))
        #expect(!LibrarySearchToken.admit(decisive, result: .ongoing, isAnalyzed: false))
    }

    /// Across facets it narrows - and this is the pin for the "empty facet
    /// must not veto" guard. A result token alone must not exclude analyzed
    /// games, and an analysis token alone must not exclude any result.
    @Test func facetsIntersectWithoutVetoingEachOther() {
        #expect(LibrarySearchToken.admit([.result(.draw)], result: .draw, isAnalyzed: true))
        #expect(LibrarySearchToken.admit([.result(.draw)], result: .draw, isAnalyzed: false))
        #expect(LibrarySearchToken.admit([.unanalyzed], result: .ongoing, isAnalyzed: false))

        let drawnAndUnanalyzed: [LibrarySearchToken] = [.result(.draw), .unanalyzed]
        #expect(LibrarySearchToken.admit(drawnAndUnanalyzed, result: .draw, isAnalyzed: false))
        #expect(!LibrarySearchToken.admit(drawnAndUnanalyzed, result: .draw, isAnalyzed: true))
        #expect(!LibrarySearchToken.admit(drawnAndUnanalyzed, result: .whiteWins, isAnalyzed: false))
    }

    /// Both analysis tokens is the same as neither. Harmless, and asserted
    /// so it stays harmless: under an AND reading it is unsatisfiable, which
    /// would empty the list for a selection that reads as "show me both".
    @Test func bothAnalysisTokensAdmitEitherState() {
        let both: [LibrarySearchToken] = [.analyzed, .unanalyzed]
        #expect(LibrarySearchToken.admit(both, result: .draw, isAnalyzed: true))
        #expect(LibrarySearchToken.admit(both, result: .draw, isAnalyzed: false))
    }

    /// The suggestion list is built by subtracting applied tokens from
    /// `allCases`, so the identities have to be distinct - two cases sharing
    /// an `id` would make one chip un-removable and the other undismissable
    /// from the suggestions. The compiler cannot check hand-written ids.
    @Test func everyTokenHasADistinctIdentity() {
        let ids = LibrarySearchToken.allCases.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(LibrarySearchToken.allCases.count == GameResult.allCases.count + 2)
    }
}
