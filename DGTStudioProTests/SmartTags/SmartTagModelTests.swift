//
//  SmartTagModelTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 23/07/2026.
//

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
