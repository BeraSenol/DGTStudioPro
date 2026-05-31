//
//  FENParsingTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 14/05/2026.
//

import Testing
@testable import DGTStudioPro

@Suite("FEN String Parsing")
struct FENParsingTests {
    
    // MARK: Starting Position
    
    @Test func startingStringRoundTrips() throws {
        let fen = try FEN(parsing: FEN.startingString)
        #expect(fen == .starting)
        #expect(fen.string == FEN.startingString)
    }
    
    @Test func startingPlacementBackRank() throws {
        let fen = try FEN(parsing: FEN.startingString)
        #expect(fen.position[Squares.a1] == .whiteRook)
        #expect(fen.position[Squares.b1] == .whiteKnight)
        #expect(fen.position[Squares.c1] == .whiteBishop)
        #expect(fen.position[Squares.d1] == .whiteQueen)
        #expect(fen.position[Squares.e1] == .whiteKing)
        #expect(fen.position[Squares.h8] == .blackRook)
        #expect(fen.position[Squares.d8] == .blackQueen)
        #expect(fen.position[Squares.e8] == .blackKing)
    }
    
    @Test func startingPlacementPawns() throws {
        let fen = try FEN(parsing: FEN.startingString)
        for file in 0..<8 {
            #expect(fen.position[Squares.a2 + file] == .whitePawn)
            #expect(fen.position[Squares.a7 + file] == .blackPawn)
        }
    }
    
    // MARK: Real Reference Positions
    
    @Test func kiwipeteParsesCorrectly() throws {
        let fen = try FEN(parsing:
                            "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -"
        )
        
        #expect(fen.activeColor == .white)
        #expect(fen.castlingRights == .all)
        #expect(fen.enPassantTarget == nil)
        #expect(fen.halfmoveClock == 0)
        #expect(fen.fullmoveNumber == 1)
        #expect(fen.position[Squares.e1] == .whiteKing)
        #expect(fen.position[Squares.e8] == .blackKing)
        #expect(fen.position[Squares.d5] == .whitePawn)
        #expect(fen.position[Squares.e5] == .whiteKnight)
        #expect(fen.position[Squares.f3] == .whiteQueen)
    }
    
    @Test func sparseEndgameParsesCorrectly() throws {
        // Perft position 3 — minimal-material endgame.
        let fen = try FEN(parsing: "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -")
        #expect(fen.position[Squares.a5] == .whiteKing)
        #expect(fen.position[Squares.h4] == .blackKing)
        #expect(fen.position[Squares.b5] == .whitePawn)
        #expect(fen.position[Squares.b4] == .whiteRook)
        #expect(fen.position[Squares.h5] == .blackRook)
        #expect(fen.castlingRights == .none)
    }
    
    // MARK: Four-Field Variant
    
    @Test func fourFieldFenAppliesDefaults() throws {
        let fen = try FEN(parsing: "8/8/8/8/8/8/8/4K3 w - -")
        #expect(fen.halfmoveClock == 0)
        #expect(fen.fullmoveNumber == 1)
    }
    
    @Test func sixFieldFenReadsClocks() throws {
        let fen = try FEN(parsing: "8/8/8/8/8/8/8/4K3 w - - 12 45")
        #expect(fen.halfmoveClock == 12)
        #expect(fen.fullmoveNumber == 45)
    }
    
    // MARK: Active Color
    
    @Test func blackToMoveParses() throws {
        let fen = try FEN(parsing:
                            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1"
        )
        #expect(fen.activeColor == .black)
    }
    
