//
//  TagRuleTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 23/07/2026.
//

import Testing
import Foundation
@testable import DGTStudioPro

/// The rule engine (M-prs.5), nonisolated — `TagRule` evaluates pure
/// `GameRecord`s, so the fixture-context idiom the old enum suite needed
/// died with the enum. Pins every kind's comparisons, the recorded edge
/// rules (empty text matches nothing, unknowns never match, either-seat
/// player, case folding), and the any/all/zero combinator.
///
/// Split from the former `SmartTagTests.swift` so each suite mirrors its
/// source file: the model half (`@MainActor`, realized `@Model`s) lives in
/// `SmartTagModelTests.swift`. The isolation split is the reason they can't
/// share a file comfortably — the same shape as
/// `DGTSessionRecorderTests` / `DGTSessionRecordingTests`.
@Suite("Tag Rules")
struct TagRuleTests {
    
    // MARK: Helpers
    
    private func record(
        white: String? = "Alice",
        black: String? = "Bob",
        result: GameResult = .whiteWins,
        endedInMate: Bool = false,
        date: Date? = nil,
        event: String = "Club Night",
        site: String = "Home",
        name: String = "Alice vs Bob",
        round: Int? = nil,
        plyCount: Int = 40,
        hasAnalysis: Bool = false,
        isTimed: Bool = false
    ) -> GameRecord {
        GameRecord(
            white: white.map { .init(key: $0.lowercased(), name: $0) },
            black: black.map { .init(key: $0.lowercased(), name: $0) },
            result: result,
            endedInMate: endedInMate,
            date: date,
            importedAt: Date(timeIntervalSince1970: 1_000),
            contentHash: "hash",
            event: event,
            site: site,
            name: name,
            round: round,
            plyCount: plyCount,
            hasAnalysis: hasAnalysis,
            isTimed: isTimed
        )
    }
    
    // MARK: String Fields
    
    @Test func stringComparisonsFoldCase() {
        let game = record(white: "Anish Giri")
        
        #expect(TagRule(field: .white, comparison: .contains, text: "GIRI").matches(game))
        #expect(TagRule(field: .white, comparison: .equals, text: "anish giri").matches(game))
        #expect(TagRule(field: .white, comparison: .beginsWith, text: "anish").matches(game))
        #expect(TagRule(field: .white, comparison: .notEquals, text: "anish giri").matches(game) == false)
        #expect(TagRule(field: .white, comparison: .contains, text: "carlsen").matches(game) == false)
    }
    
    /// The row-level sibling of "zero rules matches nothing": a blank
    /// string rule is inert, never select-all.
    @Test func emptyTextMatchesNothing() {
        let game = record()
        
        #expect(TagRule(field: .white, comparison: .contains, text: "").matches(game) == false)
        #expect(TagRule(field: .event, comparison: .contains, text: "   ").matches(game) == false)
    }
    
    @Test func playerFieldMatchesEitherSeat() {
        let game = record(white: "Alice", black: "Bob")
        
        #expect(TagRule(field: .player, comparison: .equals, text: "bob").matches(game))
        #expect(TagRule(field: .player, comparison: .equals, text: "alice").matches(game))
        #expect(TagRule(field: .player, comparison: .equals, text: "carol").matches(game) == false)
    }
    
    /// An unresolved seat is absent, not an empty string that `contains`
    /// could accidentally hit.
    @Test func unresolvedSeatNeverMatches() {
        let game = record(white: nil)
        
        #expect(TagRule(field: .white, comparison: .contains, text: "a").matches(game) == false)
        #expect(TagRule(field: .player, comparison: .contains, text: "bob").matches(game))
    }
    
    @Test func metadataStringFieldsRead() {
        let game = record(event: "Winter Open", site: "Club", name: "Round One Thriller")
        
        #expect(TagRule(field: .event, comparison: .beginsWith, text: "winter").matches(game))
        #expect(TagRule(field: .site, comparison: .equals, text: "club").matches(game))
        #expect(TagRule(field: .name, comparison: .contains, text: "thriller").matches(game))
    }
    
    // MARK: Result
    
    @Test func resultEqualsAndNot() {
        let draw = record(result: .draw)
        
        #expect(TagRule(field: .result, comparison: .equals, gameResult: .draw).matches(draw))
        #expect(TagRule(field: .result, comparison: .notEquals, gameResult: .whiteWins).matches(draw))
        #expect(TagRule(field: .result, comparison: .equals, gameResult: .whiteWins).matches(draw) == false)
    }
    
    // MARK: Numbers
    
    @Test func numberComparisonsAndNilRound() {
        let game = record(round: 3, plyCount: 24)
        
        #expect(TagRule(field: .round, comparison: .equals, number: 3).matches(game))
        #expect(TagRule(field: .moves, comparison: .lessThan, number: 50).matches(game))
        #expect(TagRule(field: .moves, comparison: .greaterThan, number: 50).matches(game) == false)
        
        let unrounded = record(round: nil)
        #expect(TagRule(field: .round, comparison: .equals, number: 3).matches(unrounded) == false)
        #expect(TagRule(field: .round, comparison: .lessThan, number: 99).matches(unrounded) == false)
    }
    
    // MARK: Dates
    
    /// Date rules answer "when was this played" — the `importedAt`
    /// fallback orders folds, it does not answer that, so undated games
    /// never match.
    @Test func dateBeforeAfterAndUndated() {
        let pivot = Date(timeIntervalSince1970: 5_000)
        let earlier = record(date: Date(timeIntervalSince1970: 1_000))
        
        #expect(TagRule(field: .date, comparison: .before, date: pivot).matches(earlier))
        #expect(TagRule(field: .date, comparison: .after, date: pivot).matches(earlier) == false)
        #expect(TagRule(field: .date, comparison: .before, date: pivot).matches(record(date: nil)) == false)
    }
    
    // MARK: Booleans
    
    @Test func booleanFieldsReadTheirFlags() {
        let mate = record(endedInMate: true, hasAnalysis: true, isTimed: false)
        
        #expect(TagRule(field: .checkmate, comparison: .isTrue).matches(mate))
        #expect(TagRule(field: .analyzed, comparison: .isTrue).matches(mate))
        #expect(TagRule(field: .timed, comparison: .isFalse).matches(mate))
        #expect(TagRule(field: .timed, comparison: .isTrue).matches(mate) == false)
    }
    
    // MARK: Combinator
    
    @Test func evaluateAnyAllAndZeroRules() {
        let game = record(result: .whiteWins, endedInMate: true)
        let mate = TagRule(field: .checkmate, comparison: .isTrue)
        let draw = TagRule(field: .result, comparison: .equals, gameResult: .draw)
        
        #expect(TagRule.evaluate([mate, draw], matchAll: false, against: game))
        #expect(TagRule.evaluate([mate, draw], matchAll: true, against: game) == false)
        #expect(TagRule.evaluate([mate], matchAll: true, against: game))
        #expect(TagRule.evaluate([], matchAll: false, against: game) == false)
        #expect(TagRule.evaluate([], matchAll: true, against: game) == false)
    }
    
    /// Every field's default comparison is one its kind admits — the
    /// editor's field-switch reset depends on this being total.
    @Test func everyFieldOwnsItsComparisons() {
        for field in TagRule.Field.allCases {
            #expect(!field.comparisons.isEmpty)
        }
    }
}
