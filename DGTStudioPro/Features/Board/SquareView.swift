import SwiftUI

struct SquareView: View {
    
    // MARK: Stored Properties
    
    /// The physical occupant - retained for *gating*, not drawing, since M6: the piece renders in
    /// `BoardPieceLayer` (gliding is a relationship between two squares; only a layer sees both).
    let piece: Piece
    let isLightSquare: Bool
    let highlight: SquareHighlight
    let squareSize: CGFloat
    let style: BoardStyle
    /// Ghost at 25% when the square is empty - the mid-castle rook and a lifted piece's
    /// stand-in alike (one opacity for every ghost, 17 Aug 2026 by request; a per-kind
    /// opacity parameter lived here for an hour and died when the kinds stopped differing).
    /// The square stays ignorant of which ghost it draws.
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
            
            // Highlight *fills* under the piece, *strokes* after it; check paints over last-move - the king
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
                    .opacity(0.25)
            }

            // Legal-destination hint: dot on an empty square, ring around an occupied one (a
            // capture) - the ring survives visually because the piece layer's glyphs carry 6%
            // padding. Fixed black rather than `.primary`: the board's colours are
            // appearance-independent assets, so the hint must not flip with the system appearance.
            if highlight.contains(.hint) {
                if piece.isOccupied {
                    Circle()
                        .strokeBorder(.black.opacity(0.2), lineWidth: squareSize * 0.07)
                        .padding(squareSize * 0.03)
                } else {
                    Circle()
                        .fill(.black.opacity(0.2))
                        .frame(width: squareSize * 0.3, height: squareSize * 0.3)
                }
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
                // Dashed green border: "a piece belongs here" - a drop target, not an error.
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
        // `.selected` is pre-wiring, not a state the app can enter - labelled so the preview doesn't
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

// Ghost across the four styles; the occupied middle square draws no ghost - the absence that
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

// The hint's two renderings: dot on empty (both fills), ring around an occupied square (a
// capture) - the defect this guards is visual: a dot that reads as a piece, or a ring the
// glyph swallows.
#Preview("Move Hints") {
    HStack(spacing: 4) {
        SquareView(
            piece: .empty, isLightSquare: true,
            highlight: .hint, squareSize: 80, style: .walnut
        )
        SquareView(
            piece: .empty, isLightSquare: false,
            highlight: .hint, squareSize: 80, style: .walnut
        )
        SquareView(
            piece: .blackPawn, isLightSquare: true,
            highlight: .hint, squareSize: 80, style: .walnut
        )
        SquareView(
            piece: .empty, isLightSquare: false,
            highlight: [.hint, .lastMove], squareSize: 80, style: .walnut
        )
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
