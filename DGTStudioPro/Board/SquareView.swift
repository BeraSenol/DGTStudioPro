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

    // MARK: Computed Properties
    private var fillColor: Color {
        isLightSquare ? style.light : style.dark
    }

    // MARK: Body
    internal var body: some View {
        ZStack {
            Rectangle()
                .fill(fillColor)

            // TODO: Apply Dynamic Rectangle Color
            //  if !highlight.isEmpty {
            //      Rectangle().fill(highlightColor)
            //  }

            if let imageName = piece.imageName {
                Image(imageName)
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .padding(squareSize * 0.06)
            }
        }
        .frame(width: squareSize, height: squareSize)
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

// Every highlight state on the same square — verifies that
// the TODO highlight overlay will look correct once wired up.
#Preview("Highlight States") {
    HStack(spacing: 4) {
        SquareView(
            piece: .whiteKing,
            pieceID: PieceID(rawValue: 4),
            isLightSquare: true,
            highlight: SquareHighlight(),
            squareSize: 80,
            style: .walnut
        )
        SquareView(
            piece: .whiteKing,
            pieceID: PieceID(rawValue: 4),
            isLightSquare: true,
            highlight: .lastMove,
            squareSize: 80,
            style: .walnut
        )
        SquareView(
            piece: .whiteKing,
            pieceID: PieceID(rawValue: 4),
            isLightSquare: true,
            highlight: .check,
            squareSize: 80,
            style: .walnut
        )
        SquareView(
            piece: .whiteKing,
            pieceID: PieceID(rawValue: 4),
            isLightSquare: true,
            highlight: .selected,
            squareSize: 80,
            style: .walnut
        )
        SquareView(
            piece: .whiteKing,
            pieceID: PieceID(rawValue: 4),
            isLightSquare: true,
            highlight: [.check, .lastMove],
            squareSize: 80,
            style: .walnut
        )
    }
    .padding()
}

// Same square rendered in each board style — catches color
// discrepancies between styles at a glance.
#Preview("All Styles") {
    HStack(spacing: 4) {
        ForEach(BoardStyle.allCases, id: \.self) { style in
            VStack(spacing: 0) {
                SquareView(
                    piece: .blackQueen,
                    pieceID: PieceID(rawValue: 28),
                    isLightSquare: true,
                    highlight: SquareHighlight(),
                    squareSize: 80,
                    style: style
                )
                SquareView(
                    piece: .whitePawn,
                    pieceID: PieceID(rawValue: 8),
                    isLightSquare: false,
                    highlight: SquareHighlight(),
                    squareSize: 80,
                    style: style
                )
            }
        }
    }
    .padding()
}

// Tests the piece padding at different square sizes — the 6%
// inset should scale proportionally without clipping or looking
// too loose at extremes.
#Preview("Size Scaling") {
    HStack(alignment: .bottom, spacing: 8) {
        SquareView(
            piece: .whiteQueen,
            pieceID: PieceID(rawValue: 3),
            isLightSquare: false,
            highlight: SquareHighlight(),
            squareSize: 40,
            style: .rosewood
        )
        SquareView(
            piece: .whiteQueen,
            pieceID: PieceID(rawValue: 3),
            isLightSquare: false,
            highlight: SquareHighlight(),
            squareSize: 80,
            style: .rosewood
        )
        SquareView(
            piece: .whiteQueen,
            pieceID: PieceID(rawValue: 3),
            isLightSquare: false,
            highlight: SquareHighlight(),
            squareSize: 120,
            style: .rosewood
        )
    }
    .padding()
}

// All six piece types for both colors — a quick visual inventory
// to confirm every piece image loads and renders correctly.
#Preview("All Pieces") {
    VStack(spacing: 0) {
        HStack(spacing: 0) {
            ForEach(Array([
                Piece.whitePawn, .whiteKnight, .whiteBishop,
                .whiteRook, .whiteQueen, .whiteKing
            ].enumerated()), id: \.offset) { index, piece in
                SquareView(
                    piece: piece,
                    pieceID: PieceID(rawValue: UInt8(index)),
                    isLightSquare: index % 2 == 0,
                    highlight: SquareHighlight(),
                    squareSize: 70,
                    style: .wenge
                )
            }
        }
        HStack(spacing: 0) {
            ForEach(Array([
                Piece.blackPawn, .blackKnight, .blackBishop,
                .blackRook, .blackQueen, .blackKing
            ].enumerated()), id: \.offset) { index, piece in
                SquareView(
                    piece: piece,
                    pieceID: PieceID(rawValue: UInt8(index + 16)),
                    isLightSquare: index % 2 != 0,
                    highlight: SquareHighlight(),
                    squareSize: 70,
                    style: .wenge
                )
            }
        }
    }
    .padding()
}
