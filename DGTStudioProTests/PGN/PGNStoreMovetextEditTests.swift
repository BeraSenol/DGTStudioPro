//
//  PGNStoreMovetextEditTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 21/07/2026.
//

import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// The store side of the D18′ movetext edit: an accepted edit canonicalizes
/// the moves, invalidates the parallel evaluation array, and refreshes the
/// content hash in one transaction; a rejected edit leaves the model
/// untouched; a no-op edit (canonicalizes to the same game) preserves the
/// evaluations. `@MainActor`, in-memory container — the store-suite shape.
@MainActor
@Suite("PGN Store — Movetext Edit")
struct PGNStoreMovetextEditTests {

    private static func makeStore() throws -> (PGNStore, ModelContext) {
        let container = try ModelContainer(
            for: PGN.self, Player.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        return (PGNStore(modelContext: context), context)
    }

    private static func sample(result: GameResult = .whiteWins) -> String {
        """
        [Event "Test"]
        [Site "Test"]
        [Date "2026.05.15"]
        [Round "1"]
        [White "Alice"]
        [Black "Bob"]
        [Result "\(result.rawValue)"]
        
        1. e4 e5 \(result.rawValue)
        """
    }

    @Test func acceptedEditCanonicalizesInvalidatesEvalsAndRehashes() throws {
        let (store, _) = try Self.makeStore()
        let game = try store.importPGN(text: Self.sample())
        game.evaluations = [.centipawns(20), .centipawns(-15)]   // parallel to e4 e5
        let hashBefore = game.contentHash

        let outcome = try store.applyMovetextEdit(to: game, proposed: ["d4", "d5", "c4"])

        #expect(outcome == .success(["d4", "d5", "c4"]))
        #expect(game.moves == ["d4", "d5", "c4"])
        #expect(game.evaluations.isEmpty)
        #expect(game.contentHash != hashBefore)
    }

    @Test func rejectedEditLeavesModelUntouched() throws {
        let (store, _) = try Self.makeStore()
        let game = try store.importPGN(text: Self.sample())
        game.evaluations = [.centipawns(20), .centipawns(-15)]
        let hashBefore = game.contentHash

        let outcome = try store.applyMovetextEdit(to: game, proposed: ["e4", "e5", "Qh6"])

        #expect(outcome == .failure(.illegalMove(index: 2, san: "Qh6", reason: .noMatchingMove("Qh6"))))
        #expect(game.moves == ["e4", "e5"])
        #expect(game.evaluations.count == 2)
        #expect(game.contentHash == hashBefore)
    }

    /// The canonical-`#` rationale end to end: a mate typed without the suffix
    /// stores with it, so `endedInMate` stays true.
    @Test func mateEditStoresCanonicalMoves() throws {
        let (store, _) = try Self.makeStore()
        let game = try store.importPGN(text: Self.sample(result: .blackWins))

        let outcome = try store.applyMovetextEdit(to: game, proposed: ["f3", "e5", "g4", "Qh4"])

        #expect(outcome == .success(["f3", "e5", "g4", "Qh4#"]))
        #expect(game.moves.last == "Qh4#")
        #expect(game.gameRecord.endedInMate)
    }

    /// A no-op edit (already canonical, identical game) doesn't wipe evals.
    @Test func noOpEditPreservesEvaluations() throws {
        let (store, _) = try Self.makeStore()
        let game = try store.importPGN(text: Self.sample())
        game.evaluations = [.centipawns(20), .centipawns(-15)]

        let outcome = try store.applyMovetextEdit(to: game, proposed: ["e4", "e5"])

        #expect(outcome == .success(["e4", "e5"]))
        #expect(game.evaluations.count == 2)
    }
}
