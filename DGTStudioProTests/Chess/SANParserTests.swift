//
//  SANParserTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/05/2026.
//

import Testing
@testable import DGTStudioPro

@Suite("SAN Parser")
struct SANParserTests {

    // State and position construction (`GameState.test`, `Position.make`,
    // and `Position.minimal` — the two-kings-on-e1/e8 scaffold) lives in
    // Support/ChessTestSupport.swift. Promotion tests that need e8 free
    // build with `Position.make` directly and park the black king on a8.

    // MARK: Pawn Pushes

    @Test func startingPositionParsesE4AsDoublePush() throws {
        let move = try GameState.starting.parseSAN("e4")
        #expect(move.from == Squares.e2)
        #expect(move.to == Squares.e4)
        #expect(move.pieceType == .pawn)
        #expect(move.isDoublePawnPush)
    }

    @Test func startingPositionParsesE3AsSinglePush() throws {
        let move = try GameState.starting.parseSAN("e3")
        #expect(move.from == Squares.e2)
        #expect(move.to == Squares.e3)
        #expect(!move.isDoublePawnPush)
    }

    @Test func blackPawnPush() throws {
        let state = GameState.test(
            .starting,
            activeColor: .black,
            castlingRights: .all
        )
        let move = try state.parseSAN("c5")
        #expect(move.from == Squares.c7)
        #expect(move.to == Squares.c5)
        #expect(move.isDoublePawnPush)
    }

    // MARK: Pawn Captures

    @Test func pawnCaptureWithFileDisambiguator() throws {
        let pos = Position.minimal {
            $0[Squares.e4] = .whitePawn
            $0[Squares.d5] = .blackKnight
        }
        let move = try GameState.test(pos).parseSAN("exd5")

        #expect(move.from == Squares.e4)
        #expect(move.to == Squares.d5)
        #expect(move.isCapture)
        #expect(move.capturedPieceType == .knight)
    }

