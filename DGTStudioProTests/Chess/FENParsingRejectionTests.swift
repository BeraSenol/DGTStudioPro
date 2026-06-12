//
//  FENParsingRejectionTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/06/2026.
//

import Testing
@testable import DGTStudioPro

/// Rejection coverage for `FEN(parsing:)` — the untrusted-input boundary.
/// `FENParsingTests` covers the happy path (round-trips, reference positions);
/// this suite is its complement, pinning that every malformed shape throws the
/// **specific** typed `FENParseError` the parser documents, rather than parsing
/// to something silently wrong.
///
/// `FENParseError` is `Equatable`, so each case is asserted by value via
/// `#expect(throws:)`. The parser is intentionally legality-agnostic — it
/// validates *shape*, not chess validity — which the one positive case at the
/// end exercises (an all-empty four-field EPD string parses fine and defaults
/// the clocks). Not `@MainActor`: `FEN` and `FENParseError` are plain value
/// types.
@Suite("FEN Parsing — Rejection")
struct FENParsingRejectionTests {
    
    // MARK: Field Count
    
    /// Only 4- or 6-field strings are accepted; the error reports the actual
    /// field count.
    @Test func rejectsWrongFieldCount() {
        #expect(throws: FENParseError.wrongFieldCount(0)) {
            try FEN(parsing: "")
        }
        #expect(throws: FENParseError.wrongFieldCount(3)) {
            try FEN(parsing: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq")
        }
        #expect(throws: FENParseError.wrongFieldCount(5)) {
            try FEN(parsing: "8/8/8/8/8/8/8/8 w - - 0")
        }
        #expect(throws: FENParseError.wrongFieldCount(7)) {
            try FEN(parsing: "8/8/8/8/8/8/8/8 w - - 0 1 extra")
        }
    }
    
    // MARK: Placement
    
    /// The placement field must be 8 slash-separated ranks, each totalling
    /// exactly 8 files, using only valid piece letters and 1–8 empty-run digits.
    @Test func rejectsMalformedPlacement() {
        // Seven ranks instead of eight.
        #expect(throws: FENParseError.malformedPlacement("8/8/8/8/8/8/8")) {
            try FEN(parsing: "8/8/8/8/8/8/8 w - -")
        }
        // A rank overflowing past 8 files.
        #expect(throws: FENParseError.malformedPlacement("ppppppppp/8/8/8/8/8/8/8")) {
            try FEN(parsing: "ppppppppp/8/8/8/8/8/8/8 w - -")
        }
        // A rank short of 8 files.
        #expect(throws: FENParseError.malformedPlacement("7/8/8/8/8/8/8/8")) {
            try FEN(parsing: "7/8/8/8/8/8/8/8 w - -")
        }
        // An out-of-range empty-run digit.
        #expect(throws: FENParseError.malformedPlacement("9/8/8/8/8/8/8/8")) {
            try FEN(parsing: "9/8/8/8/8/8/8/8 w - -")
        }
        // An unknown piece character.
        #expect(throws: FENParseError.malformedPlacement("X7/8/8/8/8/8/8/8")) {
            try FEN(parsing: "X7/8/8/8/8/8/8/8 w - -")
        }
    }
    
    // MARK: Active Color
    
    @Test func rejectsMalformedActiveColor() {
        #expect(throws: FENParseError.malformedActiveColor("W")) {
            try FEN(parsing: "8/8/8/8/8/8/8/8 W - -")
        }
        #expect(throws: FENParseError.malformedActiveColor("x")) {
            try FEN(parsing: "8/8/8/8/8/8/8/8 x - -")
        }
    }
    
    // MARK: Castling
    
    /// Castling accepts `-` or a non-repeating subset of `KQkq`; foreign
    /// characters and duplicates are both rejected, and the error carries the
    /// whole field.
    @Test func rejectsMalformedCastling() {
        #expect(throws: FENParseError.malformedCastling("KQX")) {
            try FEN(parsing: "8/8/8/8/8/8/8/8 w KQX -")
        }
        #expect(throws: FENParseError.malformedCastling("KK")) {
            try FEN(parsing: "8/8/8/8/8/8/8/8 w KK -")
        }
        #expect(throws: FENParseError.malformedCastling("KQkqK")) {
            try FEN(parsing: "8/8/8/8/8/8/8/8 w KQkqK -")
        }
    }
    
    // MARK: En Passant
    
    /// The EP field accepts `-` or a parseable algebraic square; anything else
    /// throws. (Whether the square sits on a plausible EP rank is a
    /// position-validity concern, not a parse one — deliberately not checked.)
    @Test func rejectsMalformedEnPassant() {
        #expect(throws: FENParseError.malformedEnPassant("e9")) {
            try FEN(parsing: "8/8/8/8/8/8/8/8 w - e9")
        }
        #expect(throws: FENParseError.malformedEnPassant("z3")) {
            try FEN(parsing: "8/8/8/8/8/8/8/8 w - z3")
        }
        #expect(throws: FENParseError.malformedEnPassant("e")) {
            try FEN(parsing: "8/8/8/8/8/8/8/8 w - e")
        }
        #expect(throws: FENParseError.malformedEnPassant("e44")) {
            try FEN(parsing: "8/8/8/8/8/8/8/8 w - e44")
        }
    }
    
    // MARK: Move Counters (six-field only)
    
    /// In the six-field form the halfmove clock must be a non-negative integer
    /// and the fullmove number a positive one; both failures surface as
    /// `malformedInteger` carrying the offending field.
    @Test func rejectsMalformedMoveCounters() {
        #expect(throws: FENParseError.malformedInteger("x")) {
            try FEN(parsing: "8/8/8/8/8/8/8/8 w - - x 1")
        }
        #expect(throws: FENParseError.malformedInteger("-1")) {
            try FEN(parsing: "8/8/8/8/8/8/8/8 w - - -1 1")
        }
        #expect(throws: FENParseError.malformedInteger("0")) {
            try FEN(parsing: "8/8/8/8/8/8/8/8 w - - 0 0")   // fullmove must be ≥ 1
        }
        #expect(throws: FENParseError.malformedInteger("y")) {
            try FEN(parsing: "8/8/8/8/8/8/8/8 w - - 0 y")
        }
    }
    
    // MARK: Positive Control — Four-Field EPD
    
    /// The complement to the rejection cases: a well-formed four-field EPD
    /// string parses without throwing, defaulting the halfmove clock to 0 and
    /// the fullmove number to 1. The all-empty board also confirms the parser
    /// validates shape only, not chess legality (no king-presence check).
    @Test func acceptsWellFormedFourFieldEPD() throws {
        let parsed = try FEN(parsing: "8/8/8/8/8/8/8/8 w - -")
        let expected = FEN(
            position: .empty,
            activeColor: .white,
            castlingRights: .none,
            enPassantTarget: nil,
            halfmoveClock: 0,
            fullmoveNumber: 1
        )
        #expect(parsed == expected)
    }
}
