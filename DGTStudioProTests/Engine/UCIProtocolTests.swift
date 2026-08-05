import Testing
@testable import DGTStudioPro

@Suite("UCI Protocol Parsing")
struct UCIProtocolTests {
    
    // MARK: Empty / Garbage
    
    @Test func emptyLineReturnsNil() {
        #expect(UCIProtocol.parse("") == nil)
        #expect(UCIProtocol.parse("   ") == nil)
        #expect(UCIProtocol.parse("\n") == nil)
    }
    
    /// The distinguishing pin for the `.whitespacesAndNewlines` trim.
    /// `emptyLineReturnsNil`'s `"\n"` case cannot do this job: pre-fix,
    /// the un-trimmed newline fell through the unknown-keyword exit —
    /// the same `nil` as the empty exit, so both spellings passed it.
    /// A *keyword* wearing the newline only parses when the trim
    /// actually removes it.
    @Test func keywordSurvivesTrailingNewlineOrCR() {
        #expect(UCIProtocol.parse("readyok\n") == .readyOK)
        #expect(UCIProtocol.parse("uciok\r\n") == .uciOK)
        #expect(UCIProtocol.parse(" readyok \n") == .readyOK)
    }

    @Test func unknownKeywordReturnsNil() {
        #expect(UCIProtocol.parse("garbage") == nil)
        // `option name X type spin ...` lines are deliberately not recognized
        // — engine option discovery isn't part of the eval-only phase.
        #expect(
            UCIProtocol.parse("option name Threads type spin default 1") == nil
        )
    }
    
    // MARK: Simple Responses
    
    @Test func uciOKParses() {
        #expect(UCIProtocol.parse("uciok") == .uciOK)
    }
    
    @Test func readyOKParses() {
        #expect(UCIProtocol.parse("readyok") == .readyOK)
    }
    
    // MARK: id Line
    
    @Test func idNameParses() {
        #expect(
            UCIProtocol.parse("id name Stockfish 17")
            == .id(key: "name", value: "Stockfish 17")
        )
    }
    
    @Test func idAuthorParses() {
        #expect(
            UCIProtocol.parse("id author the Stockfish developers")
            == .id(key: "author", value: "the Stockfish developers")
        )
    }
    
    // MARK: info Line — Score
    
    @Test func infoCpScoreParses() throws {
        let response = try #require(UCIProtocol.parse("info depth 12 score cp 45"))
        guard case .info(let info) = response else {
            Issue.record("Expected .info, got \(response)")
            return
        }
        #expect(info.depth == 12)
        #expect(info.score == .centipawns(45))
    }
    
    @Test func infoMateScoreParses() throws {
        let response = try #require(UCIProtocol.parse("info depth 8 score mate 3"))
        guard case .info(let info) = response else {
            Issue.record("Expected .info, got \(response)")
            return
        }
        #expect(info.score == .mate(3))
    }
    
    @Test func infoNegativeCpScoreParses() throws {
        let response = try #require(UCIProtocol.parse("info depth 10 score cp -150"))
        guard case .info(let info) = response else {
            Issue.record("Expected .info, got \(response)")
            return
        }
        #expect(info.score == .centipawns(-150))
    }
    
    @Test func infoNegativeMateScoreParses() throws {
        let response = try #require(UCIProtocol.parse("info depth 8 score mate -2"))
        guard case .info(let info) = response else {
            Issue.record("Expected .info, got \(response)")
            return
        }
        #expect(info.score == .mate(-2))
    }
    
    // MARK: info Line — PV
    
    @Test func infoPvCollectsRemainingTokens() throws {
        let response = try #require(UCIProtocol.parse(
            "info depth 12 score cp 30 pv e2e4 e7e5 g1f3 b8c6"
        ))
        guard case .info(let info) = response else {
            Issue.record("Expected .info, got \(response)")
            return
        }
        #expect(info.pv == ["e2e4", "e7e5", "g1f3", "b8c6"])
    }
    
    @Test func infoPvConsumesEntireRestOfLine() throws {
        // PV terminates the line; tokens after it that look like keywords
        // (e.g. "nodes") become part of the PV. This is per UCI spec and
        // is why `pv` must be parsed last in the keyword scan.
        let response = try #require(UCIProtocol.parse("info pv e2e4 nodes 100"))
        guard case .info(let info) = response else {
            Issue.record("Expected .info, got \(response)")
            return
        }
        #expect(info.pv == ["e2e4", "nodes", "100"])
    }
    
    @Test func infoPvWithPromotion() throws {
        // Promotion moves are 5 chars: from-square + to-square + piece letter.
        let response = try #require(UCIProtocol.parse(
            "info depth 6 score cp 800 pv e7e8q a1a2"
        ))
        guard case .info(let info) = response else {
            Issue.record("Expected .info, got \(response)")
            return
        }
        #expect(info.pv == ["e7e8q", "a1a2"])
    }
    
    // MARK: info Line — Multiple Fields
    
    @Test func infoFullProductionLineParses() throws {
        let line = "info depth 20 seldepth 27 multipv 1 score cp 32 "
        + "nodes 1234567 nps 850000 tbhits 0 time 1450 "
        + "pv e2e4 c7c5 g1f3"
        let response = try #require(UCIProtocol.parse(line))
        guard case .info(let info) = response else {
            Issue.record("Expected .info, got \(response)")
            return
        }
        #expect(info.depth == 20)
        #expect(info.selectiveDepth == 27)
        #expect(info.score == .centipawns(32))
        #expect(info.nodes == 1234567)
        #expect(info.nodesPerSecond == 850000)
        #expect(info.timeMs == 1450)
        #expect(info.pv == ["e2e4", "c7c5", "g1f3"])
    }
    
    @Test func infoLowerboundUpperboundDoesNotConsumePayload() throws {
        // Aspiration-window qualifiers appear during search but carry no
        // payload. The parser must skip them without eating the next
        // keyword — a bug here would cause the following field to be lost.
        let response = try #require(UCIProtocol.parse(
            "info depth 5 score cp 100 lowerbound nodes 500"
        ))
        guard case .info(let info) = response else {
            Issue.record("Expected .info, got \(response)")
            return
        }
        #expect(info.score == .centipawns(100))
        #expect(info.nodes == 500)
    }
    
    @Test func infoStringConsumesEntireRestOfLine() throws {
        // `string` carries an engine debug message; everything after it
        // is the message and must not be reinterpreted as keyword/value
        // pairs.
        let response = try #require(UCIProtocol.parse(
            "info depth 5 score cp 10 string this depth nodes 100 is debug"
        ))
        guard case .info(let info) = response else {
            Issue.record("Expected .info, got \(response)")
            return
        }
        #expect(info.depth == 5)
        #expect(info.score == .centipawns(10))
        // `nodes 100` inside the debug string must not populate info.nodes.
        #expect(info.nodes == nil)
    }
    
    // MARK: bestmove Line
    
    @Test func bestmoveWithoutPonderParses() {
        #expect(
            UCIProtocol.parse("bestmove e2e4")
            == .bestMove(UCIBestMove(move: "e2e4", ponder: nil))
        )
    }
    
    @Test func bestmoveWithPonderParses() {
        #expect(
            UCIProtocol.parse("bestmove e2e4 ponder c7c5")
            == .bestMove(UCIBestMove(move: "e2e4", ponder: "c7c5"))
        )
    }
    
    @Test func bestmoveWithPromotionParses() {
        #expect(
            UCIProtocol.parse("bestmove e7e8q")
            == .bestMove(UCIBestMove(move: "e7e8q", ponder: nil))
        )
    }
    
    @Test func bestmoveMissingMoveReturnsNil() {
        #expect(UCIProtocol.parse("bestmove") == nil)
    }
    
    // MARK: UCIScore → Evaluation Conversion
    
    @Test func scoreFromWhiteIsNotFlipped() {
        let cp = UCIScore.centipawns(50).toEvaluation(sideToMove: .white)
        let mate = UCIScore.mate(3).toEvaluation(sideToMove: .white)
        #expect(cp == .centipawns(50))
        #expect(mate == .mate(3))
    }
    
    @Test func scoreFromBlackIsFlipped() {
        // If it's black's turn and the engine says "side-to-move is +50",
        // white-relative storage form is -50 (black is +50 means white is -50).
        let cp = UCIScore.centipawns(50).toEvaluation(sideToMove: .black)
        let mate = UCIScore.mate(3).toEvaluation(sideToMove: .black)
        #expect(cp == .centipawns(-50))
        #expect(mate == .mate(-3))
    }
    
    @Test func scoreConversionIsInvolutionUnderColorSwap() {
        // Converting with white then black sides applied successively
        // gives back the original sign.
        let original = UCIScore.centipawns(75)
        let flipped = original.toEvaluation(sideToMove: .black)
        #expect(flipped.flipped == .centipawns(75))
    }

    // MARK: Known-and-ignored vs unrecognized (D63′)

    /// `parse` returning nil means two different things, and until 5 Aug 2026
    /// the engine treated both as **errors** — so Stockfish's twenty-five
    /// option advertisements arrived on the error channel at every start,
    /// under a comment saying that channel existed to spot real engine drift.
    ///
    /// These pin the split rather than the logging, because the split is the
    /// part that can be wrong: a caller can only classify correctly if this
    /// answers correctly.
    @Test(arguments: [
        "option name Hash type spin default 16 min 1 max 33554432",
        "option name Threads type spin default 1 min 1 max 1024",
        "copyprotection checking",
        "registration ok"
    ])
    func knownButUnusedKeywordsAreDeliberatelyIgnored(_ line: String) {
        #expect(UCIProtocol.parse(line) == nil, "still unparsed — that has not changed")
        #expect(UCIProtocol.isDeliberatelyIgnored(line), "but it is not news")
    }

    /// Genuine drift is **not** absorbed by the new arm, which is the failure
    /// mode worth guarding: a classifier that returns true too easily would
    /// silence the very thing the error channel was cleared out to reveal.
    ///
    /// The banner is the interesting case. It is emitted by every real
    /// Stockfish before the handshake and it is deliberately *not* on the
    /// ignore list — it matches no keyword, so it reaches the error arm once
    /// per start, which is the documented floor at the call site. Absorbing it
    /// would need a rule ("anything before uciok") broad enough to swallow a
    /// real protocol change made in the same window.
    @Test(arguments: [
        "Stockfish 18 by the Stockfish developers (see AUTHORS file)",
        "some future keyword we have never seen",
        "optional"           // a known keyword's prefix is not that keyword
    ])
    func unrecognizedLinesAreNotAbsorbed(_ line: String) {
        #expect(UCIProtocol.isDeliberatelyIgnored(line) == false)
    }

    /// Leading whitespace must not hide a known keyword, because the caller
    /// asks this *before* it asks whether the line is blank — so a padded
    /// `option` line that classified as unrecognized would land back on the
    /// error channel this change exists to clear.
    @Test func leadingWhitespaceStillFindsTheKeyword() {
        #expect(UCIProtocol.isDeliberatelyIgnored("   option name Hash type spin default 16"))
    }

    /// An empty line is neither — it takes the caller's own empty exit, and
    /// asking this of it must not trap.
    @Test(arguments: ["", "   ", "\n"])
    func blankLinesClassifyAsNothing(_ line: String) {
        #expect(UCIProtocol.isDeliberatelyIgnored(line) == false)
    }

    /// The lines the app actually acts on are untouched by the new arm — the
    /// check that this change subtracted nothing.
    @Test(arguments: ["uciok", "readyok", "id name Stockfish 18", "bestmove e2e4"])
    func handledResponsesAreNeverClassifiedAsIgnorable(_ line: String) {
        #expect(UCIProtocol.parse(line) != nil)
        #expect(UCIProtocol.isDeliberatelyIgnored(line) == false)
    }
}
