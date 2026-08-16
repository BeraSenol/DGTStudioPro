import Testing
@testable import DGTStudioPro

@Suite("PGN Parser - [%eval] Comments")
struct PGNParserEvalTests {

    // MARK: Helpers

    /// Wraps a movetext fragment in the minimum tag roster required for
    /// `PGNParser.parse(_:)` to succeed. Lets tests focus on movetext shape
    /// without retyping headers each time.
    private func pgnText(movetext: String) -> String {
        """
        [Event "Test"]
        [Site "Test"]
        [Date "2026.05.15"]
        [Round "1"]
        [White "A"]
        [Black "B"]
        [Result "*"]
        
        \(movetext)
        """
    }

    // MARK: Single-Move Eval Extraction

    @Test func decimalEvalAfterWhiteMove() throws {
        let (moves, evals) = try PGNParser.parseMovesAndEvaluations(
            from: "1. e4 {[%eval 0.23]} e5"
        )
        #expect(moves == ["e4", "e5"])
        #expect(evals == [.centipawns(23), nil])
    }

    @Test func decimalEvalAfterBlackMove() throws {
        let (moves, evals) = try PGNParser.parseMovesAndEvaluations(
            from: "1. e4 e5 {[%eval 0.10]}"
        )
        #expect(moves == ["e4", "e5"])
        #expect(evals == [nil, .centipawns(10)])
    }

    @Test func negativeDecimalEval() throws {
        let (moves, evals) = try PGNParser.parseMovesAndEvaluations(
            from: "1. e4 {[%eval -1.50]}"
        )
        #expect(moves == ["e4"])
        #expect(evals == [.centipawns(-150)])
    }

    @Test func leadingPlusToleratedOnDecimal() throws {
        let (_, evals) = try PGNParser.parseMovesAndEvaluations(
            from: "1. e4 {[%eval +0.50]}"
        )
        #expect(evals == [.centipawns(50)])
    }

    @Test func mateEvalPositive() throws {
        let (_, evals) = try PGNParser.parseMovesAndEvaluations(
            from: "1. e4 {[%eval #3]}"
        )
        #expect(evals == [.mate(3)])
    }

    @Test func mateEvalNegative() throws {
        let (_, evals) = try PGNParser.parseMovesAndEvaluations(
            from: "1. e4 {[%eval #-3]}"
        )
        #expect(evals == [.mate(-3)])
    }

    // MARK: Hostile Payloads

