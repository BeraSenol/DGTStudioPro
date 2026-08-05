import Testing
@testable import DGTStudioPro

/// Acceptance coverage for `FEN(parsing:)` — the happy path: the starting
/// position, real reference positions, both field-count variants, every
/// accepted per-field form, whitespace tolerance, and the full round-trip.
/// Its complement, `FENParsingRejectionTests`, owns *all* malformed-input
/// pins; a rejection case belongs there, not here (the two suites carried
/// duplicated rejection tests for a while — that overlap has been removed,
/// with this file keeping acceptance only).
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

    // MARK: Position Key

    @Test func positionKeyCarriesEveryDoublePushEPTarget() throws {
        // `updatedEnPassantTarget` is *permissive*: it stamps the skipped
        // square after every double push, capturable or not — so two states
        // identical in placement, side, and rights get different
        // `positionKey`s when only a dead EP right separates them. After
        // 1. e4 no black pawn attacks e3, yet the key still says `e3`.
        //
        // Pinned as documentation, not endorsement: `positionKey` has no
        // repetition consumer today, but FIDE's repetition rule counts the
        // EP square only when the capture is actually playable (capturer
        // present, unpinned, not in check). Any future threefold/fivefold
        // fold over this key must strictify the EP field first, or it will
        // miss exactly the repetitions players notice. The convention
        // choice is a decision for that feature; this test is the tripwire
        // that makes it one.
        let start: GameState = .starting
        let afterDoublePush = start.applying(try start.parseSAN("e4"))

        let permissive = FEN(
            position: afterDoublePush.position,
            activeColor: afterDoublePush.activeColor,
            castlingRights: afterDoublePush.castlingRights,
            enPassantTarget: afterDoublePush.enPassantTarget,
            halfmoveClock: afterDoublePush.halfmoveClock,
            fullmoveNumber: afterDoublePush.fullmoveNumber
        )
        let withoutEP = FEN(
            position: afterDoublePush.position,
            activeColor: afterDoublePush.activeColor,
            castlingRights: afterDoublePush.castlingRights,
            enPassantTarget: nil,
            halfmoveClock: afterDoublePush.halfmoveClock,
            fullmoveNumber: afterDoublePush.fullmoveNumber
        )

        #expect(permissive.enPassantTarget == Squares.e3)
        #expect(permissive.positionKey.hasSuffix(" e3"))
        #expect(permissive.positionKey != withoutEP.positionKey)
    }
}
