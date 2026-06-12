//
//  EvaluationTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/06/2026.
//

import Testing
import Foundation
@testable import DGTStudioPro

/// Coverage for `Evaluation` — the white-perspective engine score used
/// throughout analysis and storage. Four contracts are pinned: the
/// `whiteWinProbability` sigmoid (the curve `EvaluationGraphView` draws), the
/// `flipped` sign convention (how the UCI parser normalizes side-to-move output
/// to white-relative), the PGN `[%eval ...]` parse/render pair (the on-disk
/// interchange format), and `Codable`.
///
/// `Evaluation` is `Sendable`; its synthesized `==` is nonisolated, so — like
/// `PGNParserEvalTests`, which already compares it — this suite is not
/// `@MainActor`. Floating-point comparisons use an explicit epsilon; the
/// decimal-rounding cases deliberately avoid exact `.5` boundaries so the
/// expected centipawn value is unambiguous under binary floating point.
@Suite("Evaluation")
struct EvaluationTests {
    
    /// Tolerance for sigmoid probability comparisons.
    private let epsilon = 1e-9
    
    // MARK: Constants
    
    @Test func drawnIsZeroCentipawns() {
        #expect(Evaluation.drawn == .centipawns(0))
    }
    
    // MARK: White Win Probability
    
    /// A dead-equal position is exactly 0.5 — the sigmoid's fixed point.
    @Test func probabilityIsOneHalfAtZero() {
        #expect(Evaluation.centipawns(0).whiteWinProbability == 0.5)
    }
    
    /// The sigmoid is antisymmetric about 0: `p(cp) + p(-cp) == 1`, and an
    /// advantage for white reads above 0.5 (and grows with the advantage).
    @Test(arguments: [50, 150, 400, 1000])
    func probabilityIsSymmetricAndMonotonic(_ cp: Int) {
        let up   = Evaluation.centipawns(cp).whiteWinProbability
        let down = Evaluation.centipawns(-cp).whiteWinProbability
        
        #expect(abs(up + down - 1.0) < epsilon)
        #expect(up > 0.5)
        #expect(down < 0.5)
        #expect(up > Evaluation.centipawns(cp - 1).whiteWinProbability)
    }
    
    /// Mate scores clamp to the extremes; `mate(0)` is treated as 0.5 to avoid
    /// sign-of-zero ambiguity.
    @Test func mateProbabilityClampsToExtremes() {
        #expect(Evaluation.mate(3).whiteWinProbability == 1.0)
        #expect(Evaluation.mate(1).whiteWinProbability == 1.0)
        #expect(Evaluation.mate(-3).whiteWinProbability == 0.0)
        #expect(Evaluation.mate(-1).whiteWinProbability == 0.0)
        #expect(Evaluation.mate(0).whiteWinProbability == 0.5)
    }
    
    // MARK: Flipped
    
    @Test func flippedNegatesBothCases() {
        #expect(Evaluation.centipawns(150).flipped == .centipawns(-150))
        #expect(Evaluation.centipawns(-30).flipped == .centipawns(30))
        #expect(Evaluation.mate(3).flipped == .mate(-3))
        #expect(Evaluation.mate(-7).flipped == .mate(7))
    }
    
    /// Flipping twice is the identity, and a draw is its own mirror.
    @Test(arguments: [Evaluation.centipawns(0), .centipawns(123), .centipawns(-456), .mate(2), .mate(-9)])
    func doubleFlipIsIdentity(_ eval: Evaluation) {
        #expect(eval.flipped.flipped == eval)
        #expect(Evaluation.drawn.flipped == .drawn)
    }
    
    // MARK: Parsing — Tag Content
    
    @Test func parsesDecimalPawnContent() {
        #expect(Evaluation(parsingEvalTagContent: "0.23") == .centipawns(23))
        #expect(Evaluation(parsingEvalTagContent: "-1.50") == .centipawns(-150))
        #expect(Evaluation(parsingEvalTagContent: "0.00") == .centipawns(0))
        // A leading '+' is tolerated (some exporters emit it).
        #expect(Evaluation(parsingEvalTagContent: "+0.50") == .centipawns(50))
        // Surrounding whitespace is trimmed.
        #expect(Evaluation(parsingEvalTagContent: "  0.23 ") == .centipawns(23))
    }
    
