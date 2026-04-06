//
//  BoardView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/04/2026.
//

import SwiftUI

// MARK: - Board View
internal struct BoardView: View {
    
    // MARK: - Stored Properties
    internal let position: Position
    internal let pieceTracker: PieceTracker
    internal let style: BoardStyle
    internal let perspective: PieceColor
    internal let lastMoveFrom: Square?
    internal let lastMoveTo: Square?
    internal let checkSquare: Square?
    internal let selectedSquare: Square?
    
    // MARK: - Static Constants
    private static let gridBorderWidth: CGFloat = 5
    
    // MARK: - Body
    internal var body: some View {
        GeometryReader { geometry in
            let totalSide = min(geometry.size.width, geometry.size.height)
            let sqSize = totalSide / 10
            let stripWidth = sqSize
            
            ZStack {
                Rectangle()
                    .fill(style.dark)
                
                VStack(spacing: 0) {
                    fileStrip(squareSize: sqSize, stripHeight: stripWidth, isTop: true)
                    
                    HStack(spacing: 0) {
                        rankStrip(squareSize: sqSize, stripWidth: stripWidth, isLeft: true)
                        
                        grid(squareSize: sqSize)
                            .border(.black, width: Self.gridBorderWidth)
                        
                        rankStrip(squareSize: sqSize, stripWidth: stripWidth, isLeft: false)
                    }
                    
                    fileStrip(squareSize: sqSize, stripHeight: stripWidth, isTop: false)
                }
            }
            .frame(width: totalSide, height: totalSide)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    // MARK: - Instance Methods
    private func grid(squareSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { visualRow in
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { visualCol in
                        let sq = square(atVisualRow: visualRow, visualCol: visualCol)
                        SquareView(
                            piece: position[sq],
                            pieceID: pieceTracker[sq] ?? PieceID(rawValue: 0),
                            isLight: (sq.file + sq.rank) % 2 != 0,
                            highlight: highlight(for: sq),
                            squareSize: squareSize,
                            style: style
                        )
                    }
                }
            }
        }
    }
    
    private func fileStrip(squareSize: CGFloat, stripHeight: CGFloat, isTop: Bool) -> some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: stripHeight)
            
            ForEach(0..<8, id: \.self) { visualCol in
                let file = perspective == .white ? visualCol : 7 - visualCol
                let letter = String(Character(UnicodeScalar(Int(UnicodeScalar("a").value) + file)!))
                
                Text(letter)
                    .font(.system(size: stripHeight * 0.45, weight: .medium, design: .serif))
                    .foregroundStyle(Color.rosewoodLight)
                    .frame(width: squareSize, height: stripHeight)
                    .rotationEffect(isTop ? .degrees(180) : .zero)
            }
            
            Spacer()
                .frame(width: stripHeight)
        }
    }
    
    private func rankStrip(squareSize: CGFloat, stripWidth: CGFloat, isLeft: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { visualRow in
                let rank = perspective == .white ? 7 - visualRow : visualRow
                let digit = String(rank + 1)
                
                Text(digit)
                    .font(.system(size: stripWidth * 0.45, weight: .medium, design: .serif))
                    .foregroundStyle(Color.rosewoodLight)
                    .frame(width: stripWidth, height: squareSize)
                    .rotationEffect(isLeft ? .zero : .degrees(180))
            }
        }
    }
    
    private func square(atVisualRow row: Int, visualCol col: Int) -> Square {
        if perspective == .white {
            let rank = 7 - row
            let file = col
            return rank * 8 + file
        } else {
            let rank = row
            let file = 7 - col
            return rank * 8 + file
        }
    }
    
    private func highlight(for square: Square) -> SquareHighlight {
        var result = SquareHighlight()
        if square == lastMoveFrom || square == lastMoveTo {
            result.insert(.lastMove)
        }
        if square == checkSquare {
            result.insert(.check)
        }
        if square == selectedSquare {
            result.insert(.selected)
        }
        return result
    }
}
