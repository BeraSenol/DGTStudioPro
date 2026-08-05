internal struct FEN: Equatable, Sendable {
    
    // MARK: Static Constants
    internal static let starting = FEN(
        position: .starting,
        activeColor: .white,
        castlingRights: .all,
        enPassantTarget: nil,
        halfmoveClock: 0,
        fullmoveNumber: 1
    )
    
    internal static let startingString = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    
    // MARK: Stored Properties
    internal let position: Position
    internal let activeColor: PieceColor
    internal let castlingRights: CastlingRights
    internal let enPassantTarget: Square?
    internal let halfmoveClock: Int
    internal let fullmoveNumber: Int
    
    // MARK: Computed Properties
    internal var string: String {
        "\(positionKey) \(halfmoveClock) \(fullmoveNumber)"
    }
    
    internal var positionKey: String {
        let color: Character = activeColor == .white ? "w" : "b"
        let enPassant = enPassantTarget?.algebraicNotation ?? "-"
        return "\(piecePlacement) \(color) \(castlingRights.fen) \(enPassant)"
    }
    
    internal var piecePlacement: String {
        var result = ""
        result.reserveCapacity(72)
        
        for rank in Square.ranks.reversed() {
            if rank < 7 { result.append("/") }
            var emptyRun = 0
            
            for file in Square.files {
                let piece = position[rank * 8 + file]
                
                if piece.isOccupied {
                    if emptyRun > 0 {
                        result.append(emptyRun.asciiDigit)
                        emptyRun = 0
                    }
                    result.append(piece.fenCharacter)
                } else {
                    emptyRun += 1
                }
            }
            
            if emptyRun > 0 {
                result.append(emptyRun.asciiDigit)
            }
        }
        
        return result
    }
}

// MARK: Move Generation

extension FEN {
    /// Legal moves from this position, via `GameState` — the single source of
    /// legality.
    ///
    /// **Test-only by decision, not rot.** No production caller: every app path
    /// already holds a `GameState`. It is kept because it is the one symbol
    /// that exercises the `FEN` → `GameState` conversion init against real
    /// generation, so a drift between the two six-field shapes fails a test
    /// rather than surfacing as a wrong move list somewhere downstream. See
    /// the waiver register's "test-only by decision" list.
    internal func legalMoves() -> [Move] {
        GameState(self).legalMoves()
    }
}
