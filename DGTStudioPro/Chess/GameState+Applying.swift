extension GameState {
    
    // MARK: State Application
    
    /// Applies `move`, returning a new state with all six fields updated. Every path to a next
    /// state goes through here; hand-built states are the caller's problem.
    internal func applying(_ move: Move) -> GameState {
        GameState(
            position: position.applying(move),
            activeColor: activeColor.opponent,
            castlingRights: updatedCastlingRights(for: move),
            enPassantTarget: updatedEnPassantTarget(for: move),
            halfmoveClock: updatedHalfmoveClock(for: move),
            fullmoveNumber: updatedFullmoveNumber()
        )
    }
    
    // MARK: Per-Field Helpers
    
    /// Rights revoke on: any king move (both sides), a rook leaving home (that side), a capture on
    /// a rook's home corner (that side).
    private func updatedCastlingRights(for move: Move) -> CastlingRights {
        var rights = castlingRights
        let color = activeColor
        
        if move.pieceType == .king {
            rights.revokeAll(for: color)
        }
        
        if move.pieceType == .rook {
            let homeKingsideRook  = color == .white ? Squares.h1 : Squares.h8
            let homeQueensideRook = color == .white ? Squares.a1 : Squares.a8
            if move.from == homeKingsideRook {
                rights.revoke(.mask(for: color, .kingSide))
            } else if move.from == homeQueensideRook {
                rights.revoke(.mask(for: color, .queenSide))
            }
        }
        
        if move.isCapture {
            let opponent = color.opponent
            let oppKingsideRook  = opponent == .white ? Squares.h1 : Squares.h8
            let oppQueensideRook = opponent == .white ? Squares.a1 : Squares.a8
            if move.to == oppKingsideRook {
                rights.revoke(.mask(for: opponent, .kingSide))
            } else if move.to == oppQueensideRook {
                rights.revoke(.mask(for: opponent, .queenSide))
            }
        }
        
        return rights
    }
    
    /// EP target is set only after a double pawn push; otherwise cleared.
    /// The target is the square the pawn skipped over, not its landing square.
    private func updatedEnPassantTarget(for move: Move) -> Square? {
        guard move.isDoublePawnPush else { return nil }
        return activeColor == .white ? move.from + 8 : move.from - 8
    }
    
    /// Halfmove clock resets on pawn moves and captures (FIDE 50-move rule
    /// counter); otherwise increments.
    private func updatedHalfmoveClock(for move: Move) -> Int {
        if move.pieceType == .pawn || move.isCapture { return 0 }
        return halfmoveClock + 1
    }
    
    /// Fullmove number increments after black's move (i.e., when transitioning
    /// from black to move → white to move).
    private func updatedFullmoveNumber() -> Int {
        activeColor == .black ? fullmoveNumber + 1 : fullmoveNumber
    }
}
