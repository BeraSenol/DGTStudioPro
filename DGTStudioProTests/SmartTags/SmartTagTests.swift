//
//  SmartTagTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// The rule engine (M-prs.5), nonisolated — `TagRule` evaluates pure
/// `GameRecord`s, so the fixture-context idiom the old enum suite needed
/// died with the enum. Pins every kind's comparisons, the recorded edge
/// rules (empty text matches nothing, unknowns never match, either-seat
/// player, case folding), and the any/all/zero combinator.
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

/// The model half (`@MainActor` — realized `@Model`s): rules survive the
/// store round-trip (the Codable-array-on-a-model storage is the one
/// thing the pure suite can't witness), and the reborn defaults match
/// what their enum ancestors matched.
@MainActor
@Suite("Smart Tag — Model")
struct SmartTagModelTests {
    
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: SmartTag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }
    
    @Test func rulesSurviveTheStoreRoundTrip() throws {
        let context = try makeContext()
        let tag = SmartTag(
            name: "Miniatures",
            colorName: .purple,
            matchAll: true,
            rules: [
                TagRule(field: .moves, comparison: .lessThan, number: 50),
                TagRule(field: .result, comparison: .notEquals, gameResult: .draw),
            ]
        )
        context.insert(tag)
        try context.save()
        
        let fetched = try #require(try context.fetch(FetchDescriptor<SmartTag>()).first)
        #expect(fetched.rules.count == 2)
        #expect(fetched.rules[0].field == .moves)
        #expect(fetched.rules[0].number == 50)
        #expect(fetched.rules[1].gameResult == .draw)
        #expect(fetched.matchAll)
    }
    
    /// The three defaults, semantically: each must match what its enum
    /// ancestor matched (the old suite's contract, carried forward).
    @Test func defaultTagsMatchTheirAncestors() {
        let tags = Dictionary(
            uniqueKeysWithValues: SmartTag.defaultTags().map { ($0.name, $0) }
        )
        let mate = GameRecord(
            white: nil, black: nil, result: .blackWins, endedInMate: true,
            date: nil, importedAt: .now, contentHash: "m"
        )
        let timed = GameRecord(
            white: nil, black: nil, result: .draw, endedInMate: false,
            date: nil, importedAt: .now, contentHash: "t", isTimed: true
        )
        let firstRound = GameRecord(
            white: nil, black: nil, result: .whiteWins, endedInMate: false,
            date: nil, importedAt: .now, contentHash: "r", round: 1
        )
        
        #expect(tags["Checkmate"]?.matches(mate) == true)
        #expect(tags["Checkmate"]?.matches(timed) == false)
        #expect(tags["Timed"]?.matches(timed) == true)
        #expect(tags["First Round"]?.matches(firstRound) == true)
        #expect(tags["First Round"]?.matches(timed) == false)
    }
    
    @Test func defaultNamesAndColorsAreStable() {
        let tags = SmartTag.defaultTags()
        #expect(tags.map(\.name) == ["Checkmate", "Timed", "First Round"])
        #expect(tags.map(\.colorName) == [.red, .orange, .blue])
    }
}
