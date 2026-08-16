import Testing
@testable import DGTStudioPro

@Suite("Castling Move Generation")
struct CastlingMoveGenerationTests {

    // State construction (`GameState.test`, `Position.make`) lives in
    // Support/ChessTestSupport.swift; note its castling-rights default is
    // `.none`, so the tests below pass `.all` explicitly wherever rights are
    // meant to exist - which reads better anyway, since rights are the very
    // thing under test here.

    // MARK: Helpers

    /// Builds a minimal castling test position with both kings + both white rooks
    /// on their home squares. Add additional pieces via the `extras` closure.
    private func castlingPosition(
        extras: (inout Position) -> Void = { _ in }
    ) -> Position {
        Position.make { pos in
            pos[Squares.e1] = .whiteKing
            pos[Squares.h1] = .whiteRook
            pos[Squares.a1] = .whiteRook
            pos[Squares.e8] = .blackKing
            extras(&pos)
        }
    }

    private func castlingMoves(in state: GameState) -> [Move] {
        state.legalMoves().filter { $0.isCastling }
    }

    // MARK: Both Sides Available
    @Test func bothSidesLegalEmitsTwoCastlingMoves() {
        let state = GameState.test(castlingPosition(), castlingRights: .all)
        let moves = castlingMoves(in: state)

        #expect(moves.count == 2)
        #expect(moves.contains { $0.to == Squares.g1 })
        #expect(moves.contains { $0.to == Squares.c1 })
    }

    @Test func castlingMoveCarriesCastlingFlagAndCorrectRookSquares() throws {
        let state = GameState.test(castlingPosition(), castlingRights: .all)
        let kingside = try #require(castlingMoves(in: state).first { $0.to == Squares.g1 })

        #expect(kingside.isCastling)
        #expect(kingside.from == Squares.e1)
        #expect(kingside.rookFrom == Squares.h1)
        #expect(kingside.rookTo == Squares.f1)

        let queenside = try #require(castlingMoves(in: state).first { $0.to == Squares.c1 })
        #expect(queenside.rookFrom == Squares.a1)
        #expect(queenside.rookTo == Squares.d1)
    }

    // MARK: Rights Gating
    @Test func noRightsMeansNoCastling() {
        let state = GameState.test(castlingPosition(), castlingRights: .none)
        #expect(castlingMoves(in: state).isEmpty)
    }

