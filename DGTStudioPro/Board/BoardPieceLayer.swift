//
//  BoardPieceLayer.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 02/08/2026.
//

import SwiftUI

/// One piece, drawn — the glyph, its aspect fit, and the 6% breathing room,
/// stated once.
///
/// Shared by the layer (real pieces) and `SquareView` (the mid-castle ghost),
/// because the ghost must be pixel-identical to the piece it foreshadows and
/// the 0.06 padding lived one refactor away from becoming a twin the moment
/// piece drawing moved out of the square.
internal struct PieceGlyph: View {

    // MARK: Stored Properties
    internal let piece: Piece
    internal let squareSize: CGFloat

    // MARK: Body
    internal var body: some View {
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

/// M6 — every piece on the board, rendered in one identity-keyed layer above
/// the square grid.
///
/// The squares stopped drawing pieces when this landed: a square can only
/// pop its content into existence, while a layer whose `ForEach` keys on
/// `ResolvedPiece.key` gets the whole animation contract from identity
/// alone — a persisting key whose square changes **glides**, a key that
/// appears or vanishes **fades**. No case analysis, no animation flags: the
/// resolver decides who persists (`PieceIdentity`), and this view merely
/// obeys. A board dump re-keys everything and therefore fades; a proven move
/// keeps its key and therefore glides; a lifted piece loses its square and
/// therefore fades out where it stood, which is the truthful rendering of a
/// piece in a hand.
///
/// `matchedGeometryEffect` was the rejected mechanism: it pairs an insertion
/// with a removal across two views, which means threading a namespace
/// through 64 square cells and trusting the pairing to fire inside a clipped,
/// overlaid grid — and it has no vocabulary for "this change must not
/// animate", which the dump case needs and identity churn expresses for
/// free.
///
/// Geometry: the layer frames itself to the grid's exact side (8 squares)
/// and converts each square to its visual cell with the same XOR
/// `BoardView.square(visualRow:visualColumn:)` uses in the other direction —
/// one mask, two directions, so the layer and the grid cannot disagree about
/// where e4 is. Hit testing stays off: squares own interaction (they keep
/// the accessibility identifiers too).
///
/// Reduce Motion honours the system setting by dropping the animation, not
/// the layer: positions still update, nothing slides.
internal struct BoardPieceLayer: View {

    // MARK: Static Constants

    /// The glide duration's guardrails and default — a user preference
    /// since 2 Aug 2026, replacing the fixed `glide` constant. 0.22 s is
    /// the shipped feel: quick enough to read as the piece landing, slow
    /// enough to read as motion. The range is the chosen envelope
    /// (0.1–1 s), clamped on every read — the `EngineConfiguration`
    /// stance: the slider can't leave the range, and a hand-edited
    /// default gets repaired rather than obeyed.
    ///
    /// One sentence the old constant's doc carried no longer always
    /// holds: above 0.3 s a glide can still be in flight when the
    /// session's 300 ms quiescence settles the move. That is visual only
    /// — the animation retargets mid-flight, and nothing about commit
    /// timing reads the animation — and it is the accepted price of
    /// making the speed a preference.
    /// All three are `nonisolated`: `View` conformance infers `@MainActor`
    /// onto a type's statics, and `BoardPieceLayerTests` is deliberately
    /// nonisolated — the suite is the compile-time witness (the D44′
    /// shape) that plain value arithmetic stays callable from anywhere,
    /// and it caught exactly this. Deeply immutable values and a pure
    /// function need no isolation; `glide(duration:)` stays isolated
    /// because its only consumer is `body`.
    internal nonisolated static let durationRange: ClosedRange<Double> = 0.1...1.0
    internal nonisolated static let defaultDuration: Double = 0.22

    internal nonisolated static func clampedDuration(_ raw: Double) -> Double {
        min(max(raw, durationRange.lowerBound), durationRange.upperBound)
    }

    /// The glide at an already-clamped duration — `.snappy` stays the
    /// curve; only the duration is the user's.
    internal static func glide(duration: Double) -> Animation {
        .snappy(duration: duration)
    }

    // MARK: Stored Properties
    internal let pieces: [ResolvedPiece]
    internal let squareSize: CGFloat
    internal let perspective: PieceColor

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// D21′'s shape: read here because the layer is the duration's one
    /// consumer. Settings binds the same key, and both initial values are
    /// spelled `BoardPieceLayer.defaultDuration`, so the number lives
    /// once (the `EngineConfiguration` arrangement, documented at
    /// `StorageKeys`).
    @AppStorage(StorageKeys.pieceAnimationDuration)
    private var animationDuration = BoardPieceLayer.defaultDuration

    // MARK: Body
    internal var body: some View {
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

    /// The inverse of `BoardView.square(visualRow:visualColumn:)` — same
    /// mask, involutive XOR, so a flipped perspective moves every cell and
    /// the layer follows without a second flip rule.
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

/// The full asset set at the layer's own rendering — migrated from
/// `SquareView` when piece drawing moved here, because a preview should live
/// with the code it witnesses.
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

/// The 6% padding at three sizes — the scaling contract `SquareView`'s old
/// `pieceImage` carried.
#Preview("Size Scaling") {
    HStack(alignment: .bottom, spacing: 8) {
        ForEach([40, 80, 120] as [CGFloat], id: \.self) { size in
            PieceGlyph(piece: .whiteQueen, squareSize: size)
                .background(BoardStyle.rosewood.dark)
        }
    }
    .padding()
}

/// M6's gate, watchable: e4, the en-passant capture, the promotion morph,
/// and O-O, in one scripted line stepped by hand. Every step recomputes
/// position and tracker through `LibraryGamePreviewState.compute` — the same
/// pairing the review board renders — so what animates here is exactly what
/// animates when stepping a real game.
///
/// What to look for, per shape: e4 glides two squares; exf6 glides the
/// capturing pawn diagonally while the f5 pawn fades from the odd square;
/// gxh8=Q glides out of g7 and lands already a queen (one identity, the
/// pawn's — `PieceTracker.applyMove`'s reuse rule made visible); O-O glides
/// king and rook simultaneously, crossing.
#Preview("Four Shapes — Interactive") {
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
