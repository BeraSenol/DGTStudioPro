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
        isTimed: Bool = false,
        opening: ECOOpening? = nil,
        specialCheckmate: SpecialCheckmate? = nil
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
            isTimed: isTimed,
            opening: opening,
            specialCheckmate: specialCheckmate
        )
    }

    // MARK: Classification Fields (M4, D34′)

    private static let winawer = ECOOpening(
        code: "C15", name: "French Defense: Winawer Variation"
    )

    @Test("The opening field matches over the full name, not the family alone")
    func openingMatchesFullName() {
        let game = record(opening: Self.winawer)

        #expect(TagRule(field: .opening, comparison: .contains, text: "winawer").matches(game))
        #expect(TagRule(field: .opening, comparison: .beginsWith, text: "French Defense").matches(game))
        #expect(
            TagRule(field: .opening, comparison: .equals,
                    text: "French Defense: Winawer Variation").matches(game)
        )
        // The documented consequence: the family alone is not the full name.
        #expect(
            TagRule(field: .opening, comparison: .equals, text: "French Defense")
                .matches(game) == false
        )
    }

    @Test("An unclassified game never matches an opening rule, negation included")
    func unclassifiedOpeningNeverMatches() {
        let game = record(opening: nil)

        #expect(TagRule(field: .opening, comparison: .contains, text: "French").matches(game) == false)
        // The D30′ guard: "opening is not X" needs a known opening to be true.
        #expect(TagRule(field: .opening, comparison: .notEquals, text: "French").matches(game) == false)
    }

    @Test("A mate-pattern rule matches its motif and rejects the other")
    func matePatternMatches() {
        let smothered = record(specialCheckmate: .smothered)
        let backRank = record(specialCheckmate: .backRank)

        #expect(
            TagRule(field: .matePattern, comparison: .equals, specialCheckmate: .smothered)
                .matches(smothered)
        )
        #expect(
            TagRule(field: .matePattern, comparison: .equals, specialCheckmate: .smothered)
                .matches(backRank) == false
        )
        #expect(
            TagRule(field: .matePattern, comparison: .notEquals, specialCheckmate: .smothered)
                .matches(backRank)
        )
    }

    /// The arm's whole argument: an ordinary mate and an unclassified game
    /// are the same nil, so neither may satisfy a negated motif rule.
    @Test("A game with no motif never matches a mate-pattern rule, negation included")
    func absentMatePatternNeverMatches() {
        let game = record(endedInMate: true, specialCheckmate: nil)

        #expect(
            TagRule(field: .matePattern, comparison: .equals, specialCheckmate: .smothered)
                .matches(game) == false
        )
        #expect(
            TagRule(field: .matePattern, comparison: .notEquals, specialCheckmate: .smothered)
                .matches(game) == false
        )
    }

    // MARK: Codable Migration

    /// The pin for the defaulting decoder. A rule saved before M4 has no
    /// `specialCheckmate` key; synthesized decoding would throw on it and
    /// take every saved smart tag down with it, because the whole array is
    /// one blob on the model.
    @Test("A rule saved before the mate slot existed still decodes")
    func preM4RuleDecodesWithDefaults() throws {
        let legacy = """
        {
          "id": "5B4E1E9C-1F0B-4C3E-9E4E-7A2B9C0D1E2F",
          "field": "white",
          "comparison": "contains",
          "text": "Bera",
          "number": 1,
          "date": 700000000,
          "gameResult": "1-0"
        }
        """
        let rule = try JSONDecoder().decode(TagRule.self, from: Data(legacy.utf8))

        #expect(rule.field == .white)
        #expect(rule.text == "Bera")
        #expect(rule.specialCheckmate == .smothered)  // the default, not a throw
    }

    @Test("A rule round-trips through the encoder it will actually be stored by")
    func ruleRoundTripsThroughCoding() throws {
        let original = TagRule(
            field: .matePattern, comparison: .notEquals, specialCheckmate: .backRank
        )
        let decoded = try JSONDecoder().decode(
            TagRule.self, from: JSONEncoder().encode(original)
        )
        #expect(decoded == original)
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
    
    // MARK: Negation Quantifier

    /// The 27 July quantifier fix, finally pinned (M1 item 18): "Player
    /// is not X" means *neither* seat is X. Under `contains` it read
    /// "some seat isn't X" — true of every game X ever played against
    /// anyone, the exact inverse of the rule's plain meaning.
    @Test func playerNotEqualsFlipsTheQuantifier() {
        let notBera = TagRule(field: .player, comparison: .notEquals, text: "bera")

        // X vs Y: one seat IS Bera → excluded.
        #expect(notBera.matches(record(white: "Bera", black: "Reinaud")) == false)
        #expect(notBera.matches(record(white: "Christophe", black: "Bera")) == false)
        // Third parties only → matched.
        #expect(notBera.matches(record(white: "Christophe", black: "Reinaud")))
        // No resolved seat: nothing can prove or disprove a player rule —
        // unknowns never match, negation included.
        #expect(notBera.matches(record(white: nil, black: nil)) == false)
    }

    /// D30′ — the decision the M1 documentation test
    /// (`singleSubjectNotEqualsCurrentlyMatchesUnknowns`) existed to trip
    /// on: unknowns never match, **negation included**, for the single
    /// subjects too. An unresolved seat and a `""`/`"?"` event/site fail
    /// `.notEquals` — "White is not X" means the white player is known and
    /// isn't X. The half-resolved `.player` reading is unchanged by
    /// decision: the one resolved seat satisfies the negation, the missing
    /// seat abstains.
    @Test func singleSubjectNotEqualsNeverMatchesUnknowns() {
        let notCarlsen = TagRule(field: .white, comparison: .notEquals, text: "carlsen")
        #expect(notCarlsen.matches(record(white: nil)) == false)
        #expect(notCarlsen.matches(record(white: "Anish Giri")))

        let notCasual = TagRule(field: .event, comparison: .notEquals, text: "casual game")
        #expect(notCasual.matches(record(event: "?")) == false)
        #expect(notCasual.matches(record(event: "")) == false)
        #expect(notCasual.matches(record(event: "Winter Open")))

        // Positive comparisons deliberately keep matching an explicit "?".
        #expect(TagRule(field: .event, comparison: .equals, text: "?").matches(record(event: "?")))

        let notBera = TagRule(field: .player, comparison: .notEquals, text: "bera")
        #expect(notBera.matches(record(white: "Christophe", black: nil)))
    }

    /// D30′'s other half: both sides of a string comparison ride
    /// `PlayerName.folded` + `lowercased()`, so whitespace runs and
    /// newlines in *either* the tag or the rule text stop mattering.
    @Test func stringComparisonsFoldWhitespaceRunsBothSides() {
        let doubleSpaced = record(white: "Anish  Giri", event: "Winter\nOpen")

        #expect(TagRule(field: .white, comparison: .equals, text: "anish giri").matches(doubleSpaced))
        #expect(TagRule(field: .white, comparison: .equals, text: " Anish\tGiri ").matches(doubleSpaced))
        #expect(TagRule(field: .event, comparison: .contains, text: "winter open").matches(doubleSpaced))
        #expect(TagRule(field: .player, comparison: .equals, text: "anish  giri").matches(doubleSpaced))
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