    @Test func onlyKingsideRights() {
        let state = GameState.test(
            castlingPosition(),
            castlingRights: .mask(for: .white, .kingSide)
        )
        let moves = castlingMoves(in: state)
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.g1)
    }

    @Test func onlyQueensideRights() {
        let state = GameState.test(
            castlingPosition(),
            castlingRights: .mask(for: .white, .queenSide)
        )
        let moves = castlingMoves(in: state)
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.c1)
    }

    // MARK: Rights Without Rooks (hand-edited state)

    /// The rook-home guard (M1 item 16): rights imply a home rook only
    /// for positions reached through `applying` - a FEN can lie, and the
    /// draft sidecar resumes through `FEN(parsing:)`. A hand-edited `KQ`
    /// over a bare back rank must generate no castling at all; pre-guard,
    /// `O-O` was emitted and `Position.applying` copied an empty square
    /// onto f1.
    @Test func rightsWithoutRooksGenerateNoCastling() {
        let bareBackRank = Position.make { pos in
            pos[Squares.e1] = .whiteKing
            pos[Squares.e8] = .blackKing
        }
        let state = GameState.test(bareBackRank, castlingRights: .all)
        #expect(castlingMoves(in: state).isEmpty)
    }

    /// One missing rook kills exactly its own wing; the other stays legal.
    @Test func missingKingsideRookKillsOnlyKingside() {
        let pos = Position.make { pos in
            pos[Squares.e1] = .whiteKing
            pos[Squares.a1] = .whiteRook      // queenside rook only
            pos[Squares.e8] = .blackKing
        }
        let state = GameState.test(pos, castlingRights: .all)
        let moves = castlingMoves(in: state)
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.c1)
    }

    /// A foreign piece on the rook's home square is not a rook: the guard
    /// compares the piece (`position[home] == homeRook`), not occupancy -
    /// a knight parked on h1 under `KQ` rights must not castle kingside.
    @Test func wrongPieceOnRookHomeSquareDoesNotCastle() {
        let pos = castlingPosition { p in p[Squares.h1] = .whiteKnight }
        let state = GameState.test(pos, castlingRights: .all)
        let moves = castlingMoves(in: state)
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.c1)
    }

    // MARK: Path Blocked
    @Test func pieceBetweenBlocksKingside() {
        let pos = castlingPosition { p in p[Squares.f1] = .whiteBishop }
        let state = GameState.test(pos, castlingRights: .all)
        let moves = castlingMoves(in: state)

        // Queenside still legal
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.c1)
    }

    @Test func pieceBetweenBlocksQueenside() {
        let pos = castlingPosition { p in p[Squares.d1] = .whiteQueen }
        let state = GameState.test(pos, castlingRights: .all)
        let moves = castlingMoves(in: state)

        // Kingside still legal
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.g1)
    }

    @Test func pieceOnBSquareBlocksQueensideEvenThoughKingDoesntPassThroughIt() {
        // The b1 square isn't part of the king's path but the rook traverses it,
        // so castling is illegal if it's occupied.
        let pos = castlingPosition { p in p[Squares.b1] = .whiteKnight }
        let state = GameState.test(pos, castlingRights: .all)
        let moves = castlingMoves(in: state)

        // Kingside legal; queenside blocked
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.g1)
    }

    // MARK: Attack Gating
    @Test func cannotCastleOutOfCheck() {
        // Black rook on e2 attacks the white king on e1
        let pos = castlingPosition { p in p[Squares.e2] = .blackRook }
        let state = GameState.test(pos, castlingRights: .all)

        #expect(state.isInCheck)
        #expect(castlingMoves(in: state).isEmpty)
    }

    @Test func cannotCastleThroughAttackedSquareKingside() {
        // Black rook on f4 attacks the king's kingside transit square f1
        let pos = castlingPosition { p in p[Squares.f4] = .blackRook }
        let state = GameState.test(pos, castlingRights: .all)
        let moves = castlingMoves(in: state)

        // Queenside still legal (transit d1 not attacked)
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.c1)
    }

    @Test func cannotCastleThroughAttackedSquareQueenside() {
        // Black rook on d4 attacks the queenside transit d1
        let pos = castlingPosition { p in p[Squares.d4] = .blackRook }
        let state = GameState.test(pos, castlingRights: .all)
        let moves = castlingMoves(in: state)

        // Kingside legal
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.g1)
    }

    @Test func cannotCastleIntoAttackedDestination() {
        // Black rook on g4 attacks the kingside destination g1 but NOT the transit f1.
        // Pseudo-legal generation emits the move; legal filter rejects it.
        let pos = castlingPosition { p in p[Squares.g4] = .blackRook }
        let state = GameState.test(pos, castlingRights: .all)
        let moves = castlingMoves(in: state)

        // Queenside still legal
        #expect(moves.count == 1)
        #expect(moves.first?.to == Squares.c1)
    }

    // MARK: Black Mirror
    @Test func blackKingsideCastling() {
        let pos = Position.make {
            $0[Squares.e1] = .whiteKing
            $0[Squares.e8] = .blackKing
            $0[Squares.h8] = .blackRook
            $0[Squares.a8] = .blackRook
        }
        let state = GameState.test(pos, activeColor: .black, castlingRights: .all)

        let moves = castlingMoves(in: state)
        #expect(moves.contains { $0.to == Squares.g8 })
        #expect(moves.contains { $0.to == Squares.c8 })
    }

    // MARK: Starting Position Sanity
    @Test func startingPositionGeneratesNoCastling() {
        // All between-squares occupied by knights/bishops/queen.
        let moves = castlingMoves(in: .starting)
        #expect(moves.isEmpty)
    }
}
