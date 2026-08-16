import SwiftUI

struct BoardView: View {
    
    // MARK: Stored Properties
    let position: Position
    /// What the piece layer animates under - resolved by the caller through `PieceIdentity`,
    /// because only the caller knows which arm applies.
    let pieces: [ResolvedPiece]
    let style: BoardStyle
    let perspective: PieceColor
    let lastMove: LastMove?
    let checkSquare: Square?
    /// Reserved: nothing selects a square today (the physical board is the input). Defaulted, not
    /// removed - the highlight machinery is built; a click-to-move surface only passes a value.
    var selectedSquare: Square? = nil
    /// The mid-castle ghost square; both ghost fields must be non-nil to render.
    var ghostSquare: Square? = nil
    /// The ghost piece - drawn only when the square is actually empty, so a mid-fumble real piece
    /// hides the ghost rather than overlapping it.
    var ghostPiece: Piece? = nil
    /// Recovery highlights: `.attention` ("shouldn't be here") and `.target` ("belongs here").
    /// The board knows styles, not recovery.
    var attentionSquares: Set<Square> = []
    var targetSquares: Set<Square> = []
    /// Legal destinations of the one lifted piece (`MoveHints`) - the board knows dots, not chess.
    var hintSquares: Set<Square> = []
    
    // MARK: Preferences
    
    /// The coordinates - read here (one consumer) rather than threaded like `style`.
    @AppStorage(StorageKeys.showBoardCoordinates) private var showsCoordinates = true
    
    // MARK: Body
    var body: some View {
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
    
    /// One frame glyph - `Color.clear` when off, so the strip's layout contribution is unambiguous:
    /// the board keeps its 10×10 grid and size at every setting.
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
                        // "square.e4" - stable algebraic handle, kept per the registry's bet.
                        .accessibilityIdentifier(
                            AccessibilityID.boardSquare(square.algebraicNotation)
                        )
                    }
                }
            }
        }
        // The piece layer sits between squares and wood grain (pieces keep their texture), inside the
        // `.clipped()` so a glide never escapes the grid.
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
        // Unreachable today: every call site takes the default. Kept as pre-wiring - one value turns
        // all three on.
        if square == selectedSquare {
            result.insert(.selected)
        }
        if attentionSquares.contains(square) {
            result.insert(.attention)
        }
        if targetSquares.contains(square) {
            result.insert(.target)
        }
        if hintSquares.contains(square) {
            result.insert(.hint)
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

// White kingside castle mid-flight: king e1 → g1, real rook on h1, ghost on f1.
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

// Black queenside: king e8 → c8, rook on a8, ghost on d8.
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

// The mirror mid-lift: after 1. e4 d5 White's e4-pawn is up - a dot on the empty e5, a ring
// under the black d5-pawn. The composition check the square-level preview cannot make, since
// glyphs live on the piece layer.
#Preview("Lift Hints") {
    var position = Position.starting
    position[Squares.e2] = .empty          // e4 was played,
    position[Squares.d7] = .empty          // ...d5 answered,
    position[Squares.d5] = .blackPawn
    // ...and the e4-pawn is in the player's hand (e4 stays empty).

    return BoardView(
        position: position,
        pieces: PieceIdentity.resolved(position: position, tracker: .empty),
        style: .walnut,
        perspective: .white,
        lastMove: LastMove(from: Squares.d7, to: Squares.d5),
        checkSquare: nil,
        hintSquares: [Squares.e5, Squares.d5]
    )
    .frame(width: 600, height: 600)
}
