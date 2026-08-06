internal struct GameState: Equatable, Sendable {
    
    // MARK: Static Constants
    internal static let starting = GameState(
        position: .starting,
        activeColor: .white,
        castlingRights: .all,
        enPassantTarget: nil,
        halfmoveClock: 0,
        fullmoveNumber: 1
    )
    
    // MARK: Stored Properties
    internal let position: Position
    internal let activeColor: PieceColor
    internal let castlingRights: CastlingRights
    internal let enPassantTarget: Square?
    internal let halfmoveClock: Int
    internal let fullmoveNumber: Int
    
}

// MARK: FEN Conversion

/// Deliberately in an extension, not the type body: a conversion init inside
/// the struct suppresses the synthesized memberwise init, which every call
/// site here wants and which was previously hand-written to match exactly.
extension GameState {
    internal init(_ fen: FEN) {
        self.init(
            position: fen.position,
            activeColor: fen.activeColor,
            castlingRights: fen.castlingRights,
            enPassantTarget: fen.enPassantTarget,
            halfmoveClock: fen.halfmoveClock,
            fullmoveNumber: fen.fullmoveNumber
        )
    }
}
extension FEN {
    internal init(_ state: GameState) {
        self.init(
            position: state.position,
            activeColor: state.activeColor,
            castlingRights: state.castlingRights,
            enPassantTarget: state.enPassantTarget,
            halfmoveClock: state.halfmoveClock,
            fullmoveNumber: state.fullmoveNumber
        )
    }
}

// MARK: - Replay
//
// Folded in from `GameState+Replay.swift` at M13 (6 Aug 2026). The type body
// and this extension were 51 lines each, surrounded by `+MoveGeneration` (354)
// and `+SAN` (324) — so the file split read as four peers when it was really
// two large extensions and a core that fits on a screen. Merging the two small
// halves leaves the split describing what it is actually for.

extension GameState {

    /// The first SAN string that fails to parse throws `ReplayError`,
    /// carrying the index (0-based), the offending string, and the
    /// underlying `SANParseError`.
    ///
    /// The "I just want the final state" path, and since M4 it has the
    /// production caller it spent three months waiting for:
    /// `GameClassification` replays to the final position to ask
    /// `SpecialCheckmate` what pattern the game ended on, and that is the one
    /// walk in the app with no use for the plies in between.
    ///
    /// Every *other* walk still needs the per-ply state this method discards,
    /// which is why they don't call it and shouldn't be made to: `Game`
    /// scrubs history, `LibraryGamePreviewState` stops at the first bad ply,
    /// and `MovetextEdit.validate` needs each ply's canonical SAN — so all
    /// three loop `parseSAN` + `applying` themselves.
    internal func replay(_ sanMoves: [String]) throws(ReplayError) -> GameState {
        var state = self
        for (index, san) in sanMoves.enumerated() {
            let move: Move
            do {
                move = try state.parseSAN(san)
            } catch {
                throw ReplayError.invalidMove(index: index, san: san, underlying: error)
            }
            state = state.applying(move)
        }
        return state
    }
}

extension FEN {
    internal func replay(_ sanMoves: [String]) throws(ReplayError) -> GameState {
        try GameState(self).replay(sanMoves)
    }
}

internal enum ReplayError: Error, Equatable {
    /// The SAN string at the given move index failed to parse. The
    /// underlying parser error captures the specific reason; the index
    /// and string allow callers to surface diagnostic context like
    /// "move 14 ('Bxd5'): no legal move matches".
    case invalidMove(index: Int, san: String, underlying: SANParseError)
}
