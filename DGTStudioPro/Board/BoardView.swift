//
//  BoardView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/04/2026.
//

import SwiftUI

internal struct BoardView: View {

    // MARK: Stored Properties
    internal let position: Position
    internal let pieceTracker: PieceTracker
    internal let style: BoardStyle
    internal let perspective: PieceColor
    internal let lastMove: LastMove?
    internal let checkSquare: Square?
    internal let selectedSquare: Square?

    // MARK: Body
    internal var body: some View {
        GeometryReader { geometry in
            let totalSide = min(geometry.size.width, geometry.size.height)
            let squareSize = totalSide / 10
            let borderInset = gridBorderInset(squareSize: squareSize)
            let innerSquareSize = (8 * squareSize - 2 * borderInset) / 8

            ZStack {
                boardFrame(size: totalSide, frameThickness: squareSize)

                VStack(spacing: 0) {
                    fileStrip(
                        squareSize: squareSize,
                        borderInset: borderInset,
                        innerSquareSize: innerSquareSize,
                        isTop: true
                    )

                    HStack(spacing: 0) {
                        rankStrip(
                            squareSize: squareSize,
                            borderInset: borderInset,
                            innerSquareSize: innerSquareSize,
                            isLeft: true
                        )

                        squareGrid(
                            squareSize: squareSize,
                            borderInset: borderInset,
                            innerSquareSize: innerSquareSize)

                        rankStrip(
                            squareSize: squareSize,
                            borderInset: borderInset,
                            innerSquareSize: innerSquareSize,
                            isLeft: false
                        )
                    }

                    fileStrip(
                        squareSize: squareSize,
                        borderInset: borderInset,
                        innerSquareSize: innerSquareSize,
                        isTop: false
                    )
                }
            }
            .frame(width: totalSide, height: totalSide)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Instance Methods
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

    private func fileStrip(squareSize: CGFloat, borderInset: CGFloat,
                           innerSquareSize: CGFloat, isTop: Bool) -> some View {
        HStack(spacing: 0) {
            Spacer().frame(width: squareSize + borderInset)

            ForEach(Square.files, id: \.self) { visualColumn in
                let file = perspective == .white ? visualColumn : 7 - visualColumn
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

    private func rankStrip(squareSize: CGFloat, borderInset: CGFloat,
                           innerSquareSize: CGFloat, isLeft: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: borderInset)

            ForEach(Square.ranks, id: \.self) { visualRow in
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

    private func squareGrid(
        squareSize: CGFloat,
        borderInset: CGFloat,
        innerSquareSize: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(Square.ranks, id: \.self) { visualRow in
                HStack(spacing: 0) {
                    ForEach(Square.files, id: \.self) { visualColumn in
                        let square = square(visualRow: visualRow, visualColumn: visualColumn)
                        SquareView(
                            piece: position[square],
                            pieceID: pieceTracker[square],
                            isLightSquare: (square.file + square.rank) % 2 != 0,
                            highlight: squareHighlight(for: square),
                            squareSize: innerSquareSize,
                            style: style
                        )
                    }
                }
            }
        }
        .overlay {
            if style != .leather {
                Image("WoodGrainCoarse")
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
    }

    @ViewBuilder
    private func gridBorder(squareSize: CGFloat) -> some View {
        let thin = squareSize / 28

        switch style {
        case .leather:
            EmptyView()

        case .walnut:
            Rectangle()
                .strokeBorder(.gridBorder, lineWidth: thin)

        case .rosewood:
            Rectangle()
                .strokeBorder(style.light, lineWidth: thin / 3)
            Rectangle()
                .strokeBorder(.gridBorder, lineWidth: thin)
                .padding(thin / 3)
            Rectangle()
                .strokeBorder(style.light, lineWidth: thin / 3)
                .padding(thin * 5/3)

        case .wenge:
            Rectangle()
                .strokeBorder(style.light, lineWidth: thin)
            Rectangle()
                .strokeBorder(style.dark, lineWidth: thin / 2)
                .padding(thin)
        }
    }

    private func gridBorderInset(squareSize: CGFloat) -> CGFloat {
        let thin = squareSize / 28
        switch style {
        case .leather:  return 0
        case .rosewood: return thin * 5/3
        case .walnut:   return thin
        case .wenge:    return thin * 1.5
        }
    }

    private func square(visualRow: Int, visualColumn: Int) -> Square {
        (visualRow * 8 + visualColumn) ^ (perspective == .white ? 56 : 7)
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

// MARK: Previews
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
    //    .frame(width: 800, height: 800)
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
    //    .frame(width: 800, height: 800)
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
    //    .frame(width: 800, height: 800)
}
