//
//  MoveFootprintTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/05/2026.
//

import Testing
@testable import DGTStudioPro

/// Pins the two chess-core facts an eBoard move tracker depends on, framed
/// the way the tracker sees the world — physical squares, not SAN.
///
/// A DGT board reports lift/place events on individual squares. To turn
/// those into a logical `Move`, the tracker relies on:
///
///  1. **Footprint** — the exact set of squares a legal move changes must
///     match what the board observes. This is non-trivial for en passant
///     (the captured pawn lifts from a square *other* than the destination)
///     and castling (two pieces move), which are the patterns most likely
///     to be mis-recognised from raw lift/place events.
///
///  2. **Coordinate identity** — physical `(from, to)` plus, when relevant,
///     the promoted piece must resolve to a *unique* legal move. If two
///     distinct legal moves ever shared those coordinates the tracker
///     could not disambiguate from board observation alone. This suite
///     proves that the only source of `(from, to)` collision is promotion,
///     which the board resolves physically (the player places the actual
///     promoted piece).
@Suite("Move Footprint & Coordinate Identity")
struct MoveFootprintTests {
    
    // MARK: Footprint Helper
    
    /// The set of squares whose contents differ between two positions —
    /// i.e. the lifts and places a board would register for the transition.
    private func changedSquares(_ before: Position, _ after: Position) -> Set<Square> {
        var changed: Set<Square> = []
        for square in Square.all where before[square] != after[square] {
            changed.insert(square)
        }
        return changed
    }
    
    private func position(_ build: (inout Position) -> Void) -> Position {
        var pos = Position.empty
        build(&pos)
        return pos
    }
    
    // MARK: Quiet & Capture Footprints
    
    @Test func quietPushTouchesExactlyTwoSquares() {
        let move = Move.make(
            from: Squares.e2, to: Squares.e4,
            pieceType: .pawn, pieceColor: .white,
            isDoublePawnPush: true
        )
        let after = Position.starting.applying(move)
        #expect(changedSquares(.starting, after) == [Squares.e2, Squares.e4])
    }
    
    @Test func captureTouchesExactlyFromAndTo() {
        let before = position {
            $0[Squares.a1] = .whiteRook
            $0[Squares.a7] = .blackPawn
        }
        let move = Move.make(
            from: Squares.a1, to: Squares.a7,
            pieceType: .rook, pieceColor: .white,
            capturedPieceType: .pawn
        )
        let after = before.applying(move)
        // Capture footprint is the same two squares as a quiet move — the
        // board distinguishes them only by what was on `to` beforehand.
        #expect(changedSquares(before, after) == [Squares.a1, Squares.a7])
        #expect(after[Squares.a7] == .whiteRook)
        #expect(after[Squares.a1] == .empty)
    }
    
    // MARK: En Passant Footprint (the three-square pattern)
    
    @Test func enPassantTouchesThreeSquaresIncludingTheOffsetCapture() {
        let before = position {
            $0[Squares.e5] = .whitePawn
            $0[Squares.d5] = .blackPawn   // just played d7-d5
        }
        let move = Move.make(
            from: Squares.e5, to: Squares.d6,
            pieceType: .pawn, pieceColor: .white,
            capturedPieceType: .pawn,
            isEnPassant: true
        )
        let after = before.applying(move)
        
        // Three squares change, and the captured pawn lifts from d5 — NOT
        // from the destination d6. A tracker keying captures off `to` would
        // miss this; it must consult move.capturedSquare.
        #expect(changedSquares(before, after) == [Squares.e5, Squares.d5, Squares.d6])
        #expect(move.capturedSquare == Squares.d5)
        #expect(move.capturedSquare != move.to)
        #expect(after[Squares.d6] == .whitePawn)
        #expect(after[Squares.d5] == .empty)
        #expect(after[Squares.e5] == .empty)
    }
    
    // MARK: Castling Footprint (two pieces, four squares)
    
    @Test func kingsideCastlingTouchesKingAndRookSquares() {
        let before = position {
            $0[Squares.e1] = .whiteKing
            $0[Squares.h1] = .whiteRook
        }
        let move = Move.make(
            from: Squares.e1, to: Squares.g1,
            pieceType: .king, pieceColor: .white,
            isCastling: true
        )
        let after = before.applying(move)
        
        // Four squares, two pieces in motion — the board sees two lifts and
        // two places, and the rook squares come from move.rookFrom/rookTo.
        #expect(changedSquares(before, after) == [Squares.e1, Squares.g1, Squares.h1, Squares.f1])
        #expect(move.rookFrom == Squares.h1)
        #expect(move.rookTo == Squares.f1)
        #expect(after[Squares.g1] == .whiteKing)
        #expect(after[Squares.f1] == .whiteRook)
    }
    
