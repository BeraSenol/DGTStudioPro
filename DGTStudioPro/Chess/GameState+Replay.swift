//
//  GameState+Replay.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 10/05/2026.
//

extension GameState {
    
    // MARK: Replay (7g)
    
    /// Replays a sequence of SAN move strings starting from this state and
    /// returns the resulting game state.
    ///
    /// The first SAN string that fails to parse throws `ReplayError`,
    /// carrying the index (0-based), the offending string, and the
    /// underlying `SANParseError`. Callers building higher-level importers
    /// (e.g. `PGNStore`) wrap this with file or game context.
    ///
    /// For per-move state inspection (UI scrubbing through history),
    /// callers do their own loop calling `parseSAN` + `applying`. This
    /// method exists for the common "I just want the final state" path.
    internal func replay(_ sanMoves: [String]) throws -> GameState {
        var state = self
        for (index, san) in sanMoves.enumerated() {
            let move: Move
            do {
                move = try state.parseSAN(san)
            } catch let error as SANParseError {
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
