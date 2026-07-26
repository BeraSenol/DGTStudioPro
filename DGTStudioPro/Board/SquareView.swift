//
//  SquareView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 01/04/2026.
//

import SwiftUI

internal struct SquareView: View, Equatable {
    
    // MARK: Stored Properties
    internal let piece: Piece
    internal let pieceID: PieceID?
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
            
            if let imageName = piece.imageName {
                pieceImage(imageName)
            } else if let imageName = ghostPiece?.imageName {
                // Ghost only draws on an empty square — the real piece occludes it once landed.
                pieceImage(imageName).opacity(0.5)
            }
            
            if highlight.contains(.selected) {
                Rectangle().strokeBorder(
                    Color.accentColor,
                    lineWidth: max(2, squareSize * 0.05)
                )
            }
            if highlight.contains(.attention) {
                // Solid red border: "fix this square" (remove / swap).
                Rectangle().strokeBorder(
                    .red.opacity(0.9),
                    lineWidth: max(2, squareSize * 0.055)
                )
            }
            if highlight.contains(.target) {
                // Dashed green border: "a piece belongs here" — reads as a
                // drop target without claiming anything is wrong.
                Rectangle().strokeBorder(
                    .green.opacity(0.9),
                    style: StrokeStyle(
                        lineWidth: max(2, squareSize * 0.05),
                        dash: [squareSize * 0.14]
                    )
                )
            }
        }
        .frame(width: squareSize, height: squareSize)
    }
    
    private func pieceImage(_ name: String) -> some View {
        Image(name)
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .padding(squareSize * 0.06)
    }
}

// MARK: Previews
#Preview("Basic Squares") {
    HStack(spacing: 0) {
        VStack(spacing: 0) {
            SquareView(
                piece: .empty,
                pieceID: nil,
                isLightSquare: true,
                highlight: SquareHighlight(),
                squareSize: 80,
                style: .walnut
            )
            SquareView(
                piece: .whiteRook,
                pieceID: PieceID(rawValue: 0),
                isLightSquare: false,
                highlight: SquareHighlight(),
                squareSize: 80,
                style: .walnut
            )
        }
        VStack(spacing: 0) {
            SquareView(
                piece: .blackKnight,
                pieceID: PieceID(rawValue: 18),
                isLightSquare: false,
                highlight: SquareHighlight(),
                squareSize: 80,
                style: .walnut
            )
            SquareView(
                piece: .empty,
                pieceID: nil,
                isLightSquare: true,
                highlight: SquareHighlight(),
                squareSize: 80,
                style: .walnut
            )
        }
    }
}

// Highlight permutations on the same square — including the M6 recovery
// styles (.attention solid red, .target dashed green).
#Preview("Highlight States") {
    HStack(spacing: 4) {
        SquareView(
            piece: .whiteKing, pieceID: PieceID(rawValue: 4),
            isLightSquare: true, highlight: SquareHighlight(),
            squareSize: 80, style: .walnut
        )
        SquareView(
            piece: .whiteKing, pieceID: PieceID(rawValue: 4),
            isLightSquare: true, highlight: .lastMove,
            squareSize: 80, style: .walnut
        )
        SquareView(
            piece: .whiteKing, pieceID: PieceID(rawValue: 4),
            isLightSquare: true, highlight: .check,
            squareSize: 80, style: .walnut
        )
        SquareView(
            piece: .whiteKing, pieceID: PieceID(rawValue: 4),
            isLightSquare: true, highlight: .selected,
            squareSize: 80, style: .walnut
        )
        SquareView(
            piece: .whiteKing, pieceID: PieceID(rawValue: 4),
            isLightSquare: true, highlight: [.check, .lastMove],
            squareSize: 80, style: .walnut
        )
        SquareView(
            piece: .blackPawn, pieceID: PieceID(rawValue: 18),
            isLightSquare: true, highlight: .attention,
            squareSize: 80, style: .walnut
        )
        SquareView(
            piece: .empty, pieceID: nil,
            isLightSquare: true, highlight: .target,
            squareSize: 80, style: .walnut
        )
    }
    .padding()
}

