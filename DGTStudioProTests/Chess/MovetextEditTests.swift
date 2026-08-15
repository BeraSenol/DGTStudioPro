import Testing
@testable import DGTStudioPro

/// The movetext-edit validator: legality by full replay from the start
/// position, canonicalized output, and the position-forced result rules
/// (checkmate ⇒ mating side wins; a `#` must mate; stalemate ⇒ draw; `*` is
/// never finished). Pure over `GameState` — nonisolated, no fixtures beyond
/// SAN sequences and one FEN for the stalemate/promotion edges.
@Suite("Movetext Edit — Validation")
struct MovetextEditTests {
    
    // MARK: Legality
    
    @Test func legalGameIsAccepted() {
        let result = MovetextEdit.validate(["e4", "e5", "Nf3", "Nc6"], claimedResult: .whiteWins)
        #expect((try? result.get()) != nil)
    }
    
    @Test func firstIllegalPlyIsNamed() {
        // Qh6 is unreachable on move 2 — the first (and only) illegal ply.
        let result = MovetextEdit.validate(["e4", "e5", "Qh6"], claimedResult: .whiteWins)
        #expect(result == .failure(.illegalMove(index: 2, san: "Qh6", reason: .noMatchingMove("Qh6"))))
    }
    
    @Test func illegalOpeningPlyIsIndexZero() {
        let result = MovetextEdit.validate(["e5"], claimedResult: .whiteWins)
        #expect(result == .failure(.illegalMove(index: 0, san: "e5", reason: .noMatchingMove("e5"))))
    }
    
    // MARK: Canonicalization
    
    @Test func castlingCanonicalizesOldForm() throws {
        // `0-0` (older PGN) → `O-O`.
        let accepted = try MovetextEdit.validate(
            ["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5", "0-0"],
            claimedResult: .whiteWins
        ).get()
        #expect(accepted.moves.last == "O-O")
    }
    
    @Test func mateSuffixIsAppendedEvenWhenOmitted() throws {
        // Fool's mate typed without the `#` — storage must still carry it
        // (GameRecord.endedInMate depends on the trailing `#`).
        let accepted = try MovetextEdit.validate(
            ["f3", "e5", "g4", "Qh4"],
            claimedResult: .blackWins
        ).get()
        #expect(accepted.moves.last == "Qh4#")
    }
    
    @Test func promotionFormsCanonicalizeToEquals() throws {
        // a7 pawn; a8=Q gives check, so canonical is `a8=Q+`. All three read
        // forms collapse to it.
        let state = try GameState(FEN(parsing: "4k3/P7/8/8/8/8/8/4K3 w - - 0 1"))
        for input in ["a8=Q", "a8Q", "a8(Q)"] {
            let accepted = try MovetextEdit.validate([input], claimedResult: .whiteWins, from: state).get()
            #expect(accepted.moves == ["a8=Q+"], "\(input) did not canonicalize")
        }
    }
    
    // MARK: Result Consistency
    
    @Test func checkmateForcesMatingSideResult() {
        let drawClaim = MovetextEdit.validate(["f3", "e5", "g4", "Qh4#"], claimedResult: .draw)
        #expect(drawClaim == .failure(.checkmateResultMismatch(expected: .blackWins, claimed: .draw)))
        
        let loserWinsClaim = MovetextEdit.validate(["f3", "e5", "g4", "Qh4#"], claimedResult: .whiteWins)
        #expect(loserWinsClaim == .failure(.checkmateResultMismatch(expected: .blackWins, claimed: .whiteWins)))
    }
    
    @Test func checkmateWithMatingResultIsAccepted() throws {
        let accepted = try MovetextEdit.validate(["f3", "e5", "g4", "Qh4#"], claimedResult: .blackWins).get()
        #expect(accepted.moves.last == "Qh4#")
    }
    
    @Test func trailingHashOnNonMateIsRejected() {
        // Qh5 is neither check nor mate; the `#` is a lie the parser would swallow.
        let result = MovetextEdit.validate(["e4", "e5", "Qh5#"], claimedResult: .whiteWins)
        #expect(result == .failure(.claimsCheckmateButPositionIsNot(san: "Qh5#")))
    }
    
    @Test func stalemateForcesDraw() throws {
        // Qf2, Kg6 vs Kh8; Qf7 stalemates Black.
        let state = try GameState(FEN(parsing: "7k/8/6K1/8/8/8/5Q2/8 w - - 0 1"))
        
        let winClaim = MovetextEdit.validate(["Qf7"], claimedResult: .whiteWins, from: state)
        #expect(winClaim == .failure(.stalemateRequiresDraw(claimed: .whiteWins)))
        
        #expect((try? MovetextEdit.validate(["Qf7"], claimedResult: .draw, from: state).get()) != nil)
    }
    
    @Test func ongoingResultIsRejected() {
        let result = MovetextEdit.validate(["e4", "e5"], claimedResult: .ongoing)
        #expect(result == .failure(.resultRequiresDecision))
    }
    
    @Test func nonTerminalDecisiveResultIsAccepted() {
        // Resignation from a non-terminal position — the board can't refute it.
        #expect((try? MovetextEdit.validate(["e4", "e5"], claimedResult: .blackWins).get()) != nil)
    }
    
    // MARK: Tokenization

    @Test func tokenizeStripsMoveNumbersAndTrailingResult() throws {
        #expect(try MovetextEdit.tokenize("1. e4 e5 2. Nf3 Nc6 1-0") == ["e4", "e5", "Nf3", "Nc6"])
    }

    @Test func tokenizeHandlesGluedNumbersAndBlackEllipsis() throws {
        #expect(try MovetextEdit.tokenize("1.e4 e5 2.Nf3 2...Nc6") == ["e4", "e5", "Nf3", "Nc6"])
    }

    @Test func tokenizeToleratesWhitespaceAndNewlines() throws {
        #expect(try MovetextEdit.tokenize("  e4\n  e5 \t Nf3  ") == ["e4", "e5", "Nf3"])
    }

    @Test func tokenizeOfEmptyIsEmpty() throws {
        #expect(try MovetextEdit.tokenize("   \n  ") == [])
    }

    // MARK: Splice Refusal (M2 item 3)

    @Test func midTextResultTokenIsRefused() {
        // Two games glued together: without the refusal, the second game's
        // plies replay legally from the first game's final position often
        // enough that the splice validated as one game.
        #expect(throws: MovetextEdit.Rejection.splicedGames(token: "1-0")) {
            try MovetextEdit.tokenize("1. e4 e5 1-0 1. d4 d5")
        }
    }

    @Test func midTextAsteriskIsRefused() {
        #expect(throws: MovetextEdit.Rejection.splicedGames(token: "*")) {
            try MovetextEdit.tokenize("e4 e5 * e4")
        }
    }

    @Test func doubledTrailingResultIsRefusedAsSplice() {
        // The first `1-0` has a token after it (the second), so it reads as
        // mid-text — refusal, not silent double-drop.
        #expect(throws: MovetextEdit.Rejection.splicedGames(token: "1-0")) {
            try MovetextEdit.tokenize("e4 e5 1-0 1-0")
        }
    }

    @Test func loneResultTokenTokenizesEmpty() throws {
        // A result with no moves is a trailing result — dropped, not a splice.
        #expect(try MovetextEdit.tokenize("1/2-1/2") == [])
    }
}
