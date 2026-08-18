import Testing
@testable import DGTStudioPro

@Suite("Position Attack Detection")
struct PositionAttackTests {

    // Position construction (`Position.make`) lives in
    // Support/ChessTestSupport.swift, shared across the chess-core suites.

    // MARK: Pawn Attacks
    @Test func whitePawnAttacksUpDiagonals() {
        let pos = Position.make { $0[Squares.e4] = .whitePawn }

        #expect(pos.isSquareAttacked(Squares.d5, by: .white))
        #expect(pos.isSquareAttacked(Squares.f5, by: .white))
        // Pawns do NOT attack forward
        #expect(!pos.isSquareAttacked(Squares.e5, by: .white))
        // Pawns do NOT attack backward
        #expect(!pos.isSquareAttacked(Squares.d3, by: .white))
        #expect(!pos.isSquareAttacked(Squares.f3, by: .white))
    }

    @Test func blackPawnAttacksDownDiagonals() {
        let pos = Position.make { $0[Squares.e5] = .blackPawn }

        #expect(pos.isSquareAttacked(Squares.d4, by: .black))
        #expect(pos.isSquareAttacked(Squares.f4, by: .black))
        #expect(!pos.isSquareAttacked(Squares.e4, by: .black))
        #expect(!pos.isSquareAttacked(Squares.d6, by: .black))
    }

    /// The offsets are stated from the **attacked** square, running backwards to where a pawn would
    /// have to stand - the convention `SpecialCheckmate` also reads, and the reason the pair moved
    /// onto `Square` (18 Aug 2026) instead of being spelled at both sites.
    ///
    /// Asserted against the scanner rather than against the literals `[-7, -9]`: a pinned literal
    /// would keep passing while the constant and its one consumer quietly disagreed.
    @Test func pawnAttackOriginsRunBackwardsFromTheAttackedSquare() {
        for (color, target) in [(PieceColor.white, Squares.d5), (.black, Squares.d4)] {
            for offset in Square.pawnAttackOrigins(of: color) {
                let origin = target + offset
                let pos = Position.make { $0[origin] = Piece(color, .pawn) }
                #expect(pos.isSquareAttacked(target, by: color))
            }
        }
    }

    @Test func pawnAttackDoesNotWraparound() {
        let pos = Position.make { $0[Squares.a4] = .whitePawn }
        // h5 is not attacked despite a4 - 9 = h2 arithmetic; file diff catches the wrap.
        #expect(!pos.isSquareAttacked(Squares.h5, by: .white))
        // Legitimate attack: b5
        #expect(pos.isSquareAttacked(Squares.b5, by: .white))
    }

    // MARK: Knight Attacks
    @Test func knightAttacksAllEightSquares() {
        let pos = Position.make { $0[Squares.d4] = .whiteKnight }

        let attacked: [Square] = [
            Squares.b3, Squares.b5, Squares.c2, Squares.c6,
            Squares.e2, Squares.e6, Squares.f3, Squares.f5
        ]
        for sq in attacked {
            #expect(pos.isSquareAttacked(sq, by: .white), "expected \(sq.algebraicNotation) attacked")
        }
    }

    @Test func knightAttackDoesNotWraparound() {
        let pos = Position.make { $0[Squares.a1] = .whiteKnight }
        // Wraparound bait: file-7 squares should not be reported as attacked
        #expect(!pos.isSquareAttacked(Squares.h2, by: .white))
        #expect(!pos.isSquareAttacked(Squares.g1, by: .white))
        // Legitimate: b3, c2
        #expect(pos.isSquareAttacked(Squares.b3, by: .white))
        #expect(pos.isSquareAttacked(Squares.c2, by: .white))
    }

    // MARK: King Attacks
    @Test func kingAttacksAllEightNeighbors() {
        let pos = Position.make { $0[Squares.d4] = .whiteKing }

        let attacked: [Square] = [
            Squares.c3, Squares.c4, Squares.c5,
            Squares.d3,             Squares.d5,
            Squares.e3, Squares.e4, Squares.e5
        ]
        for sq in attacked {
            #expect(pos.isSquareAttacked(sq, by: .white))
        }
        // Two squares away: not attacked
        #expect(!pos.isSquareAttacked(Squares.d6, by: .white))
        #expect(!pos.isSquareAttacked(Squares.f4, by: .white))
    }

    @Test func kingAttackDoesNotWraparound() {
        let pos = Position.make { $0[Squares.a4] = .whiteKing }
        #expect(!pos.isSquareAttacked(Squares.h3, by: .white))
        #expect(!pos.isSquareAttacked(Squares.h4, by: .white))
        #expect(!pos.isSquareAttacked(Squares.h5, by: .white))
    }

    // MARK: Sliding Attacks - Rook
    @Test func rookAttacksAlongRankAndFile() {
        let pos = Position.make { $0[Squares.d4] = .whiteRook }

        #expect(pos.isSquareAttacked(Squares.d8, by: .white))
        #expect(pos.isSquareAttacked(Squares.d1, by: .white))
        #expect(pos.isSquareAttacked(Squares.a4, by: .white))
        #expect(pos.isSquareAttacked(Squares.h4, by: .white))
        // Diagonal: not attacked by rook
        #expect(!pos.isSquareAttacked(Squares.e5, by: .white))
    }

