//
//  FEN+MoveGeneration.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/05/2026.
//

extension FEN {
    internal func legalMoves() -> [Move] {
        GameState(self).legalMoves()
    }
}
