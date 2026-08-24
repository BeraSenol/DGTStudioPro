extension GameState {

    // MARK: State Application

    /// Applies `move`, returning a new state with all six fields recomputed. Every path to a next
    /// state goes through here - nothing in the app hand-builds a mid-game `GameState`, and the
    /// move generator's guards assume that.
    func applying(_ move: Move) -> GameState {
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

    /// Three revocation causes, and they are the whole list: any king move (both sides, castling
    /// included), a rook leaving home (that side), a capture on a rook's home corner (that side).
    /// Rights are never restored.
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

    /// The square the pawn skipped over, not its landing square. Cleared by every other move.
    ///
    /// **Permissive: stamped after any double push**, whether or not an enemy pawn could actually
    /// capture there. FIDE's repetition rule is about the en-passant *right*, so this line is why
    /// `FEN.positionKey` under-reports repetitions - the fix belongs here, not there.
    private func updatedEnPassantTarget(for move: Move) -> Square? {
        guard move.isDoublePawnPush else { return nil }
        return activeColor == .white ? move.from + 8 : move.from - 8
    }

    /// The FIDE 50-move counter: resets on any pawn move and any capture, otherwise increments.
    private func updatedHalfmoveClock(for move: Move) -> Int {
        if move.pieceType == .pawn || move.isCapture { return 0 }
        return halfmoveClock + 1
    }

    /// Increments after black's move only - it counts moves, where the halfmove clock counts plies.
    private func updatedFullmoveNumber() -> Int {
        activeColor == .black ? fullmoveNumber + 1 : fullmoveNumber
    }
}
