//
//  SquareView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 01/04/2026.
//

import SwiftUI

// MARK: - Square View
internal struct SquareView: View, Equatable {
    
    // MARK: - Stored Properties
    internal let piece: Piece
    internal let pieceID: PieceID?
    internal let isLightSquare: Bool
    internal let highlight: SquareHighlight
    internal let squareSize: CGFloat
    internal let style: BoardStyle
    
    // MARK: - Static Methods
    internal static func == (lhs: SquareView, rhs: SquareView) -> Bool {
        lhs.piece == rhs.piece &&
        lhs.isLightSquare == rhs.isLightSquare &&
        lhs.highlight == rhs.highlight &&
        lhs.squareSize == rhs.squareSize &&
        lhs.style == rhs.style
    }
    
    // MARK: - Computed Properties
    private var fillColor: Color {
        isLightSquare ? style.light : style.dark
    }
    
    // MARK: - Body
    internal var body: some View {
        ZStack {
            Rectangle()
                .fill(fillColor)
            
            if highlight.contains(.lastMove) {
                Rectangle()
                    .fill(Color.black.opacity(0.12))
            }
            
            if highlight.contains(.check) {
                Rectangle()
                    .fill(Color.leatherLight.opacity(0.45))
            }
            
            if highlight.contains(.selected) {
                Rectangle()
                    .fill(Color.white.opacity(0.25))
            }
            
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
