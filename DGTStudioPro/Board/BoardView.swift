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
    internal let lastMove: LastMove?
    internal let checkSquare: Square?
    internal let selectedSquare: Square?
    
    // MARK: - Body
    internal var body: some View {
        GeometryReader { geometry in
            let totalSide = min(geometry.size.width, geometry.size.height)
            let squareSize = totalSide / 10
            
            ZStack {
                boardFrame(size: totalSide, frameThickness: squareSize)
                
                VStack(spacing: 0) {
                    fileStrip(squareSize: squareSize, isTop: true)
                    
                    HStack(spacing: 0) {
                        rankStrip(squareSize: squareSize, isLeft: true)
                        squareGrid(squareSize: squareSize)
                        rankStrip(squareSize: squareSize, isLeft: false)
                    }
                    
                    fileStrip(squareSize: squareSize, isTop: false)
                }
            }
            .frame(width: totalSide, height: totalSide)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    // MARK: - Instance Methods
    private func squareGrid(squareSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(Square.sides, id: \.self) { visualRow in
                HStack(spacing: 0) {
                    ForEach(Square.sides, id: \.self) { visualCol in
                        let sq = square(atVisualRow: visualRow, visualCol: visualCol)
                        SquareView(
                            piece: position[sq],
                            pieceID: pieceTracker[sq],
                            isLightSquare: (sq.file + sq.rank) % 2 != 0,
                            highlight: squareHighlight(for: sq),
                            squareSize: squareSize,
                            style: style
                        )
                    }
                }
            }
        }
        .overlay {
            if style != .leather {
                Image("WoodGrainCourse")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blendMode(.overlay)
                    .opacity(0.25)
                    .allowsHitTesting(false)
            }
        }
        .clipped()
        .padding(squareSize / 30)
        .border(.black.opacity(0.5), width: squareSize / 30)
    }
    
    private func boardFrame(size: CGFloat, frameThickness: CGFloat) -> some View {
        let trapezoid = Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: size, y: 0))
            path.addLine(to: CGPoint(x: size - frameThickness, y: frameThickness))
            path.addLine(to: CGPoint(x: frameThickness, y: frameThickness))
            path.closeSubpath()
        }
        
        return ZStack {
            ForEach(0..<4, id: \.self) { side in
                ZStack(alignment: .top) {
                    trapezoid.fill(style.dark)
                    
                    if style != .leather {
                        Image("WoodGrainFine")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: frameThickness)
                            .rotationEffect(.degrees(90))
                            .blendMode(.overlay)
                            .opacity(0.25)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(trapezoid)
                .rotationEffect(.degrees(Double(side) * 90), anchor: .center)
            }
        }
    }
    
    private func fileStrip(squareSize: CGFloat, isTop: Bool) -> some View {
        HStack(spacing: 0) {
            Spacer().frame(width: squareSize)
            
            ForEach(Square.sides, id: \.self) { visualCol in
                let file = perspective == .white ? visualCol : 7 - visualCol
                Text(String((file * 8).fileIndicator))
                    .font(.system(size: squareSize * 0.25, weight: .ultraLight, design: .serif))
                    .foregroundStyle(.rosewoodLight)
                    .frame(width: squareSize, height: squareSize)
                    .rotationEffect(isTop ? .degrees(180) : .zero)
            }
            
            Spacer().frame(width: squareSize)
        }
    }
    
    private func rankStrip(squareSize: CGFloat, isLeft: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Square.sides, id: \.self) { visualRow in
                let rank = perspective == .white ? 7 - visualRow : visualRow
                Text(String((rank * 8).rankIndicator))
                    .font(.system(size: squareSize * 0.25, weight: .ultraLight, design: .serif))
                    .foregroundStyle(.rosewoodLight)
                    .frame(width: squareSize, height: squareSize)
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
    
    private func squareHighlight(for square: Square) -> SquareHighlight {
        var result = SquareHighlight()
        if square == lastMove?.from || square == lastMove?.to {
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