    @Test func queensideCastlingTouchesKingAndRookSquares() {
        let before = position {
            $0[Squares.e1] = .whiteKing
            $0[Squares.a1] = .whiteRook
        }
        let move = Move.make(
            from: Squares.e1, to: Squares.c1,
            pieceType: .king, pieceColor: .white,
            isCastling: true
        )
        let after = before.applying(move)
        #expect(changedSquares(before, after) == [Squares.e1, Squares.c1, Squares.a1, Squares.d1])
        #expect(move.rookFrom == Squares.a1)
        #expect(move.rookTo == Squares.d1)
    }
    
    // MARK: Promotion Footprint (square count small, identity changes)
    
    @Test func pushPromotionTouchesTwoSquaresButChangesPieceType() {
        let before = position { $0[Squares.e7] = .whitePawn }
        let move = Move.make(
            from: Squares.e7, to: Squares.e8,
            pieceType: .pawn, pieceColor: .white,
            promotionType: .queen
        )
        let after = before.applying(move)
        // Only two squares move, but a pawn lifts and a queen is placed —
        // the tracker can't infer the promoted piece from geometry alone;
        // it reads it from the piece physically placed on e8.
        #expect(changedSquares(before, after) == [Squares.e7, Squares.e8])
        #expect(after[Squares.e8] == .whiteQueen)
        #expect(after[Squares.e8].type != .pawn)
    }
    
    @Test func capturePromotionTouchesFromAndDiagonalTo() {
        let before = position {
            $0[Squares.e7] = .whitePawn
            $0[Squares.f8] = .blackRook
        }
        let move = Move.make(
            from: Squares.e7, to: Squares.f8,
            pieceType: .pawn, pieceColor: .white,
            capturedPieceType: .rook,
            promotionType: .queen
        )
        let after = before.applying(move)
        #expect(changedSquares(before, after) == [Squares.e7, Squares.f8])
        #expect(after[Squares.f8] == .whiteQueen)
    }
    
    // MARK: Coordinate Identity Invariant
    
    /// Reference positions (the perft suite's set) spanning castling, pins,
    /// en passant and dense promotion fan-out.
    private static let referenceFENs: [(name: String, fen: String)] = [
        ("Starting",   FEN.startingString),
        ("Kiwipete",   "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -"),
        ("Position 3", "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -"),
        ("Position 4", "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq -"),
        ("Position 5", "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ -"),
    ]
    
    /// The full identity key the tracker resolves against: from-square,
    /// to-square, and (only ever set for promotions) the promoted type.
    private func identityKey(_ move: Move) -> String {
        "\(move.from)-\(move.to)-\(move.promotionType?.rawValue ?? 0)"
    }
    
    @Test func fromToPromotionUniquelyIdentifiesEveryLegalMove() throws {
        for entry in Self.referenceFENs {
            let state = GameState(try FEN(parsing: entry.fen))
            let moves = state.legalMoves()
            
            var seen: [String: Move] = [:]
            for move in moves {
                let key = identityKey(move)
                #expect(
                    seen[key] == nil,
                    "\(entry.name): two legal moves share (from,to,promotion) key \(key)"
                )
                seen[key] = move
            }
            #expect(seen.count == moves.count)
        }
    }
    
    @Test func onlyPromotionsCauseFromToCollisions() throws {
        // Without the promotion component, (from,to) collisions may exist —
        // but every colliding move must be a promotion. This pins WHY the
        // tracker only needs to ask "which piece?" on the back rank, never
        // elsewhere.
        for entry in Self.referenceFENs {
            let state = GameState(try FEN(parsing: entry.fen))
            let moves = state.legalMoves()
            
            var byFromTo: [String: [Move]] = [:]
            for move in moves {
                byFromTo["\(move.from)-\(move.to)", default: []].append(move)
            }
            
            for (key, group) in byFromTo where group.count > 1 {
                #expect(
                    group.allSatisfy { $0.promotionType != nil },
                    "\(entry.name): (from,to) \(key) collides on non-promotion moves"
                )
            }
        }
    }
    
    @Test func promotionPositionActuallyExercisesTheCollisionPath() throws {
        // Guards the test above against passing vacuously: Position 4 must
        // contain at least one (from,to) pair with all four promotion
        // choices, otherwise "only promotions collide" proves nothing.
        let state = GameState(try FEN(parsing: Self.referenceFENs[3].fen))  // Position 4
        let moves = state.legalMoves()
        
        var byFromTo: [String: Int] = [:]
        for move in moves where move.promotionType != nil {
            byFromTo["\(move.from)-\(move.to)", default: 0] += 1
        }
        #expect(byFromTo.values.contains(4), "Expected a square reachable by all four promotions")
    }
}
