import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// The model half (`@MainActor` — realized `@Model`s): rules survive the
/// store round-trip (the Codable-array-on-a-model storage is the one
/// thing the pure suite can't witness), and the reborn defaults match
/// what their enum ancestors matched.
///
/// Split from the former `SmartTagTests.swift`; the pure rule engine lives
/// nonisolated in `TagRuleTests.swift`. Isolation is the seam — matching
/// a suite's isolation to its subject is why these two can't share a file.
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
    
    /// Each default, semantically. The first three must match what their
    /// enum ancestors matched (the old suite's contract, carried forward);
    /// "Smothered Mates" has no ancestor and is pinned on its own terms — a
    /// seeded tag whose rule was never exercised is a rule nobody has checked.
    ///
    /// **The clause "and this one is the only surface `SpecialCheckmate` has"
    /// is struck** (7 Aug 2026). True at M4; false since 5 Aug, when the
    /// Library's Checkmate Type column and Get Info both began rendering the
    /// motif — the fourth species of stale claim, a sentence that was correct
    /// when written and decayed when something adjacent shipped. What survives
    /// is the narrower true version: this is the only place the seeded tag's
    /// *rule* is exercised.
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
        
        let smothered = GameRecord(
            white: nil, black: nil, result: .whiteWins, endedInMate: true,
            date: nil, importedAt: .now, contentHash: "s",
            specialCheckmate: .smothered
        )
        let backRank = GameRecord(
            white: nil, black: nil, result: .whiteWins, endedInMate: true,
            date: nil, importedAt: .now, contentHash: "b",
            specialCheckmate: .backRank
        )

        #expect(tags["Checkmate"]?.matches(mate) == true)
        #expect(tags["Checkmate"]?.matches(timed) == false)
        #expect(tags["Timed"]?.matches(timed) == true)
        #expect(tags["First Round"]?.matches(firstRound) == true)
        #expect(tags["First Round"]?.matches(timed) == false)
        #expect(tags["Smothered Mates"]?.matches(smothered) == true)
        #expect(tags["Smothered Mates"]?.matches(backRank) == false)
        // An ordinary mate carries no motif, so it isn't a smothered one —
        // and the Checkmate tag still catches it, which is the division of
        // labour between the two seeds.
        #expect(tags["Smothered Mates"]?.matches(mate) == false)
        #expect(tags["Checkmate"]?.matches(smothered) == true)
    }
    
    /// A deliberate change-detector. The seed fires **once ever** per install,
    /// so a casual edit here silently changes what a fresh install gets and
    /// nothing else would notice. Growing this list is a decision; having to
    /// come back and edit this test is the decision being noticed. (M4 appended
    /// "Smothered Mates" — appended, so the existing positions are undisturbed.)
    @Test func defaultNamesAndColorsAreStable() {
        let tags = SmartTag.defaultTags()
        #expect(tags.map(\.name) == ["Checkmate", "Timed", "First Round", "Smothered Mates"])
        #expect(tags.map(\.colorName) == [.red, .orange, .blue, .purple])
    }
}
