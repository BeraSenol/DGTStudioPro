import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// The M4 store door (D34′): `classify` is the single write site for all four
/// classification columns, `backfillClassifications` heals pre-M4 rows
/// without an engine, `applyMovetextEdit` **re-derives** rather than clears,
/// and none of it touches the content hash.
///
/// Runs against the real bundled table on purpose — the pure walk is already
/// pinned on fixtures in `ECOClassifierTests`, so what is left to prove here
/// is that the store, the table and the model agree end to end.
///
/// `@MainActor`: fronts `PGNStore` and realized `@Model`s, same as the other
/// store suites.
@MainActor
@Suite("PGN Store — Classification")
struct PGNStoreClassificationTests {

    // MARK: Helpers

    private static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: PGN.self, Player.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private static func pgnText(
        moves: String,
        result: String = "1-0",
        round: Int = 1
    ) -> String {
        """
        [Event "Test"]
        [Site "Test"]
        [Date "2026.05.15"]
        [Round "\(round)"]
        [White "Carlsen, Magnus"]
        [Black "Nepo"]
        [Result "\(result)"]

        \(moves) \(result)
        """
    }

    /// The Réti trap: a real game that is both a named opening and a
    /// recognised mate motif, so one fixture exercises both halves.
    private static let smotheredGame =
        "1. e4 c6 2. d4 d5 3. Nc3 dxe4 4. Nxe4 Nd7 5. Qe2 Ngf6 6. Nd6#"

    // MARK: The Write Door

    @Test("classify stamps every column from one lookup")
    func classifyStampsAllColumns() throws {
        let store = PGNStore(modelContext: try Self.makeContext())
        let game = try store.importPGN(text: Self.pgnText(moves: "1. e4 e5 2. Nf3 Nc6 3. Bb5"))

        #expect(store.classify(game) == true)
        #expect(game.ecoCode == "C60")
        #expect(game.ecoFamily == "Ruy Lopez")
        #expect(game.ecoVariation == nil)
        // The whole line is book, and the stamp says so — the analysis skip's input (D74′).
        #expect(game.ecoDepth == 5)
        #expect(game.specialCheckmate == nil)
    }

    @Test("Both halves land together on a game that has both")
    func classifyStampsOpeningAndMate() throws {
        let store = PGNStore(modelContext: try Self.makeContext())
        let game = try store.importPGN(text: Self.pgnText(moves: Self.smotheredGame))

        store.classify(game)
        #expect(game.ecoFamily == "Caro-Kann Defense")
        #expect(game.specialCheckmate == .smothered)
    }

    @Test("classify is idempotent and reports honestly")
    func classifyIsIdempotent() throws {
        let store = PGNStore(modelContext: try Self.makeContext())
        let game = try store.importPGN(text: Self.pgnText(moves: "1. e4 e5 2. Nf3 Nc6 3. Bb5"))

        #expect(store.classify(game) == true)
        #expect(store.classify(game) == false)
        #expect(store.classify(game) == false)
    }

    /// `PGN.opening` requires both a code and a family; this pins the round
    /// trip the three stored columns exist to support.
    @Test("The stored columns rehydrate into the value the surfaces read")
    func storedColumnsRehydrate() throws {
        let store = PGNStore(modelContext: try Self.makeContext())
        let game = try store.importPGN(
            text: Self.pgnText(moves: "1. e4 e6 2. d4 d5 3. Nc3 Bb4")
        )
        store.classify(game)

        let opening = try #require(game.opening)
        #expect(opening.code == "C15")
        #expect(opening.family == "French Defense")
        #expect(opening.variation == "Winawer Variation")
        #expect(opening.fullName == "French Defense: Winawer Variation")
    }

    /// The only row shape that classifies to nothing. The bundled table names
    /// all twenty legal first moves — a4 is the Ware Opening, h4 the Kádas —
    /// so a game with any move at all comes back named, and "unclassified"
    /// in practice means "no moves yet".
    @Test("A game with no moves classifies as nothing rather than as a half-opening")
    func movelessGameStoresNil() throws {
        let store = PGNStore(modelContext: try Self.makeContext())
        let game = try store.importPGN(text: Self.pgnText(moves: "", result: "*"))

        #expect(game.moves.isEmpty)
        #expect(store.classify(game) == false)
        #expect(game.ecoCode == nil)
        #expect(game.ecoFamily == nil)
        #expect(game.opening == nil)
    }