// Ghost rook in the four board styles — left square shows the ghost
// (empty square + ghostPiece), right shows what it looks like once the
// real rook lands (ghost is occluded by the real piece).
#Preview("Castling Ghost") {
    VStack(spacing: 0) {
        ForEach(BoardStyle.allCases, id: \.self) { style in
            HStack(spacing: 0) {
                SquareView(
                    piece: .empty, pieceID: nil,
                    isLightSquare: true, highlight: SquareHighlight(),
                    squareSize: 80, style: style,
                    ghostPiece: .whiteRook
                )
                SquareView(
                    piece: .whiteRook, pieceID: PieceID(rawValue: 7),
                    isLightSquare: false, highlight: SquareHighlight(),
                    squareSize: 80, style: style,
                    ghostPiece: .whiteRook
                )
                SquareView(
                    piece: .empty, pieceID: nil,
                    isLightSquare: false, highlight: SquareHighlight(),
                    squareSize: 80, style: style,
                    ghostPiece: .blackRook
                )
                SquareView(
                    piece: .blackRook, pieceID: PieceID(rawValue: 23),
                    isLightSquare: true, highlight: SquareHighlight(),
                    squareSize: 80, style: style,
                    ghostPiece: .blackRook
                )
            }
        }
    }
    .padding()
}

// Same square rendered in each board style.
#Preview("All Styles") {
    HStack(spacing: 4) {
        ForEach(BoardStyle.allCases, id: \.self) { style in
            VStack(spacing: 0) {
                SquareView(
                    piece: .blackQueen, pieceID: PieceID(rawValue: 28),
                    isLightSquare: true, highlight: SquareHighlight(),
                    squareSize: 80, style: style
                )
                SquareView(
                    piece: .whitePawn, pieceID: PieceID(rawValue: 8),
                    isLightSquare: false, highlight: SquareHighlight(),
                    squareSize: 80, style: style
                )
            }
        }
    }
    .padding()
}

#Preview("Size Scaling") {
    HStack(alignment: .bottom, spacing: 8) {
        SquareView(
            piece: .whiteQueen, pieceID: PieceID(rawValue: 3),
            isLightSquare: false, highlight: SquareHighlight(),
            squareSize: 40, style: .rosewood
        )
        SquareView(
            piece: .whiteQueen, pieceID: PieceID(rawValue: 3),
            isLightSquare: false, highlight: SquareHighlight(),
            squareSize: 80, style: .rosewood
        )
        SquareView(
            piece: .whiteQueen, pieceID: PieceID(rawValue: 3),
            isLightSquare: false, highlight: SquareHighlight(),
            squareSize: 120, style: .rosewood
        )
    }
    .padding()
}

#Preview("All Pieces") {
    VStack(spacing: 0) {
        HStack(spacing: 0) {
            ForEach(Array([
                Piece.whitePawn, .whiteKnight, .whiteBishop,
                .whiteRook, .whiteQueen, .whiteKing
            ].enumerated()), id: \.offset) { index, piece in
                SquareView(
                    piece: piece, pieceID: PieceID(rawValue: UInt8(index)),
                    isLightSquare: index % 2 == 0, highlight: SquareHighlight(),
                    squareSize: 70, style: .wenge
                )
            }
        }
        HStack(spacing: 0) {
            ForEach(Array([
                Piece.blackPawn, .blackKnight, .blackBishop,
                .blackRook, .blackQueen, .blackKing
            ].enumerated()), id: \.offset) { index, piece in
                SquareView(
                    piece: piece, pieceID: PieceID(rawValue: UInt8(index + 16)),
                    isLightSquare: index % 2 != 0, highlight: SquareHighlight(),
                    squareSize: 70, style: .wenge
                )
            }
        }
    }
    .padding()
}
