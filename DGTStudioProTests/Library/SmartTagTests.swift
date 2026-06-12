//
//  SmartTagTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/06/2026.
//

import Testing
import SwiftData
@testable import DGTStudioPro

/// Coverage for `SmartTag` — the Library's smart-filter chips. The stable
/// metadata (display name, SF Symbol, id, case order) is pinned directly, and
/// the real value is `matches(_:)`, the predicate that decides whether a game
/// carries each tag: a checkmate (last move ends in `#`), a timed game
/// (`timeControl` present), or a first-round game (`round == 1`). A regression
/// in any of these silently breaks Library filtering.
///
/// `@MainActor`: `matches` reads stored properties off `PGN`, an SwiftData
/// `@Model`, so each test builds realized models in a fresh in-memory
/// `ModelContext` (the `PGNStoreTests` idiom) and evaluates the predicate while
/// that context is still alive. This is the one fixture-dependent suite here;
/// the metadata tests themselves are pure. Color is intentionally not asserted
/// (SwiftUI `Color` equality is not a meaningful contract to pin).
@MainActor
@Suite("Smart Tag")
struct SmartTagTests {
    
    /// A fresh in-memory context. Held by the caller for the duration of a
    /// test so models built in it stay readable.
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: PGN.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }
    
    /// Inserts a PGN into `context` and saves, returning the realized model.
    private func insert(
        into context: ModelContext,
        moves: [String] = ["e4", "e5"],
        timeControl: String? = nil,
        round: Int? = nil
    ) throws -> PGN {
        let pgn = PGN(round: round, moves: moves, timeControl: timeControl)
        context.insert(pgn)
        try context.save()
        return pgn
    }
    
    // MARK: Metadata
    
    @Test func displayNamesAndImagesAreStable() {
        #expect(SmartTag.checkmate.displayName == "Checkmate")
        #expect(SmartTag.timeControlled.displayName == "Timed")
        #expect(SmartTag.firstRound.displayName == "First Round")
        
        #expect(SmartTag.checkmate.systemImage == "crown")
        #expect(SmartTag.timeControlled.systemImage == "clock")
        #expect(SmartTag.firstRound.systemImage == "1.circle")
    }
    
    @Test func idMatchesRawValueAndAllCasesAreOrdered() {
        #expect(SmartTag.checkmate.id == "checkmate")
        #expect(SmartTag.allCases == [.checkmate, .timeControlled, .firstRound])
    }
    
    // MARK: matches — checkmate
    
    /// The checkmate tag keys purely off the last move's `#` suffix (it does
    /// not re-derive legality), matching how PGN encodes mate.
    @Test func checkmateMatchesWhenLastMoveEndsInHash() throws {
        let context = try makeContext()
        
        let mate = try insert(into: context, moves: ["e4", "e5", "Qh5", "Nc6", "Bc4", "Nf6", "Qxf7#"])
        #expect(SmartTag.checkmate.matches(mate) == true)
        
        let ongoing = try insert(into: context, moves: ["e4", "e5", "Nf3"])
        #expect(SmartTag.checkmate.matches(ongoing) == false)
    }
    
    // MARK: matches — timeControlled
    
    @Test func timeControlledMatchesWhenTimeControlPresent() throws {
        let context = try makeContext()
        
        let timed = try insert(into: context, timeControl: "300+3")
        #expect(SmartTag.timeControlled.matches(timed) == true)
        
        let untimed = try insert(into: context, timeControl: nil)
        #expect(SmartTag.timeControlled.matches(untimed) == false)
    }
    
    // MARK: matches — firstRound
    
    @Test func firstRoundMatchesOnlyForRoundOne() throws {
        let context = try makeContext()
        
        let first = try insert(into: context, round: 1)
        #expect(SmartTag.firstRound.matches(first) == true)
        
        let second = try insert(into: context, round: 2)
        #expect(SmartTag.firstRound.matches(second) == false)
        
        let unrounded = try insert(into: context, round: nil)
        #expect(SmartTag.firstRound.matches(unrounded) == false)
    }
    
    // MARK: matches — independence
    
    /// The tags are independent predicates: a timed, non-mate, round-5 game
    /// matches only `timeControlled`.
    @Test func tagsAreIndependentPredicates() throws {
        let context = try makeContext()
        let pgn = try insert(into: context, moves: ["e4", "e5", "Nf3"], timeControl: "60+0", round: 5)
        
        #expect(SmartTag.checkmate.matches(pgn) == false)
        #expect(SmartTag.timeControlled.matches(pgn) == true)
        #expect(SmartTag.firstRound.matches(pgn) == false)
    }
}