    @Test func unknownActiveColorThrows() {
        #expect(throws: FENParseError.malformedActiveColor("x")) {
            _ = try FEN(parsing: "8/8/8/8/8/8/8/8 x - -")
        }
    }
    
    @Test func uppercaseActiveColorThrows() {
        // FEN is case-sensitive; uppercase is not the spec.
        #expect(throws: FENParseError.malformedActiveColor("W")) {
            _ = try FEN(parsing: "8/8/8/8/8/8/8/8 W - -")
        }
    }
    
    // MARK: Castling Rights
    
    @Test func castlingDashIsNone() throws {
        let fen = try FEN(parsing: "8/8/8/8/8/8/8/8 w - -")
        #expect(fen.castlingRights == .none)
    }
    
    @Test func castlingAllPresent() throws {
        let fen = try FEN(parsing: "8/8/8/8/8/8/8/8 w KQkq -")
        #expect(fen.castlingRights == .all)
    }
    
    @Test func castlingPartialPresent() throws {
        let fen = try FEN(parsing: "8/8/8/8/8/8/8/8 w Kq -")
        #expect(fen.castlingRights.has(.white, .kingSide))
        #expect(!fen.castlingRights.has(.white, .queenSide))
        #expect(!fen.castlingRights.has(.black, .kingSide))
        #expect(fen.castlingRights.has(.black, .queenSide))
    }
    
    @Test func castlingNonCanonicalOrderAccepted() throws {
        // Per FEN spec the canonical order is KQkq, but castling rights are
        // a set, not a sequence — order does not change semantic meaning.
        let fen = try FEN(parsing: "8/8/8/8/8/8/8/8 w qkQK -")
        #expect(fen.castlingRights == .all)
    }
    
    @Test func castlingUnknownCharThrows() {
        #expect(throws: FENParseError.malformedCastling("KQXq")) {
            _ = try FEN(parsing: "8/8/8/8/8/8/8/8 w KQXq -")
        }
    }
    
    @Test func castlingDuplicateThrows() {
        #expect(throws: FENParseError.malformedCastling("KK")) {
            _ = try FEN(parsing: "8/8/8/8/8/8/8/8 w KK -")
        }
    }
    
    // MARK: En Passant
    
    @Test func enPassantDashIsNil() throws {
        let fen = try FEN(parsing: "8/8/8/8/8/8/8/8 w - -")
        #expect(fen.enPassantTarget == nil)
    }
    
    @Test func enPassantSquareParses() throws {
        let fen = try FEN(parsing: "8/8/8/8/8/8/8/8 w - e3")
        #expect(fen.enPassantTarget == Squares.e3)
    }
    
    @Test func enPassantBlackTargetParses() throws {
        let fen = try FEN(parsing: "8/8/8/8/8/8/8/8 b - c6")
        #expect(fen.enPassantTarget == Squares.c6)
    }
    
    @Test func enPassantMalformedThrows() {
        #expect(throws: FENParseError.malformedEnPassant("xx")) {
            _ = try FEN(parsing: "8/8/8/8/8/8/8/8 w - xx")
        }
    }
    
    @Test func enPassantTooLongThrows() {
        #expect(throws: FENParseError.malformedEnPassant("e33")) {
            _ = try FEN(parsing: "8/8/8/8/8/8/8/8 w - e33")
        }
    }
    
    // MARK: Placement Errors
    
    @Test func wrongRankCountThrows() {
        // Only 7 ranks — FEN requires 8.
        #expect(throws: FENParseError.malformedPlacement("8/8/8/8/8/8/8")) {
            _ = try FEN(parsing: "8/8/8/8/8/8/8 w - -")
        }
    }
    
    @Test func rankWithTooManyFilesThrows() {
        // Rank totals to 9 (8 + 1).
        #expect(throws: FENParseError.malformedPlacement("8/8/8/8/8/8/8/8K")) {
            _ = try FEN(parsing: "8/8/8/8/8/8/8/8K w - -")
        }
    }
    
    @Test func rankWithTooFewFilesThrows() {
        // Rank only adds up to 7.
        #expect(throws: FENParseError.malformedPlacement("8/8/8/8/8/8/8/7")) {
            _ = try FEN(parsing: "8/8/8/8/8/8/8/7 w - -")
        }
    }
    
    @Test func unknownPieceCharacterThrows() {
        #expect(throws: FENParseError.malformedPlacement("8/8/8/8/8/8/8/4Z3")) {
            _ = try FEN(parsing: "8/8/8/8/8/8/8/4Z3 w - -")
        }
    }
    
    @Test func zeroDigitIsRejected() {
        // Digit 0 is not a valid file run length per FEN spec.
        #expect(throws: FENParseError.malformedPlacement("8/8/8/8/8/8/8/8K0")) {
            _ = try FEN(parsing: "8/8/8/8/8/8/8/8K0 w - -")
        }
    }
    
    // MARK: Field Count
    
    @Test func emptyStringHasZeroFields() {
        #expect(throws: FENParseError.wrongFieldCount(0)) {
            _ = try FEN(parsing: "")
        }
    }
    
    @Test func tooFewFieldsThrows() {
        #expect(throws: FENParseError.wrongFieldCount(3)) {
            _ = try FEN(parsing: "8/8/8/8/8/8/8/8 w -")
        }
    }
    
    @Test func fiveFieldsThrows() {
        // 5 fields is neither EPD (4) nor full FEN (6) — reject.
        #expect(throws: FENParseError.wrongFieldCount(5)) {
            _ = try FEN(parsing: "8/8/8/8/8/8/8/8 w - - 0")
        }
    }
    
    @Test func tooManyFieldsThrows() {
        #expect(throws: FENParseError.wrongFieldCount(7)) {
            _ = try FEN(parsing: "8/8/8/8/8/8/8/8 w - - 0 1 extra")
        }
    }
    
    // MARK: Integer Fields
    
    @Test func negativeHalfmoveThrows() {
        #expect(throws: FENParseError.malformedInteger("-1")) {
            _ = try FEN(parsing: "8/8/8/8/8/8/8/8 w - - -1 1")
        }
    }
    
    @Test func zeroFullmoveThrows() {
        // Fullmove must be ≥ 1 per FEN spec.
        #expect(throws: FENParseError.malformedInteger("0")) {
            _ = try FEN(parsing: "8/8/8/8/8/8/8/8 w - - 0 0")
        }
    }
    
    @Test func nonNumericHalfmoveThrows() {
        #expect(throws: FENParseError.malformedInteger("foo")) {
            _ = try FEN(parsing: "8/8/8/8/8/8/8/8 w - - foo 1")
        }
    }
    
    // MARK: Whitespace Handling
    
    @Test func multipleSpacesBetweenFieldsTolerated() throws {
        let fen = try FEN(parsing:
                            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR  w  KQkq  -"
        )
        #expect(fen.position == .starting)
        #expect(fen.activeColor == .white)
        #expect(fen.castlingRights == .all)
    }
    
    @Test func leadingAndTrailingWhitespaceTolerated() throws {
        let fen = try FEN(parsing: "   " + FEN.startingString + "   ")
        #expect(fen == .starting)
    }
    
    @Test func tabSeparatorsTolerated() throws {
        // `whereSeparator: \.isWhitespace` handles tabs equally well as spaces.
        let fen = try FEN(parsing:
                            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR\tw\tKQkq\t-"
        )
        #expect(fen.position == .starting)
    }
    
    // MARK: Round-Trip
    
    @Test func roundTripPreservesAllFields() throws {
        // Sweep across positions that vary every parseable field.
        let inputs = [
            FEN.startingString,
            "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
            "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2pP/R2Q1RK1 w kq - 0 1",
            "rnbqkb1r/pp1ppppp/5n2/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq c6 0 3",
            "8/8/8/8/8/8/8/4K2k b Q e3 99 250"
        ]
        
        for original in inputs {
            let fen = try FEN(parsing: original)
            #expect(
                fen.string == original,
                "Round-trip mismatch: \(original) → \(fen.string)"
            )
        }
    }
}