    /// The sibling of the above, and the reason the "every first move is
    /// named" fact is worth pinning rather than just noting: it is what makes
    /// a single Library sweep actually finish the job.
    @Test("Any game with a move classifies to something")
    func everyPlayedGameGetsAName() throws {
        let store = PGNStore(modelContext: try Self.makeContext())
        for (index, opening) in ["1. a4", "1. h4", "1. Na3", "1. g4"].enumerated() {
            let game = try store.importPGN(
                text: Self.pgnText(moves: opening, round: index + 1)
            )
            store.classify(game)
            #expect(game.ecoCode != nil, "\(opening) should be named by the table")
        }
    }

    // MARK: The Backfill

    @Test("The backfill heals a pre-M4 row and its count is honest")
    func backfillHealsAndCountsOnce() throws {
        let store = PGNStore(modelContext: try Self.makeContext())
        let game = try store.importPGN(text: Self.pgnText(moves: "1. e4 e5 2. Nf3 Nc6 3. Bb5"))
        // Import does not classify — the backfill is the door for existing rows.
        #expect(game.ecoCode == nil)

        #expect(try store.backfillClassifications() == 1)
        #expect(game.ecoFamily == "Ruy Lopez")
        // Idempotent: a second sweep finds nothing to do.
        #expect(try store.backfillClassifications() == 0)
    }

    /// The conflation the store doc admits to: a row that legitimately
    /// classifies nil is re-asked every sweep. What must *not* happen is it
    /// being counted as work, which would make the idempotence contract
    /// meaningless and the log line noise.
    @Test("A moveless game is re-asked but never re-counted")
    func movelessGameIsNeverCountedAsWork() throws {
        let store = PGNStore(modelContext: try Self.makeContext())
        _ = try store.importPGN(text: Self.pgnText(moves: "", result: "*"))

        #expect(try store.backfillClassifications() == 0)
        #expect(try store.backfillClassifications() == 0)
    }

    @Test("The backfill skips rows that already carry a code")
    func backfillSkipsClassifiedRows() throws {
        let store = PGNStore(modelContext: try Self.makeContext())
        let ruy = try store.importPGN(
            text: Self.pgnText(moves: "1. e4 e5 2. Nf3 Nc6 3. Bb5", round: 1)
        )
        _ = try store.importPGN(text: Self.pgnText(moves: "1. e4 e6", round: 2))
        store.classify(ruy)

        // Only the French is left to do.
        #expect(try store.backfillClassifications() == 1)
    }

    // MARK: Movetext Edits Re-derive

    /// The corrected behaviour: D18′'s doc promised these fields would
    /// *clear* on a movetext edit. D34′ made classification engine-free, so
    /// they are re-derived inside the same transaction instead.
    @Test("A movetext edit re-classifies rather than clearing")
    func movetextEditReclassifies() throws {
        let store = PGNStore(modelContext: try Self.makeContext())
        let game = try store.importPGN(text: Self.pgnText(moves: "1. e4 e6"))
        store.classify(game)
        #expect(game.ecoFamily == "French Defense")

        let outcome = try store.applyMovetextEdit(
            to: game, proposed: ["e4", "e5", "Nf3", "Nc6", "Bb5"]
        )
        guard case .success = outcome else {
            Issue.record("The edit was rejected: \(outcome)")
            return
        }
        #expect(game.ecoCode == "C60")
        #expect(game.ecoFamily == "Ruy Lopez")
        // Evaluations still clear — recomputing those *does* need the engine.
        #expect(game.evaluations.isEmpty)
    }

    // MARK: Outside The Hash

    /// The `board` precedent (D28′): derived truth must not identify a game,
    /// or a re-classification would silently fork it from its own twin.
    @Test("Classification is outside the content hash")
    func classificationDoesNotChangeTheHash() throws {
        // The context is held locally, not reached for through the store —
        // `PGNStore.modelContext` is private by design.
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)
        let text = Self.pgnText(moves: "1. e4 e5 2. Nf3 Nc6 3. Bb5")
        let game = try store.importPGN(text: text)
        let hashBefore = game.contentHash

        store.classify(game)
        #expect(game.contentHash == hashBefore)

        // And dedupe still recognises the classified row as the same game.
        // Import treats a hash match as an *error*, not a silent merge — the
        // user is telling it to add a game it already has — so the throw is
        // the assertion, and the row count is the corroboration.
        #expect(throws: PGNStore.Error.self) {
            _ = try store.importPGN(text: text)
        }
        #expect(try context.fetch(FetchDescriptor<PGN>()).count == 1)
    }
}
