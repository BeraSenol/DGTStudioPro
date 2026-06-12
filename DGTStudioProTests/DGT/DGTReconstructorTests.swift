//
//  DGTReconstructorTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 26/05/2026.
//

import Testing
@testable import DGTStudioPro

/// Per-move-class tests for the reconstruction engine, driven by the
/// hardware-free `DGTBoardSimulator`. Each test replays a realistic lift/place
/// update sequence for one move class and asserts that the *final* board
/// reconstructs to the intended legal move, while *intermediate* (piece-in-hand)
/// boards report `.inProgress` (or `.castlingInProgress`) rather than firing a
/// move or a false desync. Recovery (D6) consumes the `.unresolved` case.
@Suite("DGT Reconstructor")
struct DGTReconstructorTests {

    // MARK: Helpers

    /// The unique legal move with these coordinates, for building expectations.
    /// (`GameState.parsing` lives in Support/ChessTestSupport.swift.)
    private func legalMove(
        _ state: GameState,
        from: Square,
        to: Square,
        promotion: PieceType? = nil
    ) throws -> Move {
        try #require(
            DGTReconstructor.move(from: from, to: to, promotion: promotion, in: state),
            "Expected a legal move \(from)→\(to)"
        )
    }

    // MARK: Normal Move

    @Test func normalMoveReconstructs() throws {
        let start = GameState.starting
        let expected = try legalMove(start, from: Squares.e2, to: Squares.e4)

        let updates: [DGTBoardSimulator.Update] = [
            (Squares.e2, .empty),
            (Squares.e4, .whitePawn),
        ]
        let boards = DGTBoardSimulator.boards(from: start.position, updates: updates)

        // Mid-move: the pawn is in hand.
        #expect(DGTReconstructor.reconstruct(from: start, physical: boards[0]) == .inProgress)
        // Settled: the move is recognized.
        #expect(DGTReconstructor.reconstruct(from: start, physical: boards[1]) == .move(expected))
    }

    /// The black-to-move mirror of `normalMoveReconstructs`. Every other case
    /// in this suite moves White; this one guards the `mover`-color filtering
    /// (`vacatedByMover` / `placedByMover`) and the a8↔a1 transform's symmetry,
    /// which a one-sided suite would never exercise.
    @Test func blackNormalMoveReconstructs() throws {
        // After 1.e4 — Black to move, e-file double push available.
        let start = try GameState.parsing(
            "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
        )
        let expected = try legalMove(start, from: Squares.e7, to: Squares.e5)

        let updates: [DGTBoardSimulator.Update] = [
            (Squares.e7, .empty),
            (Squares.e5, .blackPawn),
        ]
        let boards = DGTBoardSimulator.boards(from: start.position, updates: updates)

        #expect(DGTReconstructor.reconstruct(from: start, physical: boards[0]) == .inProgress)
        #expect(DGTReconstructor.reconstruct(from: start, physical: boards[1]) == .move(expected))
    }

    // MARK: Capture (order-independent)

    @Test func captureReconstructsRegardlessOfLiftOrder() throws {
        let state = try GameState.parsing("4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1")
        let expected = try legalMove(state, from: Squares.e4, to: Squares.d5)

        // Lift attacker, then place on the captured square.
        let attackerFirst: [DGTBoardSimulator.Update] = [
            (Squares.e4, .empty),
            (Squares.d5, .whitePawn),
        ]
        // Lift the captured piece first, then the attacker, then place.
        let capturedFirst: [DGTBoardSimulator.Update] = [
            (Squares.d5, .empty),
            (Squares.e4, .empty),
            (Squares.d5, .whitePawn),
        ]

        for updates in [attackerFirst, capturedFirst] {
            let boards = DGTBoardSimulator.boards(from: state.position, updates: updates)
            // Every intermediate board is removals-only → in hand.
            for board in boards.dropLast() {
                #expect(DGTReconstructor.reconstruct(from: state, physical: board) == .inProgress)
            }
            #expect(DGTReconstructor.reconstruct(from: state, physical: boards.last!) == .move(expected))
        }
    }

    // MARK: En Passant

    @Test func enPassantReconstructs() throws {
        let state = try GameState.parsing("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
        let expected = try legalMove(state, from: Squares.e5, to: Squares.d6)
        #expect(expected.isEnPassant)

        let updates: [DGTBoardSimulator.Update] = [
            (Squares.e5, .empty),     // lift attacker
            (Squares.d5, .empty),     // lift the captured pawn (off the to-square)
            (Squares.d6, .whitePawn), // place attacker
        ]
        let boards = DGTBoardSimulator.boards(from: state.position, updates: updates)

        #expect(DGTReconstructor.reconstruct(from: state, physical: boards[0]) == .inProgress)
        #expect(DGTReconstructor.reconstruct(from: state, physical: boards[1]) == .inProgress)
        #expect(DGTReconstructor.reconstruct(from: state, physical: boards[2]) == .move(expected))
    }

    /// A very common casual-play slip: the attacker lands on the en-passant
    /// target but the player forgets to lift the captured pawn. The EP diff is
    /// otherwise indistinguishable from a plain pawn push, so the candidate's
    /// `applying(...)` check fails and a naive engine would flag a desync.
    /// Instead this surfaces as a gentle `.correctable` — the recognized EP
    /// move plus the square the player must still clear — NOT `.unresolved`, so
    /// recovery never takes over. The completing `.move` lands once the pawn is
    /// lifted (see `enPassantReconstructs`).
    @Test func enPassantWithoutLiftingCapturedPawnIsCorrectable() throws {
        let state = try GameState.parsing("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
        let ep = try legalMove(state, from: Squares.e5, to: Squares.d6)
        #expect(ep.isEnPassant)

        // Attacker e5→d6, but the captured d5 pawn is never lifted.
        let final = DGTBoardSimulator.finalBoard(
            from: state.position,
            updates: [
                (Squares.e5, .empty),
                (Squares.d6, .whitePawn),
                // d5 black pawn intentionally left in place.
            ]
        )
        #expect(
            DGTReconstructor.reconstruct(from: state, physical: final)
            == .correctable(move: ep, clear: [Squares.d5], expectedAfter: state.position.applying(ep))
        )
    }

    /// Black-to-move mirror of the correctable EP case, guarding the
    /// `mover`-color filtering and the a8↔a1 transform's symmetry. After 1.d4
    /// (EP target d3) Black's e4 pawn captures en passant to d3, but the white
    /// d4 pawn is left on the board.
    @Test func blackEnPassantWithoutLiftingCapturedPawnIsCorrectable() throws {
        let state = try GameState.parsing("4k3/8/8/8/3Pp3/8/8/4K3 b - d3 0 1")
        let ep = try legalMove(state, from: Squares.e4, to: Squares.d3)
        #expect(ep.isEnPassant)

        let final = DGTBoardSimulator.finalBoard(
            from: state.position,
            updates: [
                (Squares.e4, .empty),
                (Squares.d3, .blackPawn),
                // d4 white pawn intentionally left in place.
            ]
        )
        #expect(
            DGTReconstructor.reconstruct(from: state, physical: final)
            == .correctable(move: ep, clear: [Squares.d4], expectedAfter: state.position.applying(ep))
        )
    }

    /// `.correctable` is narrow: it only rescues a *recognized legal* en
    /// passant. The identical physical pattern (attacker on the EP target, the
    /// neighbouring enemy pawn still present) with no EP right is simply an
    /// illegal pawn move and must remain `.unresolved` — the correctable nudge
    /// must never paper over a genuine fumble.
    @Test func epTargetReachedWithoutLegalEnPassantIsUnresolved() throws {
        // Same shape as the correctable case, but no EP target in the FEN.
        let state = try GameState.parsing("4k3/8/8/3pP3/8/8/8/4K3 w - - 0 1")
        let final = DGTBoardSimulator.finalBoard(
            from: state.position,
            updates: [
                (Squares.e5, .empty),
                (Squares.d6, .whitePawn),
                // d5 black pawn left in place — but there is no EP right here.
            ]
        )
        #expect(DGTReconstructor.reconstruct(from: state, physical: final) == .unresolved)
    }

    // MARK: Castling — Kingside

    @Test func castlingReconstructsWhenComplete() throws {
        let state = try GameState.parsing("4k3/8/8/8/8/8/8/4K2R w K - 0 1")
        let expected = try legalMove(state, from: Squares.e1, to: Squares.g1)
        #expect(expected.isCastling)

        // King first, then rook.
        let kingFirst: [DGTBoardSimulator.Update] = [
            (Squares.e1, .empty),
            (Squares.g1, .whiteKing),
            (Squares.h1, .empty),
            (Squares.f1, .whiteRook),
        ]
        // Rook first, then king.
        let rookFirst: [DGTBoardSimulator.Update] = [
            (Squares.h1, .empty),
            (Squares.f1, .whiteRook),
            (Squares.e1, .empty),
            (Squares.g1, .whiteKing),
        ]

        for updates in [kingFirst, rookFirst] {
            let final = DGTBoardSimulator.finalBoard(from: state.position, updates: updates)
            #expect(DGTReconstructor.reconstruct(from: state, physical: final) == .move(expected))
        }
    }

    @Test func castlingKingMoveShowsInProgress() throws {
        let state = try GameState.parsing("4k3/8/8/8/8/8/8/4K2R w K - 0 1")
        let expected = try legalMove(state, from: Squares.e1, to: Squares.g1)

        // King has moved two squares; rook still on h1.
        let updates: [DGTBoardSimulator.Update] = [
            (Squares.e1, .empty),
            (Squares.g1, .whiteKing),
        ]
        let boards = DGTBoardSimulator.boards(from: state.position, updates: updates)

        // Just the king lifted → in hand.
        #expect(DGTReconstructor.reconstruct(from: state, physical: boards[0]) == .inProgress)
        // King placed two squares over, rook not yet → ghost-rook state.
        #expect(DGTReconstructor.reconstruct(from: state, physical: boards[1]) == .castlingInProgress(expected))
    }

    // MARK: Castling — Queenside

    /// Queenside is geometrically distinct: the rook travels three squares
    /// (a1→d1) and passes the b1/c1 squares. The kingside cases above can't
    /// catch a queenside-specific rook-destination bug, so it gets its own
    /// both-lift-orders proof.
    @Test func queensideCastlingReconstructsWhenComplete() throws {
        let state = try GameState.parsing("4k3/8/8/8/8/8/8/R3K3 w Q - 0 1")
        let expected = try legalMove(state, from: Squares.e1, to: Squares.c1)
        #expect(expected.isCastling)

        // King first, then rook.
        let kingFirst: [DGTBoardSimulator.Update] = [
            (Squares.e1, .empty),
            (Squares.c1, .whiteKing),
            (Squares.a1, .empty),
            (Squares.d1, .whiteRook),
        ]
        // Rook first, then king.
        let rookFirst: [DGTBoardSimulator.Update] = [
            (Squares.a1, .empty),
            (Squares.d1, .whiteRook),
            (Squares.e1, .empty),
            (Squares.c1, .whiteKing),
        ]

        for updates in [kingFirst, rookFirst] {
            let final = DGTBoardSimulator.finalBoard(from: state.position, updates: updates)
            #expect(DGTReconstructor.reconstruct(from: state, physical: final) == .move(expected))
        }
    }

    @Test func queensideCastlingKingMoveShowsInProgress() throws {
        let state = try GameState.parsing("4k3/8/8/8/8/8/8/R3K3 w Q - 0 1")
        let expected = try legalMove(state, from: Squares.e1, to: Squares.c1)

        // King has moved two squares to c1; rook still on a1.
        let final = DGTBoardSimulator.finalBoard(
            from: state.position,
            updates: [
                (Squares.e1, .empty),
                (Squares.c1, .whiteKing),
            ]
        )
        #expect(DGTReconstructor.reconstruct(from: state, physical: final) == .castlingInProgress(expected))
    }

    // MARK: Promotion

    @Test func promotionReadsDetectedPiece() throws {
        let state = try GameState.parsing("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
        let expected = try legalMove(state, from: Squares.a7, to: Squares.a8, promotion: .queen)

        let updates: [DGTBoardSimulator.Update] = [
            (Squares.a7, .empty),
            (Squares.a8, .whiteQueen),
        ]
        let final = DGTBoardSimulator.finalBoard(from: state.position, updates: updates)
        #expect(DGTReconstructor.reconstruct(from: state, physical: final) == .move(expected))
    }

    /// Underpromotion is rare physically, but the engine reads the *detected*
    /// piece rather than hardcoding a queen. Placing a knight on the promotion
    /// square must reconstruct to the knight-promotion move — proving
    /// `promotionType` is driven by the board, not an assumption.
    @Test func underpromotionReadsDetectedPiece() throws {
        let state = try GameState.parsing("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
        let expected = try legalMove(state, from: Squares.a7, to: Squares.a8, promotion: .knight)
        #expect(expected.promotionType == .knight)

        let final = DGTBoardSimulator.finalBoard(
            from: state.position,
            updates: [
                (Squares.a7, .empty),
                (Squares.a8, .whiteKnight),
            ]
        )
        #expect(DGTReconstructor.reconstruct(from: state, physical: final) == .move(expected))
    }

    // MARK: Non-Moves & Fumbles

    @Test func unchangedBoardIsNoChange() {
        let start = GameState.starting
        #expect(DGTReconstructor.reconstruct(from: start, physical: start.position) == .noChange)
    }

    @Test func liftAndReplaceSettlesToNoChange() {
        // A piece lifted and returned to its own square ends identical.
        let start = GameState.starting
        let final = DGTBoardSimulator.finalBoard(
            from: start.position,
            updates: [(Squares.e2, .empty), (Squares.e2, .whitePawn)]
        )
        #expect(DGTReconstructor.reconstruct(from: start, physical: final) == .noChange)
    }

    @Test func illegalPlacementIsUnresolved() throws {
        // e2 pawn placed on e5 (a three-square jump) — no legal move produces it.
        let start = GameState.starting
        let final = DGTBoardSimulator.finalBoard(
            from: start.position,
            updates: [(Squares.e2, .empty), (Squares.e5, .whitePawn)]
        )
        #expect(DGTReconstructor.reconstruct(from: start, physical: final) == .unresolved)
    }

    @Test func strayExtraPieceMakesAnOtherwiseLegalMoveUnresolved() throws {
        // A legal e2→e4, but a second white piece also teleports — the move
        // no longer fully explains the board, so it's a fumble, not a move.
        let start = GameState.starting
        let final = DGTBoardSimulator.finalBoard(
            from: start.position,
            updates: [
                (Squares.e2, .empty),
                (Squares.e4, .whitePawn),
                (Squares.d2, .empty),
                (Squares.d5, .whitePawn),
            ]
        )
        #expect(DGTReconstructor.reconstruct(from: start, physical: final) == .unresolved)
    }
}
