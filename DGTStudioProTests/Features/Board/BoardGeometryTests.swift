import Testing
import CoreGraphics
@testable import DGTStudioPro

/// Pins the board arithmetic (M18 Phase 2 - `BoardGeometry`). Nonisolated, and that is
/// load-bearing: the whole point of the extraction is that this arithmetic is a pure function
/// of its arguments, with no view in reach. The mask constants (`56` / `7`) were "checked by
/// nothing but the eye" - the orientation pins below are that check.
@Suite("Board Geometry")
struct BoardGeometryTests {

    // MARK: Orientation

    /// White at the bottom: the top-left visual cell is a8, the bottom-left a1, the bottom
    /// row White's home rank. Four corners plus e1 - distinct squares, so a wrong mask cannot
    /// pass by symmetry.
    @Test func whitePerspectivePutsWhiteAtTheBottom() {
        #expect(BoardGeometry.square(visualRow: 0, visualColumn: 0, perspective: .white) == Squares.a8)
        #expect(BoardGeometry.square(visualRow: 0, visualColumn: 7, perspective: .white) == Squares.h8)
        #expect(BoardGeometry.square(visualRow: 7, visualColumn: 0, perspective: .white) == Squares.a1)
        #expect(BoardGeometry.square(visualRow: 7, visualColumn: 7, perspective: .white) == Squares.h1)
        #expect(BoardGeometry.square(visualRow: 7, visualColumn: 4, perspective: .white) == Squares.e1)
    }

    /// Black at the bottom is a 180° turn, not a mirror: h1 top-left, a8 bottom-right.
    @Test func blackPerspectiveTurnsTheBoardAround() {
        #expect(BoardGeometry.square(visualRow: 0, visualColumn: 0, perspective: .black) == Squares.h1)
        #expect(BoardGeometry.square(visualRow: 0, visualColumn: 7, perspective: .black) == Squares.a1)
        #expect(BoardGeometry.square(visualRow: 7, visualColumn: 0, perspective: .black) == Squares.h8)
        #expect(BoardGeometry.square(visualRow: 7, visualColumn: 7, perspective: .black) == Squares.a8)
        #expect(BoardGeometry.square(visualRow: 0, visualColumn: 3, perspective: .black) == Squares.e1)
    }

    /// The involution, cell by cell: the piece layer reads the inverse of the square grid's
    /// mapping, and every square must come back from its own visual cell - both perspectives,
    /// all 64 squares, and the 64 visual cells must be hit exactly once each.
    @Test(arguments: [PieceColor.white, .black])
    func visualCellInvertsSquareEverywhere(perspective: PieceColor) {
        var seen: Set<Int> = []
        for square in 0..<64 {
            let cell = BoardGeometry.visualCell(of: square, perspective: perspective)
            #expect(
                BoardGeometry.square(
                    visualRow: cell.row, visualColumn: cell.column, perspective: perspective
                ) == square
            )
            seen.insert(cell.row * 8 + cell.column)
        }
        #expect(seen.count == 64)
    }

    /// The coordinate strips derive from the same mapping: the file labels run a→h for White
    /// and h→a for Black; the rank labels run 8→1 for White and 1→8 for Black.
    @Test func stripDerivationsFollowTheMask() {
        #expect((0..<8).map { BoardGeometry.file(atVisualColumn: $0, perspective: .white) } == [0, 1, 2, 3, 4, 5, 6, 7])
        #expect((0..<8).map { BoardGeometry.file(atVisualColumn: $0, perspective: .black) } == [7, 6, 5, 4, 3, 2, 1, 0])
        #expect((0..<8).map { BoardGeometry.rank(atVisualRow: $0, perspective: .white) } == [7, 6, 5, 4, 3, 2, 1, 0])
        #expect((0..<8).map { BoardGeometry.rank(atVisualRow: $0, perspective: .black) } == [0, 1, 2, 3, 4, 5, 6, 7])
    }

    // MARK: Layout

    /// Leather is the exact case: no grid border, so the inner square is the frame square.
    @Test func leatherLayoutHasNoInset() {
        let layout = BoardGeometry.layout(totalSide: 500, style: .leather)
        #expect(layout.squareSize == 50)
        #expect(layout.borderInset == 0)
        #expect(layout.innerSquareSize == 50)
    }

    /// Conservation, every style: the eight inner squares plus both insets refill the eight
    /// frame squares exactly - the property that keeps the playing surface inside the frame.
    @Test(arguments: BoardStyle.allCases)
    func gridPlusBorderFillsEightSquares(style: BoardStyle) {
        let layout = BoardGeometry.layout(totalSide: 500, style: style)
        let refilled = 8 * layout.innerSquareSize + 2 * layout.borderInset
        #expect(abs(refilled - 8 * layout.squareSize) < 1e-9)
        #expect(layout.borderInset >= 0)
        #expect(layout.innerSquareSize <= layout.squareSize)
    }

    /// Rosewood's deliberate fifteenth: the inset is `thin * 24/15`, not the `thin * 25/15`
    /// a well-meaning simplification to `5/3` would produce - the declaration says the
    /// subtraction is load-bearing, and this is that sentence as a failure.
    @Test func rosewoodInsetKeepsItsFifteenth() {
        let squareSize: CGFloat = 56  // thin = 2, exact
        let inset = BoardGeometry.gridBorderInset(squareSize: squareSize, style: .rosewood)
        #expect(abs(inset - 2 * 24 / 15) < 1e-9)
    }
}
