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

// MARK: - Replay (folded in from GameState+Replay.swift at M13)

extension GameState {

    /// Replays SAN to the final state; the first failure throws `ReplayError` with index, string
    /// and parser error.
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