    /// Hostile eval payloads must fail the *annotation*, never the import
    /// (M1 item 17): pre-guard, `Double(_:)` accepted "inf"/"nan"/overflow
    /// literals and the centipawn conversion trapped - one poisoned
    /// comment crashed the whole import instead of shedding itself. The
    /// moves must survive with no evaluation recorded.
    @Test func hostileEvalPayloadsFailTheAnnotationNotTheImport() throws {
        for payload in ["inf", "-inf", "nan", "1e999", "999999999"] {
            let (moves, evals) = try PGNParser.parseMovesAndEvaluations(
                from: "1. e4 {[%eval \(payload)]} e5"
            )
            #expect(moves == ["e4", "e5"], "Moves must survive payload '\(payload)'")
            #expect(evals.allSatisfy { $0 == nil },
                    "Payload '\(payload)' must record no evaluation, got \(evals)")
        }
    }

    // MARK: Sparse Evaluations

    @Test func missingEvalsLeaveNilSlots() throws {
        let (moves, evals) = try PGNParser.parseMovesAndEvaluations(
            from: "1. e4 {[%eval 0.20]} e5 2. Nf3 {[%eval 0.15]} Nc6"
        )
        #expect(moves == ["e4", "e5", "Nf3", "Nc6"])
        #expect(evals == [.centipawns(20), nil, .centipawns(15), nil])
    }

    @Test func gameWithNoEvalCommentsProducesEmptyArray() throws {
        // The parse entry point collapses an all-nil evaluations array to
        // empty - the "no analysis was recorded" sentinel.
        let pgn = try PGNParser.parse(pgnText(movetext: "1. e4 e5 2. Nf3 Nc6 *"))
        #expect(pgn.moves == ["e4", "e5", "Nf3", "Nc6"])
        #expect(pgn.evaluations.isEmpty)
    }

    @Test func gameWithSomeEvalsPadsToMoveCount() throws {
        // When any eval is present, the array carries one slot per ply so
        // ply-indexed access stays in bounds without per-call length checks.
        let pgn = try PGNParser.parse(pgnText(
            movetext: "1. e4 {[%eval 0.20]} e5 2. Nf3 Nc6 *"
        ))
        #expect(pgn.moves.count == 4)
        #expect(pgn.evaluations.count == 4)
        #expect(pgn.evaluations == [.centipawns(20), nil, nil, nil])
    }

    // MARK: Multi-Annotation Comments

    @Test func evalAlongsideClockAnnotation() throws {
        let (_, evals) = try PGNParser.parseMovesAndEvaluations(
            from: "1. e4 {[%eval 0.23] [%clk 0:05:00]}"
        )
        #expect(evals == [.centipawns(23)])
    }

    @Test func clockBeforeEvalStillExtractsEval() throws {
        let (_, evals) = try PGNParser.parseMovesAndEvaluations(
            from: "1. e4 {[%clk 0:05:00] [%eval 0.23]}"
        )
        #expect(evals == [.centipawns(23)])
    }

    @Test func multipleEvalsLastWins() throws {
        let (_, evals) = try PGNParser.parseMovesAndEvaluations(
            from: "1. e4 {[%eval 0.20] [%eval 0.50]}"
        )
        #expect(evals == [.centipawns(50)])
    }

    @Test func evalWithSurroundingProseText() throws {
        let (_, evals) = try PGNParser.parseMovesAndEvaluations(
            from: "1. e4 {a strong opening move [%eval 0.23] best by test}"
        )
        #expect(evals == [.centipawns(23)])
    }

    // MARK: Robustness

    @Test func malformedEvalIsIgnored() throws {
        let (moves, evals) = try PGNParser.parseMovesAndEvaluations(
            from: "1. e4 {[%eval abc]} e5"
        )
        #expect(moves == ["e4", "e5"])
        #expect(evals == [nil, nil])
    }

    @Test func evalBeforeAnyMoveIsDropped() throws {
        let (moves, evals) = try PGNParser.parseMovesAndEvaluations(
            from: "{[%eval 0.10] before any move} 1. e4 e5"
        )
        #expect(moves == ["e4", "e5"])
        #expect(evals == [nil, nil])
    }

    @Test func evalInsideRAVIsDropped() throws {
        // Variations are discarded along with everything in them, including
        // any annotations they happen to contain.
        let (moves, evals) = try PGNParser.parseMovesAndEvaluations(
            from: "1. e4 (1. d4 {[%eval 0.10]} d5) e5"
        )
        #expect(moves == ["e4", "e5"])
        #expect(evals == [nil, nil])
    }

    @Test func evalAfterBracePreservedAcrossRAV() throws {
        // Eval comment on e4, then a variation, then black's reply. The
        // variation must not disturb e4's eval association.
        let (moves, evals) = try PGNParser.parseMovesAndEvaluations(
            from: "1. e4 {[%eval 0.23]} (1. d4 d5) e5"
        )
        #expect(moves == ["e4", "e5"])
        #expect(evals == [.centipawns(23), nil])
    }

    @Test func multipleBraceCommentsOnSameMoveLastEvalWins() throws {
        // A move can carry two separate brace comments; the eval from the
        // second supersedes the first.
        let (_, evals) = try PGNParser.parseMovesAndEvaluations(
            from: "1. e4 {first thought [%eval 0.10]} {[%eval 0.50] revised}"
        )
        #expect(evals == [.centipawns(50)])
    }

    @Test func multipleBraceCommentsFirstHasEvalSecondDoesNot() throws {
        // First comment has an eval, second is a pure prose comment with
        // no eval annotation. The eval from the first must be preserved
        // rather than overwritten with nil.
        let (_, evals) = try PGNParser.parseMovesAndEvaluations(
            from: "1. e4 {[%eval 0.23]} {just a note} e5"
        )
        #expect(evals == [.centipawns(23), nil])
    }

    // MARK: Hash Invariance (via Moves Invariance)

    /// The store's content hash is computed from the parsed `moves` array.
    /// As long as parsing two PGNs that differ only in eval comments
    /// produces identical `moves` arrays, the hash is invariant to
    /// eval content by construction. This test pins that invariant
    /// so a future refactor that accidentally folded comment text into
    /// `moves` would trip immediately.
    @Test func movesIdenticalRegardlessOfEvalComments() throws {
        let bare = try PGNParser.parse(pgnText(
            movetext: "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *"
        ))
        let annotated = try PGNParser.parse(pgnText(
            movetext: """
                1. e4 {[%eval 0.20]} e5 {[%eval 0.10]} \
                2. Nf3 {[%eval 0.25]} Nc6 {[%eval 0.15]} \
                3. Bb5 {[%eval 0.30]} a6 {[%eval 0.20]} *
                """
        ))
        #expect(bare.moves == annotated.moves)
        // And the annotated one really did pick up evals - confirms the
        // test isn't passing because eval scanning silently no-op'd.
        #expect(annotated.evaluations.contains(where: { $0 != nil }))
    }

    @Test func movesIdenticalAcrossClockOnlyVsEvalAndClock() throws {
        // Different annotation mixes (clock-only vs eval+clock) must not
        // perturb the move list - both annotation forms are comment content
        // that gets stripped before move tokenization.
        let clockOnly = try PGNParser.parse(pgnText(
            movetext: "1. e4 {[%clk 0:05:00]} e5 {[%clk 0:05:00]} *"
        ))
        let both = try PGNParser.parse(pgnText(
            movetext: "1. e4 {[%eval 0.20] [%clk 0:05:00]} e5 {[%clk 0:05:00]} *"
        ))
        #expect(clockOnly.moves == both.moves)
    }

    // MARK: PGN Accessor

    @Test func evaluationAtPlyReturnsNilForEmptyArray() throws {
        let pgn = try PGNParser.parse(pgnText(movetext: "1. e4 e5 *"))
        #expect(pgn.evaluations.isEmpty)
        #expect(pgn.evaluation(atPly: 0) == nil)
        #expect(pgn.evaluation(atPly: 1) == nil)
    }

    @Test func evaluationAtPlyReturnsValueForPopulatedArray() throws {
        let pgn = try PGNParser.parse(pgnText(
            movetext: "1. e4 {[%eval 0.20]} e5 {[%eval 0.15]} *"
        ))
        #expect(pgn.evaluation(atPly: 0) == .centipawns(20))
        #expect(pgn.evaluation(atPly: 1) == .centipawns(15))
    }

    @Test func evaluationAtPlyOutOfRangeReturnsNil() throws {
        let pgn = try PGNParser.parse(pgnText(
            movetext: "1. e4 {[%eval 0.20]} *"
        ))
        #expect(pgn.evaluation(atPly: -1) == nil)
        #expect(pgn.evaluation(atPly: 99) == nil)
    }
}
