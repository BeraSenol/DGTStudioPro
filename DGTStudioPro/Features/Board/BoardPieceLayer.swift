import SwiftUI

/// One piece, drawn - glyph, aspect fit, 6% breathing room, stated once. Shared by the layer
/// and the mid-castle ghost, which must be pixel-identical to the piece it foreshadows.
///
/// Draws **nothing** for a piece with no `imageName`, silently. Unreachable in practice: the layer's
/// input skips unoccupied squares and the ghost is always a real king or rook, so the only way in is
/// a `Piece` built from a raw value outside 1-6 and 9-14.
struct PieceGlyph: View {
    
    // MARK: Stored Properties
    let piece: Piece
    let squareSize: CGFloat
    
    // MARK: Body
    var body: some View {
        if let imageName = piece.imageName {
            Image(imageName)
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .padding(squareSize * 0.06)
                .frame(width: squareSize, height: squareSize)
        }
    }
}

/// M6 - every piece in one identity-keyed layer above the squares. Not
/// `matchedGeometryEffect`: MGE has no vocabulary for "this change must not animate", which the
/// board-dump case needs - identity churn expresses it free (a dump re-keys wholesale, so 32
/// pieces fade rather than fly). Reduce Motion drops the animation, not the layer.
struct BoardPieceLayer: View {
    
    // MARK: Static Constants
    
    /// Glide guardrails and default (user preference). 0.22 s is the shipped feel; the range
    /// deliberately passes the 300 ms quiescence - above it a glide can still be in flight at the
    /// settle. Visual only: the animation retargets mid-flight, nothing about commit timing reads it.
    nonisolated static let durationRange: ClosedRange<Double> = 0.1...1.0
    nonisolated static let defaultDuration: Double = 0.22
    
    /// Hand-rolled, though `Comparable.clamped(to:)` is in scope and does exactly this - the
    /// difference is that this one is a *named, pinned* entry point (`BoardPieceLayerTests` asserts
    /// eight values through it, `.infinity` included). Swapping the body for `raw.clamped(to:)`
    /// keeps every one of them.
    nonisolated static func clampedDuration(_ raw: Double) -> Double {
        min(max(raw, durationRange.lowerBound), durationRange.upperBound)
    }
    
    /// The glide at an already-clamped duration - `.snappy` stays the curve.
    static func glide(duration: Double) -> Animation {
        .snappy(duration: duration)
    }
    
    // MARK: Stored Properties
    let pieces: [ResolvedPiece]
    let squareSize: CGFloat
    let perspective: PieceColor
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    /// Read here because the layer is the duration's one consumer; Settings binds the same key,
    /// both defaults spelled off `BoardPieceLayer.defaultDuration`.
    @AppStorage(StorageKeys.pieceAnimationDuration)
    private var animationDuration = BoardPieceLayer.defaultDuration
    
    // MARK: Body
    var body: some View {
        ZStack {
            ForEach(pieces) { resolved in
                PieceGlyph(piece: resolved.piece, squareSize: squareSize)
                    .position(center(of: resolved.square))
                    .transition(.opacity)
            }
        }
        .frame(width: squareSize * 8, height: squareSize * 8)
        .animation(
            reduceMotion ? nil : Self.glide(duration: Self.clampedDuration(animationDuration)),
            value: pieces
        )
        .allowsHitTesting(false)
    }
    
    // MARK: Instance Methods
    
    /// The inverse of `BoardView.square(visualRow:visualColumn:)` - involutive XOR, so a flip moves
    /// every cell and the layer follows without a second rule.
    ///
    /// **The mask itself is spelled twice**, here and at `BoardView:206`, in two files. Same rule,
    /// two literals: change one and squares and pieces disagree about which end of the board is
    /// which - pieces render on the wrong squares, visibly, but only at runtime.
    private func center(of square: Square) -> CGPoint {
        let visual = square ^ (perspective == .white ? 56 : 7)
        let row = visual / 8
        let column = visual % 8
        return CGPoint(
            x: (CGFloat(column) + 0.5) * squareSize,
            y: (CGFloat(row) + 0.5) * squareSize
        )
    }
}

// MARK: Previews

/// The full asset set at the layer's own rendering - a preview lives with the code it witnesses.
#Preview("All Pieces") {
    let pieces: [Piece] = [
        .whitePawn, .whiteKnight, .whiteBishop, .whiteRook, .whiteQueen, .whiteKing,
        .blackPawn, .blackKnight, .blackBishop, .blackRook, .blackQueen, .blackKing
    ]
    return VStack(spacing: 0) {
        ForEach(0..<2, id: \.self) { row in
            HStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { column in
                    PieceGlyph(piece: pieces[row * 6 + column], squareSize: 70)
                        .background((row + column) % 2 == 0
                                    ? BoardStyle.wenge.light
                                    : BoardStyle.wenge.dark)
                }
            }
        }
    }
    .padding()
}

/// The 6% padding at three sizes - the scaling contract.
#Preview("Size Scaling") {
    HStack(alignment: .bottom, spacing: 8) {
        ForEach([40, 80, 120] as [CGFloat], id: \.self) { size in
            PieceGlyph(piece: .whiteQueen, squareSize: size)
                .background(BoardStyle.rosewood.dark)
        }
    }
    .padding()
}

/// M6's gate, watchable: e4, the en-passant capture, the promotion morph, and O-O, stepped by
/// hand through `LibraryGamePreviewState.compute` - exactly what the review board renders.
#Preview("Four Shapes, Interactive") {
    @Previewable @State var plyCount = 0
    let script = [
        "e4", "d5", "e5", "f5", "exf6", "Nh6", "fxg7", "Nc6",
        "gxh8=Q", "e5", "Bc4", "Bd6", "Nf3", "d4", "O-O"
    ]
    let state = LibraryGamePreviewState.compute(from: Array(script.prefix(plyCount)))
    
    return VStack(spacing: 12) {
        BoardView(
            position: state.position,
            pieces: PieceIdentity.resolved(
                position: state.position,
                tracker: state.pieceTracker
            ),
            style: .walnut,
            perspective: .white,
            lastMove: state.lastMove,
            checkSquare: state.checkSquare
        )
        HStack {
            Button("Reset") { plyCount = 0 }
                .disabled(plyCount == 0)
            Button("Back") { plyCount = max(0, plyCount - 1) }
                .disabled(plyCount == 0)
            Button("Next") { plyCount = min(script.count, plyCount + 1) }
                .disabled(plyCount == script.count)
            Text(plyCount == 0 ? "start" : "\(plyCount): \(script[plyCount - 1])")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom)
    }
    .frame(width: 560, height: 640)
}
