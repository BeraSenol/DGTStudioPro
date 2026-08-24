struct GameState: Equatable, Sendable {
    
    // MARK: Static Constants
    
    /// Guarded by the perft suite rather than by an equality test: a wrong field here shows up as
    /// `Chess.perft(.starting, depth: 4) != 197_281`.
    static let starting = GameState(
        position: .starting,
        activeColor: .white,
        castlingRights: .all,
        enPassantTarget: nil,
        halfmoveClock: 0,
        fullmoveNumber: 1
    )
    
    // MARK: Stored Properties
    let position: Position
    let activeColor: PieceColor
    let castlingRights: CastlingRights
    let enPassantTarget: Square?
    let halfmoveClock: Int
    let fullmoveNumber: Int
}

// MARK: FEN Conversion

/// Both conversions live in extensions, not in their type bodies: an init inside the struct
/// suppresses the synthesized memberwise init, which every call site here wants.
extension GameState {
    init(_ fen: FEN) {
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
    init(_ state: GameState) {
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

// MARK: Replay

extension GameState {
    
    /// Replays SAN to the final state; the first failure throws `ReplayError` with index, string
    /// and parser error.
    func replay(_ sanMoves: [String]) throws(ReplayError) -> GameState {
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
    /// **Test-only by decision**, like `FEN.legalMoves()`; production replays from `GameState`.
    func replay(_ sanMoves: [String]) throws(ReplayError) -> GameState {
        try GameState(self).replay(sanMoves)
    }
}

enum ReplayError: Error, Equatable {
    /// Index and string are carried so a caller can say which ply failed - "move 14 ('Bxd5'): no
    /// legal move matches" - rather than only why.
    case invalidMove(index: Int, san: String, underlying: SANParseError)
}
