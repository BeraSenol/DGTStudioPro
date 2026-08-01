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
    /// What the piece layer renders and animates under — resolved by the
    /// caller through `PieceIdentity`, because only the caller knows which
    /// arm applies: the review board's position *is* its game's position
    /// (total parity), while the mirror renders the physical board against a
    /// live game that may lag it. `BoardView` stays dumb either way; it
    /// draws what it is handed at the squares `position` says are occupied,
    /// and `PieceIdentity` guarantees those two agree.
    internal let pieces: [ResolvedPiece]
    internal let style: BoardStyle
    internal let perspective: PieceColor
    internal let lastMove: LastMove?
    internal let checkSquare: Square?
    /// Reserved: nothing in the app selects a square today — the physical
    /// board is the input — so every call site takes this default. Defaulted
    /// rather than removed because `SquareHighlight.selected` and
    /// `SquareView`'s tint are already built; a click-to-move or
    /// position-setup surface would need only to pass a value.
    internal var selectedSquare: Square? = nil
    /// Square at which to render a 50%-opacity ghost piece (the mid-castle
    /// "rook hasn't moved yet" cue from `DGTLiveSession`). Both `ghostSquare`
    /// and `ghostPiece` must be non-nil for the ghost to render. Defaulted so
    /// existing call sites compile unchanged.
    internal var ghostSquare: Square? = nil
    /// Piece to render at `ghostSquare`. `SquareView` only draws it when that
    /// square is actually empty — so a stray real piece on the ghost square
    /// (e.g. mid-fumble) hides the ghost rather than overlapping it.
    internal var ghostPiece: Piece? = nil
    /// Recovery highlights (M6.1): squares rendered with the `.attention`
    /// style ("something here shouldn't be") and the `.target` style ("a
    /// piece belongs here"). Generic sets, defaulted empty so existing call
    /// sites compile unchanged — same pattern as the ghost; the board
    /// knows styles, not recovery.
    internal var attentionSquares: Set<Square> = []
    internal var targetSquares: Set<Square> = []
    
    // MARK: Preferences
    
    /// D21′ — the frame's coordinate labels. Read here rather than threaded
    /// from the call sites (as `style` is) because it has exactly one
    /// consumer: one `@AppStorage` site instead of one per board keeps the
    /// "absent reads as true" default from being repeated three times. Style
    /// stays injected because the previews and the Settings swatches need to
    /// override it; nothing needs to override this.
    @AppStorage(StorageKeys.showBoardCoordinates) private var showsCoordinates = true
    
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
                coordinateLabel(Square.fileCharacter(file), squareSize: layout.squareSize)
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
                coordinateLabel(Square.rankCharacter(rank), squareSize: layout.squareSize)
                    .frame(width: layout.squareSize, height: layout.innerSquareSize)
                    .offset(x: layout.squareSize * 0.3)
                    .rotationEffect(isLeft ? .zero : .degrees(180))
            }
            
            Spacer().frame(height: layout.borderInset)
        }
    }
    
    /// One frame glyph — or nothing drawn, when coordinates are off (D21′).
    /// The caller applies the frame, and the off branch is `Color.clear`
    /// rather than an absent view so the strip's contribution to layout is
    /// unambiguous: the board keeps its 10×10 grid, its wooden border, and
    /// its size at every setting. Also the one place the two strips' shared
    /// type treatment now lives.
    @ViewBuilder
    private func coordinateLabel(_ character: Character, squareSize: CGFloat) -> some View {
        if showsCoordinates {
            Text(String(character))
                .font(.system(size: squareSize * 0.25, weight: .ultraLight, design: .serif))
                .foregroundStyle(style.light)
        } else {
            Color.clear
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
                            isLightSquare: (square.file + square.rank) % 2 != 0,
                            highlight: squareHighlight(for: square),
                            squareSize: layout.innerSquareSize,
                            style: style,
                            ghostPiece: (square == ghostSquare) ? ghostPiece : nil
                        )
                        // e.g. "square.e4" — stable algebraic handle for
                        // UI tests (esp. keyboard-nav verification).
                        .accessibilityIdentifier(
                            AccessibilityID.boardSquare(square.algebraicNotation)
                        )
                    }
                }
            }
        }
        // The piece layer sits between the squares and the wood grain, so
        // pieces keep the grain texture they always rendered under — and
        // inside the `.clipped()`, so a glide never escapes the grid.
        .overlay {
            BoardPieceLayer(
                pieces: pieces,
                squareSize: layout.innerSquareSize,
                perspective: perspective
            )
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
        if attentionSquares.contains(square) {
            result.insert(.attention)
        }
        if targetSquares.contains(square) {
            result.insert(.target)
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
        pieces: PieceIdentity.resolved(position: .starting, tracker: .starting),
        style: .leather,
        perspective: .white,
        lastMove: nil,
        checkSquare: nil
    )
    .frame(width: 800, height: 800)
}

#Preview("Rosewood") {
    BoardView(
        position: .starting,
        pieces: PieceIdentity.resolved(position: .starting, tracker: .starting),
        style: .rosewood,
        perspective: .white,
        lastMove: nil,
        checkSquare: nil
    )
    .frame(width: 800, height: 800)
}

#Preview("Walnut") {
    BoardView(
        position: .starting,
        pieces: PieceIdentity.resolved(position: .starting, tracker: .starting),
        style: .walnut,
        perspective: .white,
        lastMove: nil,
        checkSquare: nil
    )
    .frame(width: 800, height: 800)
}

#Preview("Wenge") {
    BoardView(
        position: .starting,
        pieces: PieceIdentity.resolved(position: .starting, tracker: .starting),
        style: .wenge,
        perspective: .white,
        lastMove: nil,
        checkSquare: nil
    )
    .frame(width: 800, height: 800)
}

// White kingside castle in progress: king has moved e1 → g1, the real
// rook is still on h1, and a ghost rook is rendered on f1 awaiting the
// physical move.
#Preview("Kingside Castle Ghost") {
    var position = Position.starting
    // Clear f1 and g1 (bishop, knight), move king e1 → g1.
    position[Squares.f1] = .empty
    position[Squares.g1] = .whiteKing
    position[Squares.e1] = .empty
    
    return BoardView(
        position: position,
        pieces: PieceIdentity.resolved(position: position, tracker: .empty),
        style: .walnut,
        perspective: .white,
        lastMove: LastMove(from: Squares.e1, to: Squares.g1),
        checkSquare: nil,
        ghostSquare: Squares.f1,
        ghostPiece: .whiteRook
    )
    .frame(width: 800, height: 800)
}

// Black queenside castle in progress: king e8 → c8, rook still on a8,
// ghost rook on d8.
#Preview("Queenside Castle Ghost (Black)") {
    var position = Position.starting
    position[Squares.b8] = .empty
    position[Squares.c8] = .blackKing
    position[Squares.d8] = .empty
    position[Squares.e8] = .empty
    
    return BoardView(
        position: position,
        pieces: PieceIdentity.resolved(position: position, tracker: .empty),
        style: .rosewood,
        perspective: .black,
        lastMove: LastMove(from: Squares.e8, to: Squares.c8),
        checkSquare: nil,
        ghostSquare: Squares.d8,
        ghostPiece: .blackRook
    )
    .frame(width: 600, height: 600)
}
