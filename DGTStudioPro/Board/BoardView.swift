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
        let borderInset = gridBorderInset(squareSize: squareSize)
        let innerSquareSize = (8 * squareSize - 2 * borderInset) / 8

        return VStack(spacing: 0) {
            ForEach(Square.sides, id: \.self) { visualRow in
                HStack(spacing: 0) {
                    ForEach(Square.sides, id: \.self) { visualCol in
                        let sq = square(atVisualRow: visualRow, visualCol: visualCol)
                        SquareView(
                            piece: position[sq],
                            pieceID: pieceTracker[sq],
                            isLightSquare: (sq.file + sq.rank) % 2 != 0,
                            highlight: squareHighlight(for: sq),
                            squareSize: innerSquareSize,
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
        .padding(borderInset)
        .overlay { gridBorder(squareSize: squareSize) }
        .frame(width: 8 * squareSize, height: 8 * squareSize)
    }

    private func gridBorderInset(squareSize: CGFloat) -> CGFloat {
        let thin = squareSize / 30
        switch style {
        case .leather:  return 0
        case .rosewood: return thin * 2
        case .walnut:   return thin
        case .wenge:    return thin * 1.5
        }
    }
    @ViewBuilder
    private func gridBorder(squareSize: CGFloat) -> some View {
        let thin = squareSize / 30

        switch style {
        case .leather:
            EmptyView()
        case .walnut:
            Rectangle()
                .strokeBorder(.black.opacity(0.5), lineWidth: thin)

        case .rosewood:
            Rectangle()
                .strokeBorder(style.light, lineWidth: thin / 2)
            Rectangle()
                .strokeBorder(.black, lineWidth: thin)
                .padding(thin / 2)
            Rectangle()
                .strokeBorder(style.light, lineWidth: thin / 2)
                .padding(thin / 2 + thin)

        case .wenge:
            Rectangle()
                .strokeBorder(style.light, lineWidth: thin)
            Rectangle()
                .strokeBorder(style.dark, lineWidth: thin / 2)
                .padding(thin)
        }
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
            Rectangle()
                .fill(style.dark)
                .frame(width: size, height: size)

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
        let borderInset = gridBorderInset(squareSize: squareSize)
        let innerSquareSize = (8 * squareSize - 2 * borderInset) / 8

        return HStack(spacing: 0) {
            Spacer().frame(width: squareSize + borderInset)

            ForEach(Square.sides, id: \.self) { visualCol in
                let file = perspective == .white ? visualCol : 7 - visualCol
                Text(String(Square.fileCharacter(file)))
                    .font(.system(size: squareSize * 0.25, weight: .ultraLight, design: .serif))
                    .foregroundStyle(style.light)
                    .frame(width: innerSquareSize, height: squareSize)
                    .offset(y: squareSize * -0.3)
                    .rotationEffect(isTop ? .degrees(180) : .zero)
            }

            Spacer().frame(width: squareSize + borderInset)
        }
    }

    private func rankStrip(squareSize: CGFloat, isLeft: Bool) -> some View {
        let borderInset = gridBorderInset(squareSize: squareSize)
        let innerSquareSize = (8 * squareSize - 2 * borderInset) / 8

        return VStack(spacing: 0) {
            Spacer().frame(height: borderInset)

            ForEach(Square.sides, id: \.self) { visualRow in
                let rank = perspective == .white ? 7 - visualRow : visualRow
                Text(String(Square.rankCharacter(rank)))
                    .font(.system(size: squareSize * 0.25, weight: .ultraLight, design: .serif))
                    .foregroundStyle(style.light)
                    .frame(width: squareSize, height: innerSquareSize)
                    .offset(x: squareSize * 0.3)
                    .rotationEffect(isLeft ? .zero : .degrees(180))
            }

            Spacer().frame(height: borderInset)
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

#Preview("Leather") {
    BoardView(
        position: .starting,
        pieceTracker: .empty,
        style: .leather,
        perspective: .white,
        lastMove: nil,
        checkSquare: nil,
        selectedSquare: nil
    )
    .frame(width: 800, height: 800)
    .background(.green)
}

#Preview("Rosewood") {
    BoardView(
        position: .starting,
        pieceTracker: .empty,
        style: .rosewood,
        perspective: .white,
        lastMove: nil,
        checkSquare: nil,
        selectedSquare: nil
    )
    .frame(width: 800, height: 800)
    .background(.green)
}

#Preview("Walnut") {
    BoardView(
        position: .starting,
        pieceTracker: .empty,
        style: .walnut,
        perspective: .white,
        lastMove: nil,
        checkSquare: nil,
        selectedSquare: nil
    )
    .frame(width: 800, height: 800)
    .background(.green)
}

#Preview("Wenge") {
    BoardView(
        position: .starting,
        pieceTracker: .empty,
        style: .wenge,
        perspective: .white,
        lastMove: nil,
        checkSquare: nil,
        selectedSquare: nil
    )
    .frame(width: 800, height: 800)
    .background(.green)
}
