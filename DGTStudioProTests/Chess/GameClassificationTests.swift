import Testing
@testable import DGTStudioPro

/// The D34′ composition — what only lives here: the two halves are wired together and fail
/// independently.
@Suite("Game Classification")
struct GameClassificationTests {

    private static let openings = ECOClassifier([
        (["e4", "e5"], ECOOpening(code: "C20", name: "King's Pawn Game")),
        (["e4", "c6"], ECOOpening(code: "B10", name: "Caro-Kann Defense")),
        (["f3"], ECOOpening(code: "A00", name: "Barnes Opening")),
    ])

    private static func classify(_ moves: [String]) -> GameClassification {
        GameClassification.classify(moves: moves, using: openings)
    }

    // MARK: Both Halves Together

    /// The Réti trap — 6.Nd6# is mate only because `Qe2` pins the e-pawn, so
    /// this is a real game reaching a real smothered mate, not a constructed
    /// position. Every neighbour of e8 (d7, e7, f7, d8, f8) holds a black
    /// piece and the checker is a knight.
    @Test("A real game gets its opening and its mate motif in one pass")
    func smotheredMateGameClassifiesBothHalves() {
        let result = Self.classify([
            "e4", "c6", "d4", "d5", "Nc3", "dxe4",
            "Nxe4", "Nd7", "Qe2", "Ngf6", "Nd6#",
        ])
        #expect(result.opening?.family == "Caro-Kann Defense")
        #expect(result.specialCheckmate == .smothered)
    }

    // MARK: The Mate Half

    @Test("An ordinary mate classifies as no pattern")
    func foolsMateIsNotAPattern() {
        // 1. f3 e5 2. g4 Qh4# — the queen checks along the diagonal, so it is
        // neither smothered nor a back-rank mate.
        let result = Self.classify(["f3", "e5", "g4", "Qh4#"])
        #expect(result.opening?.family == "Barnes Opening")
        #expect(result.specialCheckmate == nil)
    }

    @Test("A game that never claims mate is never replayed")
    func unfinishedGameHasNoCheckmateType() {
        #expect(Self.classify(["e4", "e5", "Nf3"]).specialCheckmate == nil)
        #expect(Self.classify([]).specialCheckmate == nil)
    }

    /// The gate is `contains("#")`, not `hasSuffix` — NOT "because annotations survive import"
    /// (they don't): `classify` is pure over a `[String]` it does not own, and must tolerate an
    /// annotated ply from any caller.
    @Test("An annotated mating move still claims mate")
    func annotatedMateStillClaimsMate() {
        let result = Self.classify(["f3", "e5", "g4", "Qh4#!"])
        // Reached the replay and was asked: an ordinary mate, hence nil —
        // indistinguishable from "never asked" by value, so the sibling
        // expectation below is what separates them.
        #expect(result.specialCheckmate == nil)

        let smothered = Self.classify([
            "e4", "c6", "d4", "d5", "Nc3", "dxe4",
            "Nxe4", "Nd7", "Qe2", "Ngf6", "Nd6#!",
        ])
        #expect(smothered.specialCheckmate == .smothered)
    }

    // MARK: Independent Failure

    @Test("Unreplayable movetext still gets its opening")
    func brokenMovetextKeepsTheOpening() {
        let result = Self.classify(["e4", "e5", "Zz9#"])
        #expect(result.opening?.code == "C20")
        #expect(result.specialCheckmate == nil)
    }

    @Test("An unnamed opening still gets its mate motif")
    func unnamedOpeningKeepsTheMate() {
        let result = Self.classify([
            "e4", "c6", "d4", "d5", "Nc3", "dxe4",
            "Nxe4", "Nd7", "Qe2", "Ngf6", "Nd6#",
        ])
        let withoutTable = GameClassification.classify(
            moves: [
                "e4", "c6", "d4", "d5", "Nc3", "dxe4",
                "Nxe4", "Nd7", "Qe2", "Ngf6", "Nd6#",
            ],
            using: ECOClassifier([])
        )
        #expect(withoutTable.opening == nil)
        #expect(withoutTable.specialCheckmate == result.specialCheckmate)
    }

    @Test("An empty game classifies as nothing at all")
    func emptyGameIsUnclassified() {
        #expect(Self.classify([]) == GameClassification.unclassified)
    }
}
