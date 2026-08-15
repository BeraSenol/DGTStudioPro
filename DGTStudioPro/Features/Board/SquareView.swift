import SwiftUI

struct SquareView: View {
    
    // MARK: Stored Properties
    
    /// The physical occupant — retained for *gating*, not drawing, since M6: the piece renders in
    /// `BoardPieceLayer` (gliding is a relationship between two squares; only a layer sees both).
    let piece: Piece
    let isLightSquare: Bool
    let highlight: SquareHighlight
    let squareSize: CGFloat
    let style: BoardStyle
    /// Ghost at 50% when the square is empty — the square stays ignorant of castling semantics.
    var ghostPiece: Piece? = nil
    
    // MARK: Computed Properties
    private var fillColor: Color {
        isLightSquare ? style.light : style.dark
    }
    
    // MARK: Body
    var body: some View {
        ZStack {
            Rectangle()
                .fill(fillColor)
            
            // Highlight *fills* under the piece, *strokes* after it; check paints over last-move — the king
            // in danger outranks "this just moved".
            if highlight.contains(.lastMove) {
                Rectangle().fill(.yellow.opacity(0.35))
            }
            if highlight.contains(.check) {
                Rectangle().fill(.red.opacity(0.40))
            }
            if highlight.contains(.attention) {
                Rectangle().fill(.red.opacity(0.22))
            }
            
            if !piece.isOccupied, let ghostPiece {
                // Ghost only on an empty square; `PieceGlyph` keeps it pixel-identical to the piece it foreshadows.
                PieceGlyph(piece: ghostPiece, squareSize: squareSize)
                    .opacity(0.5)
            }
            
            // Pre-wiring: nothing sets `.selected` (the physical board is the input); a click-to-move
            // surface needs exactly this.
            if highlight.contains(.selected) {
                Rectangle().strokeBorder(
                    Color.accentColor,
                    lineWidth: max(2, squareSize * 0.05)
                )
            }
            if highlight.contains(.attention) {
                // Solid red border: "fix this square".
                Rectangle().strokeBorder(
                    .red,
                    lineWidth: max(2, squareSize * 0.05)
                )
            }
            if highlight.contains(.target) {
                // Dashed green border: "a piece belongs here" — a drop target, not an error.
                Rectangle().strokeBorder(
                    Color.accentColor,
                    style: StrokeStyle(
                        lineWidth: max(2, squareSize * 0.05),
                        dash: [squareSize * 0.1]
                    )
                )
            }
        }
        .frame(width: squareSize, height: squareSize)
    }
}

// MARK: Previews

// The square's remaining subjects since M6: fills and highlight chrome.
#Preview("Highlight States") {
    HStack(spacing: 4) {
        SquareView(
            piece: .empty, isLightSquare: true,
            highlight: SquareHighlight(), squareSize: 80, style: .walnut
        )
        SquareView(
            piece: .empty, isLightSquare: false,
            highlight: SquareHighlight(), squareSize: 80, style: .walnut
        )
        SquareView(
            piece: .empty, isLightSquare: true,
            highlight: .lastMove, squareSize: 80, style: .walnut
        )
        SquareView(
            piece: .empty, isLightSquare: true,
            highlight: .check, squareSize: 80, style: .walnut
        )
        // `.selected` is pre-wiring, not a state the app can enter — labelled so the preview doesn't
        // read as evidence of a live arrangement.
        SquareView(
            piece: .empty, isLightSquare: true,
            highlight: .selected, squareSize: 80, style: .walnut
        )
        SquareView(
            piece: .empty, isLightSquare: true,
            highlight: [.check, .lastMove], squareSize: 80, style: .walnut
        )
        SquareView(
            piece: .empty, isLightSquare: true,
            highlight: .attention, squareSize: 80, style: .walnut
        )
        SquareView(
            piece: .empty, isLightSquare: true,
            highlight: .target, squareSize: 80, style: .walnut
        )
    }
    .padding()
}

// Ghost across the four styles; the occupied middle square draws no ghost — the absence that
// makes room.
#Preview("Castling Ghost") {
    VStack(spacing: 0) {
        ForEach(BoardStyle.allCases, id: \.self) { style in
            HStack(spacing: 0) {
                SquareView(
                    piece: .empty, isLightSquare: true,
                    highlight: SquareHighlight(),
                    squareSize: 80, style: style,
                    ghostPiece: .whiteRook
                )
                SquareView(
                    piece: .whiteRook, isLightSquare: false,
                    highlight: SquareHighlight(),
                    squareSize: 80, style: style,
                    ghostPiece: .whiteRook
                )
                SquareView(
                    piece: .empty, isLightSquare: false,
                    highlight: SquareHighlight(),
                    squareSize: 80, style: style,
                    ghostPiece: .blackRook
                )
            }
        }
    }
    .padding()
}

// The four styles' fills, light and dark.
#Preview("All Styles") {
    HStack(spacing: 4) {
        ForEach(BoardStyle.allCases, id: \.self) { style in
            VStack(spacing: 0) {
                SquareView(
                    piece: .empty, isLightSquare: true,
                    highlight: SquareHighlight(), squareSize: 80, style: style
                )
                SquareView(
                    piece: .empty, isLightSquare: false,
                    highlight: SquareHighlight(), squareSize: 80, style: style
                )
            }
        }
    }
    .padding()
}
