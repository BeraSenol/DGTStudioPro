//
//  SANSerializerTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 10/05/2026.
//

import Testing
@testable import DGTStudioPro

@Suite("SAN Serializer")
struct SANSerializerTests {

    // State and position construction (`GameState.test`, `Position.make`,
    // and `Position.minimal` — the two-kings-on-e1/e8 scaffold) lives in
    // Support/ChessTestSupport.swift. Promotion and back-rank tests that
    // need e8 free build with `Position.make` directly.

    // MARK: Pawn Pushes

    @Test func pawnSinglePush() {
        let move = Move.make(
            from: Squares.e2, to: Squares.e3,
            pieceType: .pawn, pieceColor: .white
        )
        #expect(GameState.starting.san(for: move) == "e3")
    }

    @Test func pawnDoublePush() {
        let move = Move.make(
            from: Squares.e2, to: Squares.e4,
            pieceType: .pawn, pieceColor: .white,
            isDoublePawnPush: true
        )
        #expect(GameState.starting.san(for: move) == "e4")
    }

    // MARK: Pawn Captures

    @Test func pawnCaptureCarriesFileLetter() {
        let pos = Position.minimal {
            $0[Squares.e4] = .whitePawn
            $0[Squares.d5] = .blackKnight
        }
        let move = Move.make(
            from: Squares.e4, to: Squares.d5,
            pieceType: .pawn, pieceColor: .white,
            capturedPieceType: .knight
        )
        #expect(GameState.test(pos).san(for: move) == "exd5")
    }

    @Test func enPassantSerializesAsRegularPawnCapture() {
        let pos = Position.minimal {
            $0[Squares.e5] = .whitePawn
            $0[Squares.d5] = .blackPawn
        }
        let state = GameState.test(pos, enPassantTarget: Squares.d6)
        let move = Move.make(
            from: Squares.e5, to: Squares.d6,
            pieceType: .pawn, pieceColor: .white,
            capturedPieceType: .pawn,
            isEnPassant: true
        )
        // SAN doesn't distinguish EP from regular captures.
        #expect(state.san(for: move) == "exd6")
    }

    // MARK: Knight Disambiguation

    @Test func knightWithoutDisambiguator() {
        let move = Move.make(
            from: Squares.g1, to: Squares.f3,
            pieceType: .knight, pieceColor: .white
        )
        #expect(GameState.starting.san(for: move) == "Nf3")
    }

    @Test func knightFileDisambiguator() {
        // Two knights on b1 and d1 both attack c3; b1 → c3 needs `b` file.
        let pos = Position.minimal {
            $0[Squares.b1] = .whiteKnight
            $0[Squares.d1] = .whiteKnight
        }
        let move = Move.make(
            from: Squares.b1, to: Squares.c3,
            pieceType: .knight, pieceColor: .white
        )
        #expect(GameState.test(pos).san(for: move) == "Nbc3")
    }

    @Test func knightRankDisambiguator() {
        // Two knights on b1 and b5 both attack c3; b1 → c3 needs rank `1`.
        let pos = Position.minimal {
            $0[Squares.b1] = .whiteKnight
            $0[Squares.b5] = .whiteKnight
        }
        let move = Move.make(
            from: Squares.b1, to: Squares.c3,
            pieceType: .knight, pieceColor: .white
        )
        #expect(GameState.test(pos).san(for: move) == "N1c3")
    }

    @Test func knightFullSquareDisambiguator() {
        // Three knights at b1, b5, d1 all attack c3 — need full square for b1 → c3.
        let pos = Position.minimal {
            $0[Squares.b1] = .whiteKnight
            $0[Squares.b5] = .whiteKnight
            $0[Squares.d1] = .whiteKnight
        }
        let move = Move.make(
            from: Squares.b1, to: Squares.c3,
            pieceType: .knight, pieceColor: .white
        )
        #expect(GameState.test(pos).san(for: move) == "Nb1c3")
    }

