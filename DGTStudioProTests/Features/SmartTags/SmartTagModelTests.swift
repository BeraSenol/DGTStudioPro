import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// The model half: rules survive the store round-trip (the one thing the pure suite can't
/// witness), and the reborn defaults match their enum ancestors.
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
    
    /// Each default semantically; "Smothered Mates" pinned on its own terms — this is the only
    /// place the seeded tag's *rule* is exercised.
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
    
    /// A deliberate change-detector: the seed fires once ever, so a casual edit silently changes
    /// what a fresh install gets.
    @Test func defaultNamesAndColorsAreStable() {
        let tags = SmartTag.defaultTags()
        #expect(tags.map(\.name) == ["Checkmate", "Timed", "First Round", "Smothered Mates"])
        #expect(tags.map(\.colorName) == [.red, .orange, .blue, .purple])
    }
}
