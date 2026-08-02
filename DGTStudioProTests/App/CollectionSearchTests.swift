//
//  CollectionSearchTests.swift
//  DGTStudioProTests
//
//  Created by Supreme Leader on 02/08/2026.
//

import Foundation
import Testing
@testable import DGTStudioPro

/// Nonisolated deliberately — the search types are pure values, and the
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

    /// The D30′/D9′ semantics, pinned on purpose: the fold preserves
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
}

struct PlayersSearchScopeTests {

    /// Deviations either side of the provisional threshold (110): the
    /// scope's answers are derived from `isProvisional`, not restated.
    private let provisional = Glicko1.Rating(mean: 1500, deviation: 218.6)
    private let settled = Glicko1.Rating(mean: 1620, deviation: 45)

    @Test func nilRatingIsUnratedOnly() {
        #expect(PlayersSearchScope.all.admits(nil))
        #expect(!PlayersSearchScope.rated.admits(nil))
        #expect(!PlayersSearchScope.provisional.admits(nil))
        #expect(PlayersSearchScope.unrated.admits(nil))
    }

    /// Provisional is a subset of rated — both scopes admit it, which is
    /// the documented overlap, not a defect.
    @Test func provisionalRatingIsRatedAndProvisional() {
        #expect(PlayersSearchScope.all.admits(provisional))
        #expect(PlayersSearchScope.rated.admits(provisional))
        #expect(PlayersSearchScope.provisional.admits(provisional))
        #expect(!PlayersSearchScope.unrated.admits(provisional))
    }

    @Test func settledRatingIsRatedOnly() {
        #expect(PlayersSearchScope.all.admits(settled))
        #expect(PlayersSearchScope.rated.admits(settled))
        #expect(!PlayersSearchScope.provisional.admits(settled))
        #expect(!PlayersSearchScope.unrated.admits(settled))
    }
}