    // MARK: Sliding Pieces

    @Test func bishopMove() {
        let pos = Position.minimal { $0[Squares.f1] = .whiteBishop }
        let move = Move.make(
            from: Squares.f1, to: Squares.c4,
            pieceType: .bishop, pieceColor: .white
        )
        #expect(GameState.test(pos).san(for: move) == "Bc4")
    }

    @Test func rookCapture() {
        let pos = Position.minimal {
            $0[Squares.a1] = .whiteRook
            $0[Squares.a7] = .blackPawn
        }
        let move = Move.make(
            from: Squares.a1, to: Squares.a7,
            pieceType: .rook, pieceColor: .white,
            capturedPieceType: .pawn
        )
        #expect(GameState.test(pos).san(for: move) == "Rxa7")
    }

    // MARK: King Moves

    @Test func kingStep() {
        let pos = Position.minimal()
        let move = Move.make(
            from: Squares.e1, to: Squares.d2,
            pieceType: .king, pieceColor: .white
        )
        #expect(GameState.test(pos).san(for: move) == "Kd2")
    }

    // MARK: Castling

    @Test func kingsideCastlingSerializesOO() {
        let pos = Position.minimal { $0[Squares.h1] = .whiteRook }
        let state = GameState.test(pos, castlingRights: .all)
        let move = Move.make(
            from: Squares.e1, to: Squares.g1,
            pieceType: .king, pieceColor: .white,
            isCastling: true
        )
        #expect(state.san(for: move) == "O-O")
    }

    @Test func queensideCastlingSerializesOOO() {
        let pos = Position.minimal { $0[Squares.a1] = .whiteRook }
        let state = GameState.test(pos, castlingRights: .all)
        let move = Move.make(
            from: Squares.e1, to: Squares.c1,
            pieceType: .king, pieceColor: .white,
            isCastling: true
        )
        #expect(state.san(for: move) == "O-O-O")
    }

    // MARK: Promotion

    @Test(arguments: [
        (PieceType.queen,  "e8=Q"),
        (.rook,            "e8=R"),
        (.bishop,          "e8=B"),
        (.knight,          "e8=N"),
    ])
    func promotionUsesCanonicalEqualsForm(piece: PieceType, expected: String) {
        // Black king on a8, off the promotion square, so e8 is free.
        let pos = Position.make {
            $0[Squares.e1] = .whiteKing
            $0[Squares.a8] = .blackKing
            $0[Squares.e7] = .whitePawn
        }
        let move = Move.make(
            from: Squares.e7, to: Squares.e8,
            pieceType: .pawn, pieceColor: .white,
            promotionType: piece
        )
        #expect(GameState.test(pos).san(for: move).hasPrefix(expected))
    }

    @Test func capturePromotion() {
        let pos = Position.make {
            $0[Squares.e1] = .whiteKing
            $0[Squares.a8] = .blackKing
            $0[Squares.e7] = .whitePawn
            $0[Squares.f8] = .blackRook
        }
        let move = Move.make(
            from: Squares.e7, to: Squares.f8,
            pieceType: .pawn, pieceColor: .white,
            capturedPieceType: .rook,
            promotionType: .queen
        )
        // Whether the resulting position is check/mate is incidental — we
        // just verify the body of the SAN is correct.
        let san = GameState.test(pos).san(for: move)
        #expect(san.hasPrefix("exf8=Q"))
    }

    // MARK: Check / Mate Suffix

    @Test func checkAddsPlusSuffix() {
        // Black king on h8 (not e8): after Ra8 the rook attacks h8 along
        // rank 8, so the move delivers check — the king can still escape
        // via g7/h7, so it's `+`, not `#`.
        let pos = Position.make {
            $0[Squares.e1] = .whiteKing
            $0[Squares.h8] = .blackKing
            $0[Squares.a1] = .whiteRook
        }
        let move = Move.make(
            from: Squares.a1, to: Squares.a8,
            pieceType: .rook, pieceColor: .white
        )
        #expect(GameState.test(pos).san(for: move) == "Ra8+")
    }