    @Test func rookAttackBlockedByPiece() {
        let pos = Position.make {
            $0[Squares.d4] = .whiteRook
            $0[Squares.d6] = .whitePawn  // blocks the rook's reach past d6
        }
        // d5: in front of the blocker, attacked
        #expect(pos.isSquareAttacked(Squares.d5, by: .white))
        // d6: the blocker itself - still attacked by the rook (a piece "attacks"
        // its own defended squares; the ray hits the friendly piece first and
        // that piece IS on a square the rook attacks).
        #expect(pos.isSquareAttacked(Squares.d6, by: .white))
        // d7 / d8: behind the blocker, unattacked (ray stops at the friendly pawn)
        #expect(!pos.isSquareAttacked(Squares.d7, by: .white))
        #expect(!pos.isSquareAttacked(Squares.d8, by: .white))
    }

    @Test func rookAttackBlockedByEnemyNonSlider() {
        let pos = Position.make {
            $0[Squares.d4] = .whiteRook
            $0[Squares.d6] = .blackKnight
        }
        // d6 itself: attacked (capturable)
        #expect(pos.isSquareAttacked(Squares.d6, by: .white))
        // d7: knight blocks the ray, so not attacked
        #expect(!pos.isSquareAttacked(Squares.d7, by: .white))
    }

    @Test func rookAttackDoesNotWraparoundAlongRank() {
        let pos = Position.make { $0[Squares.h1] = .whiteRook }
        // h1+1 wraps to a2 if file check fails
        #expect(!pos.isSquareAttacked(Squares.a2, by: .white))
        // Legitimate: g1 along rank 1
        #expect(pos.isSquareAttacked(Squares.g1, by: .white))
    }

    // MARK: Sliding Attacks - Bishop
    @Test func bishopAttacksAlongDiagonals() {
        let pos = Position.make { $0[Squares.d4] = .whiteBishop }

        #expect(pos.isSquareAttacked(Squares.h8, by: .white))
        #expect(pos.isSquareAttacked(Squares.a1, by: .white))
        #expect(pos.isSquareAttacked(Squares.a7, by: .white))
        #expect(pos.isSquareAttacked(Squares.g1, by: .white))
        // Orthogonal: not attacked by bishop
        #expect(!pos.isSquareAttacked(Squares.d8, by: .white))
        #expect(!pos.isSquareAttacked(Squares.h4, by: .white))
    }

    @Test func bishopAttackBlocked() {
        let pos = Position.make {
            $0[Squares.d4] = .whiteBishop
            // Knight (not pawn!) as blocker: a pawn on f6 would itself attack g7,
            // confounding the test. The knight on f6 jumps to d5/d7/e4/e8/g4/g8/h5/h7
            // - none of which are the test squares - so it blocks cleanly.
            $0[Squares.f6] = .whiteKnight
        }
        #expect(!pos.isSquareAttacked(Squares.g7, by: .white))
        #expect(!pos.isSquareAttacked(Squares.h8, by: .white))
        #expect(pos.isSquareAttacked(Squares.e5, by: .white))
    }

    // MARK: Sliding Attacks - Queen
    @Test func queenAttacksOrthogonalAndDiagonal() {
        let pos = Position.make { $0[Squares.d4] = .whiteQueen }

        #expect(pos.isSquareAttacked(Squares.d8, by: .white))   // file
        #expect(pos.isSquareAttacked(Squares.h4, by: .white))   // rank
        #expect(pos.isSquareAttacked(Squares.h8, by: .white))   // diagonal
        #expect(pos.isSquareAttacked(Squares.a1, by: .white))   // diagonal
        // Knight-jump squares (not queen lines): unattacked
        #expect(!pos.isSquareAttacked(Squares.f5, by: .white))
        #expect(!pos.isSquareAttacked(Squares.e6, by: .white))
    }

    // MARK: Color Discrimination
    @Test func attackerColorIsRespected() {
        let pos = Position.make { $0[Squares.d4] = .whiteRook }
        // d8 is attacked by white but NOT by black (no black piece exists)
        #expect(pos.isSquareAttacked(Squares.d8, by: .white))
        #expect(!pos.isSquareAttacked(Squares.d8, by: .black))
    }

    @Test func emptyBoardHasNoAttacks() {
        let pos = Position.empty
        #expect(!pos.isSquareAttacked(Squares.e4, by: .white))
        #expect(!pos.isSquareAttacked(Squares.e4, by: .black))
    }

    // MARK: Real-World Sanity
    @Test func startingPositionAttackProfile() {
        let pos = Position.starting
        // White attacks rank 3 squares via pawns (b3, c3, d3, ..., g3)
        // and via knights from b1/g1 (a3, c3, f3, h3)
        #expect(pos.isSquareAttacked(Squares.a3, by: .white))   // knight from b1
        #expect(pos.isSquareAttacked(Squares.c3, by: .white))   // knight b1 + pawns b2/d2
        #expect(pos.isSquareAttacked(Squares.f3, by: .white))   // knight g1 + pawns e2/g2
        // Black mirror: rank 6 attacked by black
        #expect(pos.isSquareAttacked(Squares.a6, by: .black))
        #expect(pos.isSquareAttacked(Squares.c6, by: .black))
        // a1 (white rook's own square) isn't attacked by any other white piece:
        // the rook doesn't attack itself, the knight on b1 doesn't jump to a1,
        // and nothing along the diagonals reaches a1 either.
        // (Note: e1 IS attacked by white - the queen on d1 sees it along rank 1.)
        #expect(!pos.isSquareAttacked(Squares.a1, by: .white))
        // White's e4/e5: e4 not attacked by either side; e5 not attacked by white pawns
        #expect(!pos.isSquareAttacked(Squares.e4, by: .white))
        #expect(!pos.isSquareAttacked(Squares.e4, by: .black))
    }
}
