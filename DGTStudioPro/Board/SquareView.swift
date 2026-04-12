//
//  SquareView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 01/04/2026.
//

import SwiftUI

// MARK: Square View
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

    // MARK: Static Methods
    internal static func == (lhs: SquareView, rhs: SquareView) -> Bool {
        lhs.piece == rhs.piece &&
        lhs.pieceID == rhs.pieceID &&
        lhs.isLightSquare == rhs.isLightSquare &&
        lhs.highlight == rhs.highlight &&
        lhs.squareSize == rhs.squareSize &&
        lhs.style == rhs.style
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
