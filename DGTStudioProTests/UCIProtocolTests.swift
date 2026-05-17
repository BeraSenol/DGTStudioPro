//
//  UCIProtocolTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 14/05/2026.
//

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
}
