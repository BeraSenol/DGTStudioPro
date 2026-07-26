//
//  GameState+Replay.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 10/05/2026.
//

extension GameState {
    
    // MARK: Replay (7g)
    
    /// The first SAN string that fails to parse throws `ReplayError`,
    /// carrying the index (0-based), the offending string, and the
    /// underlying `SANParseError`.
    ///
    /// No production caller today, and the reason is worth recording rather
    /// than rediscovering: every walk the app actually performs needs the
    /// per-ply state this method discards. `Game` scrubs history,
    /// `LibraryGamePreviewState` stops at the first bad ply, and
    /// `MovetextEdit.validate` needs each ply's canonical SAN — so all three
    /// loop `parseSAN` + `applying` themselves. This stays as the "I just
    /// want the final state" path, suited by `GameStateReplayTests`.
    internal func replay(_ sanMoves: [String]) throws -> GameState {
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

// MARK: FEN Forwarding

extension FEN {
    internal func replay(_ sanMoves: [String]) throws -> GameState {
        try GameState(self).replay(sanMoves)
    }
}

// MARK: Errors

internal enum ReplayError: Error, Equatable {
    /// The SAN string at the given move index failed to parse. The
    /// underlying parser error captures the specific reason; the index
    /// and string allow callers to surface diagnostic context like
    /// "move 14 ('Bxd5'): no legal move matches".
    case invalidMove(index: Int, san: String, underlying: SANParseError)
}
