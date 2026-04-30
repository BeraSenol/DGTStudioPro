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
            let layout = layout(for: totalSide)

            ZStack {
                boardFrame(size: totalSide, frameThickness: layout.squareSize)

                VStack(spacing: 0) {
                    fileStrip(layout: layout, isTop: true)

                    HStack(spacing: 0) {
                        rankStrip(layout: layout, isLeft: true)
                        squareGrid(layout: layout)
                        rankStrip(layout: layout, isLeft: false)
                    }

                    fileStrip(layout: layout, isTop: false)
                }
            }
            .frame(width: totalSide, height: totalSide)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Instance Methods
    private func layout(for totalSide: CGFloat) -> Layout {
        let squareSize = totalSide / 10
        let borderInset = gridBorderInset(squareSize: squareSize)
        let innerSquareSize = (8 * squareSize - 2 * borderInset) / 8
        return Layout(
            squareSize: squareSize,
            borderInset: borderInset,
            innerSquareSize: innerSquareSize
        )
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

    private func fileStrip(layout: Layout, isTop: Bool) -> some View {
        HStack(spacing: 0) {
            Spacer().frame(width: layout.squareSize + layout.borderInset)

            ForEach(Square.files, id: \.self) { visualColumn in
                let file = perspective == .white ? visualColumn : 7 - visualColumn
                Text(String(Square.fileCharacter(file)))
                    .font(.system(size: layout.squareSize * 0.25, weight: .ultraLight, design: .serif))
                    .foregroundStyle(style.light)
                    .frame(width: layout.innerSquareSize, height: layout.squareSize)
                    .offset(y: layout.squareSize * -0.3)
                    .rotationEffect(isTop ? .degrees(180) : .zero)
            }

            Spacer().frame(width: layout.squareSize + layout.borderInset)
        }
    }

    private func rankStrip(layout: Layout, isLeft: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: layout.borderInset)

            ForEach(Square.ranks, id: \.self) { visualRow in
                let rank = perspective == .white ? 7 - visualRow : visualRow
                Text(String(Square.rankCharacter(rank)))
                    .font(.system(size: layout.squareSize * 0.25, weight: .ultraLight, design: .serif))
                    .foregroundStyle(style.light)
                    .frame(width: layout.squareSize, height: layout.innerSquareSize)
                    .offset(x: layout.squareSize * 0.3)
                    .rotationEffect(isLeft ? .zero : .degrees(180))
            }

            Spacer().frame(height: layout.borderInset)
        }
    }

    private func squareGrid(layout: Layout) -> some View {
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
                            squareSize: layout.innerSquareSize,
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
        .padding(layout.borderInset)
        .overlay { gridBorder(squareSize: layout.squareSize) }
    }

    @ViewBuilder
    private func gridBorder(squareSize: CGFloat) -> some View {
        let thin = squareSize / 28

        switch style {
        case .leather:
            EmptyView()

        case .walnut:
            Rectangle()
                .strokeBorder(.gridBorder, lineWidth: thin * 19 / 15)

        case .rosewood:
            Rectangle()
                .strokeBorder(style.light, lineWidth: thin / 5)
            Rectangle()
                .strokeBorder(.gridBorder, lineWidth: thin * 19 / 15)
                .padding(thin / 5)
            Rectangle()
                .strokeBorder(style.light, lineWidth: thin / 5)
                .padding(thin * 22 / 15)

        case .wenge:
            Rectangle()
                .strokeBorder(style.light, lineWidth: thin * 13 / 10)
            Rectangle()
                .strokeBorder(style.dark, lineWidth: thin / 5)
                .padding(thin * 13 / 10)
        }
    }

    private func gridBorderInset(squareSize: CGFloat) -> CGFloat {
        let thin = squareSize / 28
        switch style {
        case .leather: return 0
        case .walnut:   return thin * 19 / 15
        case .rosewood: return thin * 5 / 3 - thin / 15
        case .wenge:    return thin * 3 / 2
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

// MARK: Supporting Types
private struct Layout {
    let squareSize: CGFloat
    let borderInset: CGFloat
    let innerSquareSize: CGFloat
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
    .frame(width: 3800, height: 3800)
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
    .frame(width: 3800, height: 3800)
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
    .frame(width: 3800, height: 3800)
}
