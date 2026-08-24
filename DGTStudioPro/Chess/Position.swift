/// The 64 squares and nothing else - no side to move, no rights, no clocks. `Codable` is
/// synthesized, and `DGTSessionRecording.Entry` is its one call site - so the synthesized shape,
/// `{"squares":[{"rawValue":N} × 64]}`, is a recording-file format. Renaming `squares` or
/// re-packing `Piece` invalidates recordings already on disk. Drafts store a FEN string instead.
struct Position: Codable, Equatable, Sendable {
    
    // MARK: Static Constants
    static let empty: Position = .init()
    
    static let starting: Position = {
        var position = Position()
        let backRank: [PieceType] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        
        // Squares a1/a2/a7/a8 serve as rank base offsets (0, 8, 48, 56)
        // Looping through Square.files (0–7) produces the correct square index.
        for file in Square.files {
            position[Squares.a1 + file] = Piece(.white, backRank[file])
            position[Squares.a2 + file] = .whitePawn
            position[Squares.a7 + file] = .blackPawn
            position[Squares.a8 + file] = Piece(.black, backRank[file])
        }
        
        return position
    }()
    
    // MARK: Stored Properties
    
    /// An array, so `applying` pays a heap allocation per ply. On the deferred-cost census: fine at
    /// personal scale, and any fix touches `Chess/` and so inherits the perft gate.
    private var squares: [Piece]
    
    // MARK: Initializers
    private init() {
        squares = [Piece](repeating: .empty, count: Square.count)
    }
    
    // MARK: Subscripts
    subscript(square: Square) -> Piece {
        get { squares[square] }
        set { squares[square] = newValue }
    }
    
    // MARK: Instance Methods
    
    /// **The step order is load-bearing.** For an ordinary capture `capturedSquare == to`, so the
    /// clear must precede writing the mover there; reversed, the moving piece vanishes. En passant
    /// is what makes the clear a separate step at all - its captured square is neither `from` nor
    /// `to`. Castling's rook squares collide with neither, so it can come last.
    func applying(_ move: Move) -> Position {
        var result = self
        
        // En passant captures a square other than `move.to`
        if let captured = move.capturedSquare {
            result[captured] = .empty
        }
        
        result[move.from] = .empty
        result[move.to] = Piece(move.pieceColor, move.promotionType ?? move.pieceType)
        
        if move.isCastling, let rookFrom = move.rookFrom, let rookTo = move.rookTo {
            result[rookTo] = result[rookFrom]
            result[rookFrom] = .empty
        }
        
        return result
    }
    
    /// Linear scan, called once per `legalMoves()` and once per `isInCheck` -
    /// which is per node in perft. `firstIndex(of:)` is the same complexity
    /// but hands the search to the stdlib rather than a Swift loop over an
    /// index range.
    ///
    /// Returns the **first** king found, which is only correct because two same-colour kings is on
    /// the assumed-never list. `FEN(parsing:)` does not count kings, so a hand-edited file can put
    /// two on the board and this will silently pick the lower square.
    func kingSquare(for color: PieceColor) -> Square? {
        squares.firstIndex(of: Piece(color, .king))
    }
}
