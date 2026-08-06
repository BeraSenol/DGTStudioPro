import SwiftUI

internal struct SquareView: View {
    
    // MARK: Stored Properties
    
    /// The square's physical occupant — retained for *gating*, not drawing,
    /// since M6: the piece itself renders in `BoardPieceLayer` above this
    /// grid, and the square's one remaining occupancy question is whether
    /// the ghost below may show.
    ///
    /// `pieceID` was retired here in the same change. It had been threaded,
    /// unread, since the tracker landed — the "intended consumer" was
    /// identity-keyed animation, and when that arrived (M6) it keyed the
    /// layer's `ForEach` on `ResolvedPiece.key` instead, because a square
    /// that knows its piece's identity still can't glide anything: gliding
    /// is a relationship between two squares, and only a layer sees both.
    internal let piece: Piece
    internal let isLightSquare: Bool
    internal let highlight: SquareHighlight
    internal let squareSize: CGFloat
    internal let style: BoardStyle
    /// Optional ghost piece to render at 50% opacity *when the square is empty*
    /// — the mid-castle "rook hasn't moved yet" cue from `DGTLiveSession`. The
    /// square stays ignorant of castling semantics: it renders whatever
    /// `Piece` it's handed, ghost or not. Defaults to nil so existing call
    /// sites compile unchanged.
    internal var ghostPiece: Piece? = nil
    
    // MARK: Computed Properties
    private var fillColor: Color {
        isLightSquare ? style.light : style.dark
    }
    
    // MARK: Body
    internal var body: some View {
        ZStack {
            Rectangle()
                .fill(fillColor)
            
            // Highlight *fills* sit under the piece; *strokes* are added
            // after the piece image below, so borders are never occluded.
            // Check paints over last-move when both apply — the king in
            // danger outranks "this just moved".
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
                // Ghost only draws on an empty square — once the real piece
                // lands, `BoardPieceLayer` renders it above this square and
                // the ghost yields. `PieceGlyph` keeps the ghost
                // pixel-identical to the piece it foreshadows.
                PieceGlyph(piece: ghostPiece, squareSize: squareSize)
                    .opacity(0.5)
            }
            
            // Pre-wiring: nothing in the running app sets `.selected`, because
            // `BoardView.selectedSquare` takes its default at every call site
            // (the physical board is the input). This arm is therefore
            // unreachable outside the preview below, which passes the option
            // directly — recorded 6 Aug 2026 (M12.3) rather than left for the
            // next reader to work out from two files. Kept because a
            // click-to-move or position-setup surface needs exactly this and
            // would have to pass a value and nothing more.
            if highlight.contains(.selected) {
                Rectangle().strokeBorder(
                    Color.accentColor,
                    lineWidth: max(2, squareSize * 0.05)
                )
            }
            if highlight.contains(.attention) {
                // Solid red border: "fix this square" (remove / swap).
                Rectangle().strokeBorder(
                    .red,
                    lineWidth: max(2, squareSize * 0.05)
                )
            }
            if highlight.contains(.target) {
                // Dashed green border: "a piece belongs here" — reads as a
                // drop target without claiming anything is wrong.
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

// The square's remaining subjects since piece drawing moved to
// `BoardPieceLayer` (M6): fills and highlight chrome. The glyph set and its
// size scaling preview with the layer, where the drawing code now lives.
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
        // `.selected` is **pre-wiring, not a state the app can enter** — see
        // the body above. It renders here and nowhere else, and that is worth
        // labelling rather than leaving to be inferred: D51′ records that a
        // preview witnessing an arrangement the app does not have reads as
        // evidence the arrangement is still checked. Same hazard, opposite
        // cause — that one had been retired, this one has never been reached.
        // The tint is kept on canvas so a future click-to-move surface starts
        // from a style someone has actually looked at.
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

// Ghost across the four styles, plus the gating case: the occupied middle
// square draws no ghost. In the app the real piece renders above it in the
// layer — what this bare square shows is the absence that makes room.
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
