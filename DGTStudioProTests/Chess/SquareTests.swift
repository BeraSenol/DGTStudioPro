import Testing
@testable import DGTStudioPro

/// Coverage for the base `Square` (an `Int`) notation layer - the a1-origin
/// coordinate vocabulary the whole chess core speaks. `SquareDGTFieldTests`
/// already covers the a8↔a1 hardware transform; this suite pins the plain
/// algebraic-notation bijection, the file/rank decomposition, and the
/// `isOnBoard` range check, including rejection of malformed notation (the
/// parser is the boundary `FEN` en-passant parsing relies on).
///
/// Pure value type (`Int`), so the suite is not `@MainActor`. Two tests are
/// full 64-square / 8×8 properties rather than spot checks, since the whole
/// point of a coordinate map is that it holds everywhere, not just at corners.
@Suite("Square")
struct SquareTests {
    
    // MARK: Algebraic-Notation Bijection
    
    /// `algebraicNotation` and `fromAlgebraicNotation` are inverse over the
    /// entire board: every square round-trips through its own name.
    @Test func algebraicNotationRoundTripsForEverySquare() {
        for square in Square.all {
            #expect(
                Square.fromAlgebraicNotation(square.algebraicNotation) == square,
                "round-trip failed for square \(square) (\(square.algebraicNotation))"
            )
        }
    }
    
    /// Spot-checks at the corners and a couple of interior squares, anchoring
    /// the orientation (a1 = 0 bottom-left, h8 = 63 top-right).
    @Test func namedSquaresRenderExpectedNotation() {
        #expect(Squares.a1.algebraicNotation == "a1")
        #expect(Squares.h1.algebraicNotation == "h1")
        #expect(Squares.a8.algebraicNotation == "a8")
        #expect(Squares.h8.algebraicNotation == "h8")
        #expect(Squares.e4.algebraicNotation == "e4")
        #expect(Squares.d6.algebraicNotation == "d6")
    }
    
    @Test func notationParsesToExpectedSquares() {
        #expect(Square.fromAlgebraicNotation("a1") == Squares.a1)
        #expect(Square.fromAlgebraicNotation("h8") == Squares.h8)
        #expect(Square.fromAlgebraicNotation("e4") == Squares.e4)
        #expect(Square.fromAlgebraicNotation("d6") == Squares.d6)
    }
    
    /// The parser is strict: exactly one file letter `a–h` and one rank digit
    /// `1–8`, lowercase, nothing more. Everything else is `nil`.
    @Test func fromAlgebraicNotationRejectsMalformedInput() {
        #expect(Square.fromAlgebraicNotation("") == nil)      // empty
        #expect(Square.fromAlgebraicNotation("a") == nil)     // too short
        #expect(Square.fromAlgebraicNotation("a12") == nil)   // too long
        #expect(Square.fromAlgebraicNotation("e44") == nil)   // too long
        #expect(Square.fromAlgebraicNotation("i1") == nil)    // file past 'h'
        #expect(Square.fromAlgebraicNotation("a9") == nil)    // rank past '8'
        #expect(Square.fromAlgebraicNotation("a0") == nil)    // rank below '1'
        #expect(Square.fromAlgebraicNotation("A1") == nil)    // case-sensitive
        #expect(Square.fromAlgebraicNotation("11") == nil)    // digit as file
        #expect(Square.fromAlgebraicNotation("1a") == nil)    // reversed order
    }
    
    // MARK: File / Rank Decomposition
    
    /// `file` and `rank` decompose a square consistently with `rank * 8 + file`,
    /// across all 64 cells.
    @Test func fileAndRankDecomposeEverySquare() {
        for rank in Square.ranks {
            for file in Square.files {
                let square = rank * 8 + file
                #expect(square.file == file, "file wrong at \(square.algebraicNotation)")
                #expect(square.rank == rank, "rank wrong at \(square.algebraicNotation)")
            }
        }
        // And the inverse holds for every square.
        for square in Square.all {
            #expect(square.rank * 8 + square.file == square)
        }
    }
    
    // MARK: On-Board Range
    
    @Test func isOnBoardMatchesTheValidRange() {
        #expect(Squares.a1.isOnBoard)
        #expect(Squares.h8.isOnBoard)
        for square in Square.all {
            #expect(square.isOnBoard)
        }
        // Just outside the 0..<64 range, in both directions.
        #expect(Square.count.isOnBoard == false)   // 64
        #expect((-1).isOnBoard == false)
    }
    
    // MARK: Structural Constants
    
    @Test func boardConstantsAreEightByEight() {
        #expect(Square.count == 64)
        #expect(Square.all.count == 64)
        #expect(Square.files.count == 8)
        #expect(Square.ranks.count == 8)
    }
}