    @Test func pawnCaptureWithoutFileIsRejectedAsMalformed() {
        let pos = Position.minimal {
            $0[Squares.e4] = .whitePawn
            $0[Squares.d5] = .blackKnight
        }
        let state = GameState.test(pos)

        #expect(throws: SANParseError.malformed("xd5")) {
            _ = try state.parseSAN("xd5")
        }
    }

    @Test func enPassantParsedAsCapture() throws {
        // White pawn on e5, black just played d7-d5, EP target d6.
        let pos = Position.minimal {
            $0[Squares.e5] = .whitePawn
            $0[Squares.d5] = .blackPawn
        }
        let state = GameState.test(pos, enPassantTarget: Squares.d6)

        let move = try state.parseSAN("exd6")
        #expect(move.isEnPassant)
        #expect(move.isCapture)
        #expect(move.capturedSquare == Squares.d5)
    }

    // MARK: Promotion (Three Notations)

    @Test(arguments: ["e8=Q", "e8Q", "e8(Q)"])
    func pawnPromotionAcceptsAllThreeForms(san: String) throws {
        // Black king on a8, off the promotion square, so e8 is free.
        let pos = Position.make {
            $0[Squares.e1] = .whiteKing
            $0[Squares.a8] = .blackKing
            $0[Squares.e7] = .whitePawn
        }
        let move = try GameState.test(pos).parseSAN(san)
        #expect(move.from == Squares.e7)
        #expect(move.to == Squares.e8)
        #expect(move.promotionType == .queen)
    }

    @Test(arguments: [
        ("e8=Q", PieceType.queen),
        ("e8=R", .rook),
        ("e8=B", .bishop),
        ("e8=N", .knight),
    ])
    func pawnPromotesToAllFourPieces(san: String, expected: PieceType) throws {
        let pos = Position.make {
            $0[Squares.e1] = .whiteKing
            $0[Squares.a8] = .blackKing
            $0[Squares.e7] = .whitePawn
        }
        let move = try GameState.test(pos).parseSAN(san)
        #expect(move.promotionType == expected)
    }

    @Test func capturePromotion() throws {
        let pos = Position.make {
            $0[Squares.e1] = .whiteKing
            $0[Squares.a8] = .blackKing
            $0[Squares.e7] = .whitePawn
            $0[Squares.f8] = .blackRook
        }
        let move = try GameState.test(pos).parseSAN("exf8=Q")

        #expect(move.from == Squares.e7)
        #expect(move.to == Squares.f8)
        #expect(move.capturedPieceType == .rook)
        #expect(move.promotionType == .queen)
    }

    @Test func promotionToKingIsRejected() {
        let pos = Position.make {
            $0[Squares.e1] = .whiteKing
            $0[Squares.a8] = .blackKing
            $0[Squares.e7] = .whitePawn
        }
        let state = GameState.test(pos)

        // 'K' is not a valid promotion piece — the bare-X path treats `K` as
        // not-a-promotion-letter and falls through to target-square parsing,
        // where "8K" isn't a valid square. Either way, it's malformed.
        #expect(throws: SANParseError.self) {
            _ = try state.parseSAN("e8=K")
        }
    }

    @Test func promotionOnNonPawnPieceIsRejected() {
        let pos = Position.make {
            $0[Squares.e1] = .whiteKing
            $0[Squares.a8] = .blackKing
            $0[Squares.h8] = .whiteBishop
        }
        let state = GameState.test(pos)

        #expect(throws: SANParseError.self) {
            _ = try state.parseSAN("Bxa1=Q")
        }
    }

    // MARK: Knight Moves

    @Test func startingKnightToF3() throws {
        let move = try GameState.starting.parseSAN("Nf3")
        #expect(move.from == Squares.g1)
        #expect(move.to == Squares.f3)
        #expect(move.pieceType == .knight)
    }

    @Test func knightFileDisambiguator() throws {
        // Two knights on b1 and d1 both attack c3; `Nbc3` selects b1.
        let pos = Position.minimal {
            $0[Squares.b1] = .whiteKnight
            $0[Squares.d1] = .whiteKnight
        }
        let move = try GameState.test(pos).parseSAN("Nbc3")
        #expect(move.from == Squares.b1)
        #expect(move.to == Squares.c3)
    }

    @Test func knightRankDisambiguator() throws {
        // Two knights on b1 and b5 both attack c3; `N1c3` selects rank 1.
        let pos = Position.minimal {
            $0[Squares.b1] = .whiteKnight
            $0[Squares.b5] = .whiteKnight
        }
        let move = try GameState.test(pos).parseSAN("N1c3")
        #expect(move.from == Squares.b1)
        #expect(move.to == Squares.c3)
    }

    @Test func knightFullSquareDisambiguator() throws {
        // Three knights all attack c3; only full square uniquely identifies.
        let pos = Position.minimal {
            $0[Squares.b1] = .whiteKnight
            $0[Squares.b5] = .whiteKnight
            $0[Squares.d1] = .whiteKnight
        }
        let move = try GameState.test(pos).parseSAN("Nb1c3")
        #expect(move.from == Squares.b1)
        #expect(move.to == Squares.c3)
    }

    // MARK: Sliding Pieces

    @Test func bishopMove() throws {
        let pos = Position.minimal { $0[Squares.f1] = .whiteBishop }
        let move = try GameState.test(pos).parseSAN("Bc4")
        #expect(move.from == Squares.f1)
        #expect(move.to == Squares.c4)
        #expect(move.pieceType == .bishop)
    }

    @Test func rookCapture() throws {
        let pos = Position.minimal {
            $0[Squares.a1] = .whiteRook
            $0[Squares.a7] = .blackPawn
        }
        let move = try GameState.test(pos).parseSAN("Rxa7")
        #expect(move.from == Squares.a1)
        #expect(move.to == Squares.a7)
        #expect(move.isCapture)
        #expect(move.capturedPieceType == .pawn)
    }

    @Test func queenLongMove() throws {
        let pos = Position.minimal { $0[Squares.d1] = .whiteQueen }
        let move = try GameState.test(pos).parseSAN("Qd8")
        // d1 → d8 slides the full d-file; the resulting rank-8 check on the
        // e8 king is a check white *gives*, which is perfectly legal.
        #expect(move.from == Squares.d1)
        #expect(move.to == Squares.d8)
    }

    // MARK: King Moves (non-castling)

    @Test func kingStep() throws {
        let pos = Position.minimal()  // Just the two kings.
        let move = try GameState.test(pos).parseSAN("Kd2")
        #expect(move.from == Squares.e1)
        #expect(move.to == Squares.d2)
        #expect(move.pieceType == .king)
    }

    // MARK: Castling

    @Test func kingsideCastlingOOForm() throws {
        let pos = Position.minimal { $0[Squares.h1] = .whiteRook }
        let state = GameState.test(pos, castlingRights: .all)
        let move = try state.parseSAN("O-O")

        #expect(move.isCastling)
        #expect(move.from == Squares.e1)
        #expect(move.to == Squares.g1)
    }

    @Test func queensideCastlingOOOForm() throws {
        let pos = Position.minimal { $0[Squares.a1] = .whiteRook }
        let state = GameState.test(pos, castlingRights: .all)
        let move = try state.parseSAN("O-O-O")

        #expect(move.isCastling)
        #expect(move.from == Squares.e1)
        #expect(move.to == Squares.c1)
    }

    @Test func kingsideCastlingZeroForm() throws {
        let pos = Position.minimal { $0[Squares.h1] = .whiteRook }
        let state = GameState.test(pos, castlingRights: .all)
        let move = try state.parseSAN("0-0")
        #expect(move.to == Squares.g1)
    }

    @Test func queensideCastlingZeroForm() throws {
        let pos = Position.minimal { $0[Squares.a1] = .whiteRook }
        let state = GameState.test(pos, castlingRights: .all)
        let move = try state.parseSAN("0-0-0")
        #expect(move.to == Squares.c1)
    }

    @Test func castlingWithCheckSuffix() throws {
        // A castling that delivers check still parses cleanly with `+`.
        let pos = Position.minimal { $0[Squares.h1] = .whiteRook }
        let state = GameState.test(pos, castlingRights: .all)
        let move = try state.parseSAN("O-O+")
        #expect(move.isCastling)
    }

    @Test func castlingWithoutRightsThrowsNoMatch() {
        // Pieces are in place but castling rights are empty.
        let pos = Position.minimal { $0[Squares.h1] = .whiteRook }
        let state = GameState.test(pos, castlingRights: .none)

        #expect(throws: SANParseError.noMatchingMove("O-O")) {
            _ = try state.parseSAN("O-O")
        }
    }

    // MARK: Suffixes

    @Test func checkSuffixStripped() throws {
        let move = try GameState.starting.parseSAN("e4+")
        #expect(move.to == Squares.e4)
    }

    @Test func mateSuffixStripped() throws {
        let move = try GameState.starting.parseSAN("e4#")
        #expect(move.to == Squares.e4)
    }

    @Test func annotationSuffixesStripped() throws {
        // PGNParser strips !/? at the tokenization layer, but parseSAN
        // tolerates them defensively.
        let move = try GameState.starting.parseSAN("e4!?")
        #expect(move.to == Squares.e4)
    }

    @Test func multipleMixedSuffixes() throws {
        let move = try GameState.starting.parseSAN("e4!!+")
        #expect(move.to == Squares.e4)
    }

    // MARK: Errors

    @Test func emptyString() {
        #expect(throws: SANParseError.empty) {
            _ = try GameState.starting.parseSAN("")
        }
    }

    @Test func whitespaceOnly() {
        #expect(throws: SANParseError.empty) {
            _ = try GameState.starting.parseSAN("   ")
        }
    }

    @Test func suffixesOnlyAfterStripping() {
        // Stripping `+++` leaves nothing — malformed (carries the original).
        #expect(throws: SANParseError.malformed("+++")) {
            _ = try GameState.starting.parseSAN("+++")
        }
    }

    @Test func garbledStringIsMalformed() {
        #expect(throws: SANParseError.malformed("zzz")) {
            _ = try GameState.starting.parseSAN("zzz")
        }
    }

    @Test func nonexistentMoveThrowsNoMatch() {
        // `e5` from the starting position — pawn on e2 cannot reach e5 in one move.
        #expect(throws: SANParseError.noMatchingMove("e5")) {
            _ = try GameState.starting.parseSAN("e5")
        }
    }

    @Test func ambiguousKnightMoveReportsCount() {
        // Both b1 and d1 knights attack c3; without disambiguator, ambiguous(2).
        let pos = Position.minimal {
            $0[Squares.b1] = .whiteKnight
            $0[Squares.d1] = .whiteKnight
        }
        let state = GameState.test(pos)

        #expect(throws: SANParseError.ambiguous("Nc3", count: 2)) {
            _ = try state.parseSAN("Nc3")
        }
    }

    @Test func captureMarkerMustMatch() {
        // `Nxf3` from the starting position: f3 is empty, so it's not a capture.
        // The strict capture-flag rule rejects this even though Nf3 is legal.
        #expect(throws: SANParseError.noMatchingMove("Nxf3")) {
            _ = try GameState.starting.parseSAN("Nxf3")
        }
    }

    // MARK: FEN Forwarding

    @Test func fenForwardsToGameState() throws {
        let move = try FEN.starting.parseSAN("e4")
        #expect(move.from == Squares.e2)
        #expect(move.to == Squares.e4)
    }

    @Test func fenForwardingPropagatesErrors() {
        #expect(throws: SANParseError.empty) {
            _ = try FEN.starting.parseSAN("")
        }
    }
}