    @Test func mateAddsHashSuffix() {
        // Back-rank mate: white rook to a8, black king h8 boxed in by own pawns.
        let pos = Position.make {
            $0[Squares.e1] = .whiteKing
            $0[Squares.h8] = .blackKing
            $0[Squares.g7] = .blackPawn
            $0[Squares.h7] = .blackPawn
            $0[Squares.a1] = .whiteRook
        }
        let move = Move.make(
            from: Squares.a1, to: Squares.a8,
            pieceType: .rook, pieceColor: .white
        )
        // King has no escape: g8 attacked by rook (rank 8); h7/g7 occupied by own pawns.
        #expect(GameState.test(pos).san(for: move) == "Ra8#")
    }

    @Test func checkPrefersMateOverPlus() {
        // Sanity: the suffix logic checks mate first, so a check-that-is-also-mate
        // gets `#`, never `+`.
        let pos = Position.make {
            $0[Squares.e1] = .whiteKing
            $0[Squares.h8] = .blackKing
            $0[Squares.g7] = .blackPawn
            $0[Squares.h7] = .blackPawn
            $0[Squares.a1] = .whiteRook
        }
        let move = Move.make(
            from: Squares.a1, to: Squares.a8,
            pieceType: .rook, pieceColor: .white
        )
        let san = GameState.test(pos).san(for: move)
        #expect(san.hasSuffix("#"))
        #expect(!san.hasSuffix("+"))
    }

    // MARK: FEN Forwarding

    @Test func fenForwardsToGameState() {
        let move = Move.make(
            from: Squares.e2, to: Squares.e4,
            pieceType: .pawn, pieceColor: .white,
            isDoublePawnPush: true
        )
        #expect(FEN.starting.san(for: move) == "e4")
    }

    // MARK: Round-Trip Tests (parser ↔ serializer)

    @Test func roundTripStartingPositionMoves() throws {
        // Each canonical SAN parses to a legal move that re-serializes back to itself.
        let starting: GameState = .starting
        for san in ["e4", "e3", "d4", "Nf3", "Nc3", "a3", "h4"] {
            let move = try starting.parseSAN(san)
            #expect(starting.san(for: move) == san, "Round-trip failed for: \(san)")
        }
    }

    @Test func roundTripScholarsMate() throws {
        // 1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7#
        let moves = ["e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#"]
        var state: GameState = .starting

        for san in moves {
            let move = try state.parseSAN(san)
            let serialized = state.san(for: move)
            #expect(serialized == san, "Round-trip failed at \(san) — got \(serialized)")
            state = state.applying(move)
        }

        // Final position is checkmate.
        #expect(state.isCheckmate)
    }

    @Test func roundTripItalianGame() throws {
        // 1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. O-O Nf6 5. d3 d6
        let moves = ["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5", "O-O", "Nf6", "d3", "d6"]
        var state: GameState = .starting

        for san in moves {
            let move = try state.parseSAN(san)
            let serialized = state.san(for: move)
            #expect(serialized == san, "Round-trip failed at \(san) — got \(serialized)")
            state = state.applying(move)
        }
    }

    @Test func roundTripWithEnPassant() throws {
        // 1. e4 a6 2. e5 d5 — black plays d7-d5; white can capture EP via 3. exd6
        let setupMoves = ["e4", "a6", "e5", "d5"]
        var state: GameState = .starting
        for san in setupMoves {
            state = state.applying(try state.parseSAN(san))
        }

        // Now white plays exd6 (en passant).
        let epMove = try state.parseSAN("exd6")
        #expect(epMove.isEnPassant)
        #expect(state.san(for: epMove) == "exd6")
    }
}
