import Testing
@testable import DGTStudioPro

/// The parser's *rejection* contract — the mirror of
/// `FENParsingRejectionTests` for the PGN door.
///
/// Born from the M9 coverage audit (July 2026): the three specialized
/// parser suites (dates, line endings, `[%eval]`) exercised the happy
/// scanner thoroughly, but all three `PGNParser.Error` throw paths and the
/// small tag helpers (`parseTag`, `parseResult`, `parseRound`,
/// `parseTimeControl`) had zero direct witnesses — every red region the
/// coverage pass showed in the *live* pipeline traced back here. (The same
/// audit retired the superseded `parseMoves`/`strip` pipeline outright, so
/// this suite witnesses `parseMovesAndEvaluations` — the only movetext
/// scanner — plus the tag layer.)
///
/// Nonisolated: `PGNParser` is a pure static enum.
@Suite("PGN Parser — Rejection and Tag Edges")
struct PGNParserRejectionTests {
    
    // MARK: Helpers
    
    /// The full seven-tag roster around a movetext fragment — same shape as
    /// the eval suite's helper, duplicated deliberately (suites stay
    /// self-contained; the fixture is seven lines).
    private func pgnText(movetext: String) -> String {
        """
        [Event "Test"]
        [Site "Test"]
        [Date "2026.07.19"]
        [Round "1"]
        [White "A"]
        [Black "B"]
        [Result "*"]
        
        \(movetext)
        """
    }
    
    // MARK: Required Tags
    
    /// Bare movetext has no blank-line separator, so the whole input reads
    /// as the (empty) tag section — the error must name all seven.
    @Test func movetextOnlyInputIsMissingAllSevenTags() {
        #expect(throws: PGNParser.Error.missingRequiredTags(PGNParser.requiredTags)) {
            _ = try PGNParser.parse("1. e4 e5 *")
        }
    }
    
    @Test func droppingOneTagNamesExactlyThatTag() {
        let text = """
        [Event "Test"]
        [Site "Test"]
        [Date "2026.07.19"]
        [Round "1"]
        [White "A"]
        [Black "B"]
        
        1. e4 *
        """
        #expect(throws: PGNParser.Error.missingRequiredTags(["Result"])) {
            _ = try PGNParser.parse(text)
        }
    }
    
    // MARK: Unbalanced Movetext
    
    @Test func unclosedBraceCommentThrows() {
        #expect(throws: PGNParser.Error.unbalancedBraces) {
            _ = try PGNParser.parse(pgnText(movetext: "1. e4 {left open *"))
        }
    }
    
    @Test func unclosedVariationParenthesisThrows() {
        #expect(throws: PGNParser.Error.unbalancedParentheses) {
            _ = try PGNParser.parse(pgnText(movetext: "1. e4 (1... e5 *"))
        }
    }
    
    // MARK: parseTag Edges
    
    @Test func tagLinesNeedBracketsAndAKeyValueSpace() {
        #expect(PGNParser.parseTag("Event \"Test\"") == nil)   // no brackets
        #expect(PGNParser.parseTag("[Event]") == nil)          // no space
        #expect(PGNParser.parseTag("") == nil)
    }
    
    @Test func quotesStripAndUnquotedValuesSurvive() throws {
        let quoted = try #require(PGNParser.parseTag("[Event \"Spring Open\"]"))
        #expect(quoted.key == "Event")
        #expect(quoted.value == "Spring Open")
        
        // Real-world PGNs occasionally drop the quotes; the value passes
        // through whole rather than being rejected.
        let bare = try #require(PGNParser.parseTag("[Site Reykjavik]"))
        #expect(bare.value == "Reykjavik")
    }
    
    // MARK: Small Tag Helpers
    
    @Test func unknownResultFallsBackToOngoing() {
        #expect(PGNParser.parseResult("2-0") == .ongoing)
        #expect(PGNParser.parseResult(nil) == .ongoing)
    }
    
    /// D31′ — integer-rounds-only is the *contract*, not an accident of
    /// `Int.init`: `"3.1"` → nil is the decided, documented handling of
    /// PGN's multipart rounds (see `parseRound`'s doc for the reasoning).
    @Test func roundParsesIntegersOnly() {
        #expect(PGNParser.parseRound("3") == 3)
        #expect(PGNParser.parseRound("?") == nil)
        #expect(PGNParser.parseRound("3.1") == nil)
        #expect(PGNParser.parseRound(nil) == nil)
    }
    
    @Test func timeControlNormalizesUnknownFormsToNil() {
        #expect(PGNParser.parseTimeControl("-") == nil)
        #expect(PGNParser.parseTimeControl("") == nil)
        #expect(PGNParser.parseTimeControl(nil) == nil)
        #expect(PGNParser.parseTimeControl("300+2") == "300+2")
    }
    
    // MARK: Token Hygiene Through the Live Scanner
    
    @Test func suffixAnnotationsStripButCheckAndMateSurvive() throws {
        let pgn = try PGNParser.parse(pgnText(movetext: "1. e4! f5?? 2. Qh5+ g6!? *"))
        #expect(pgn.moves == ["e4", "f5", "Qh5+", "g6"])
    }
    
    @Test func nagTokensVanishBetweenMoves() throws {
        let pgn = try PGNParser.parse(pgnText(movetext: "1. e4 $1 e5 $14 *"))
        #expect(pgn.moves == ["e4", "e5"])
    }
    
    @Test func semicolonCommentRunsToEndOfLine() throws {
        let pgn = try PGNParser.parse(pgnText(movetext: "1. e4 ; king's pawn, best by test\n1... e5 *"))
        #expect(pgn.moves == ["e4", "e5"])
    }
    
    @Test func resultTokensNeverBecomeMoves() throws {
        let decided = try PGNParser.parse(pgnText(movetext: "1. e4 e5 1/2-1/2"))
        #expect(decided.moves == ["e4", "e5"])
        
        let ongoing = try PGNParser.parse(pgnText(movetext: "1. e4 e5 *"))
        #expect(ongoing.moves == ["e4", "e5"])
    }
}