    @Test func parsesMateContent() {
        #expect(Evaluation(parsingEvalTagContent: "#3") == .mate(3))
        #expect(Evaluation(parsingEvalTagContent: "#-3") == .mate(-3))
        #expect(Evaluation(parsingEvalTagContent: "#0") == .mate(0))
    }
    
    /// Decimal pawns round to the nearest centipawn. Both pins sit clear of the
    /// .5 boundary so the expectation is exact under binary floating point.
    @Test func roundsDecimalContentToNearestCentipawn() {
        #expect(Evaluation(parsingEvalTagContent: "1.234") == .centipawns(123))
        #expect(Evaluation(parsingEvalTagContent: "1.236") == .centipawns(124))
    }
    
    @Test func rejectsMalformedContent() {
        #expect(Evaluation(parsingEvalTagContent: "") == nil)
        #expect(Evaluation(parsingEvalTagContent: "   ") == nil)
        #expect(Evaluation(parsingEvalTagContent: "#") == nil)      // '#' with no number
        #expect(Evaluation(parsingEvalTagContent: "abc") == nil)
        #expect(Evaluation(parsingEvalTagContent: "1.2.3") == nil)
    }
    
    // MARK: Parsing — Full Tag
    
    @Test func parsesFullEvalTag() {
        #expect(Evaluation(parsingEvalTag: "[%eval 0.23]") == .centipawns(23))
        #expect(Evaluation(parsingEvalTag: "[%eval -1.50]") == .centipawns(-150))
        #expect(Evaluation(parsingEvalTag: "[%eval #3]") == .mate(3))
    }
    
    /// The full-tag parser is strict on the wrapping syntax: the keyword, the
    /// single separating space, and both brackets are all required.
    @Test func rejectsMalformedFullTag() {
        #expect(Evaluation(parsingEvalTag: "[%eval0.23]") == nil)   // missing space
        #expect(Evaluation(parsingEvalTag: "[%foo 0.23]") == nil)   // wrong keyword
        #expect(Evaluation(parsingEvalTag: "%eval 0.23")  == nil)   // missing leading bracket
        #expect(Evaluation(parsingEvalTag: "[%eval 0.23")  == nil)  // missing closing bracket
        #expect(Evaluation(parsingEvalTag: "[%eval ]")     == nil)  // empty value
    }
    
    // MARK: Rendering
    
    @Test func rendersTagContent() {
        #expect(Evaluation.centipawns(23).evalTagContent == "0.23")
        #expect(Evaluation.centipawns(-150).evalTagContent == "-1.50")
        #expect(Evaluation.centipawns(5).evalTagContent == "0.05")
        #expect(Evaluation.centipawns(0).evalTagContent == "0.00")
        #expect(Evaluation.mate(3).evalTagContent == "#3")
        #expect(Evaluation.mate(-3).evalTagContent == "#-3")
    }
    
    @Test func rendersFullTag() {
        #expect(Evaluation.centipawns(23).evalTag == "[%eval 0.23]")
        #expect(Evaluation.mate(-3).evalTag == "[%eval #-3]")
    }
    
    // MARK: Round-Trips
    
    /// Every representable value survives render → parse, for both the content
    /// form and the full-tag form.
    @Test(arguments: [
        Evaluation.centipawns(0), .centipawns(23), .centipawns(-150),
        .centipawns(5), .centipawns(1234),
        .mate(1), .mate(-1), .mate(7), .mate(-12),
    ])
    func tagFormatRoundTrips(_ eval: Evaluation) {
        #expect(Evaluation(parsingEvalTagContent: eval.evalTagContent) == eval)
        #expect(Evaluation(parsingEvalTag: eval.evalTag) == eval)
    }
    
    /// `Codable` survives a JSON encode/decode round-trip.
    @Test(arguments: [
        Evaluation.centipawns(0), .centipawns(250), .centipawns(-75),
        .mate(4), .mate(-2),
    ])
    func codableRoundTrips(_ eval: Evaluation) throws {
        let data = try JSONEncoder().encode(eval)
        let decoded = try JSONDecoder().decode(Evaluation.self, from: data)
        #expect(decoded == eval)
    }
}
