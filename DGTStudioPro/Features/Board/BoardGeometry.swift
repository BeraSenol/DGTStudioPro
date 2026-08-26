import CoreGraphics

/// The board's arithmetic, extracted pure (M18 Phase 2 - the `EvaluationGraphReading`
/// precedent): every number `BoardView` and `BoardPieceLayer` derive rather than draw.
///
/// **The perspective flip lives here and nowhere else.** It was spelled four times - the
/// square grid's XOR, the piece layer's inverse (same involutive mask, two literals in two
/// files), and the two coordinate strips' ternaries - agreeing across all 128 cells with
/// nothing checking that they still would. Now the strips *derive* from the square mapping
/// and the layer reads the inverse from the same mask, so disagreement is unrepresentable
/// rather than unobserved. `BoardGeometryTests` pins the involution and the derivations
/// cell-by-cell anyway, because the mask constant itself (`56` / `7`) is a correctness claim
/// no compiler checks.
enum BoardGeometry {

    // MARK: Layout

    /// The three lengths the 10×10 frame-and-grid layout hands every subview.
    struct Layout: Equatable {
        let squareSize: CGFloat
        let borderInset: CGFloat
        let innerSquareSize: CGFloat
    }

    /// Frame thickness is one square of the 10×10; the grid border eats into the eight
    /// playing squares, so the inner square is what remains after the inset, split eight ways.
    static func layout(totalSide: CGFloat, style: BoardStyle) -> Layout {
        let squareSize = totalSide / 10
        let borderInset = gridBorderInset(squareSize: squareSize, style: style)
        return Layout(
            squareSize: squareSize,
            borderInset: borderInset,
            innerSquareSize: (8 * squareSize - 2 * borderInset) / 8
        )
    }

    /// **Must equal what `BoardView.gridBorder` actually draws**, or the playing surface
    /// starts somewhere other than where the frame ends. Walnut and wenge match their strokes
    /// exactly; rosewood's three sum to `thin * 5/3` and this returns a fifteenth less on
    /// purpose - which is why the expression stays a subtraction. Simplifying it to
    /// `thin * 5/3` moves the board.
    static func gridBorderInset(squareSize: CGFloat, style: BoardStyle) -> CGFloat {
        let thin = squareSize / 28
        switch style {
        case .leather:  return 0
        case .walnut:   return thin * 19 / 15
        case .rosewood: return thin * 5 / 3 - thin / 15
        case .wenge:    return thin * 3 / 2
        }
    }

    // MARK: Perspective

    /// XOR the rank bits for White (`56`), the file bits for Black (`7`). Involutive, so the
    /// same mask maps both directions.
    private static func mask(_ perspective: PieceColor) -> Int {
        perspective == .white ? 56 : 7
    }

    /// Visual cell → board square (the square grid's direction).
    static func square(visualRow: Int, visualColumn: Int, perspective: PieceColor) -> Square {
        (visualRow * 8 + visualColumn) ^ mask(perspective)
    }

    /// Board square → visual cell (the piece layer's direction - the involution read back).
    static func visualCell(of square: Square, perspective: PieceColor) -> (row: Int, column: Int) {
        let visual = square ^ mask(perspective)
        return (visual / 8, visual % 8)
    }

    /// The file a coordinate strip labels at a visual column - derived from the square
    /// mapping, not restated beside it.
    static func file(atVisualColumn visualColumn: Int, perspective: PieceColor) -> Int {
        square(visualRow: 0, visualColumn: visualColumn, perspective: perspective).file
    }

    /// The rank a coordinate strip labels at a visual row - same derivation.
    static func rank(atVisualRow visualRow: Int, perspective: PieceColor) -> Int {
        square(visualRow: visualRow, visualColumn: 0, perspective: perspective).rank
    }
}
