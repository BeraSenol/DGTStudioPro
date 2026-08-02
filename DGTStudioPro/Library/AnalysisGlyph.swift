//
//  AnalysisGlyph.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 02/08/2026.
//

import Foundation

/// The analysis-state glyph (2 Aug 2026, retiring the state-blind
/// `wand.and.stars` everywhere): a gear with a checkmark for a game that
/// has been analyzed, a gear with an xmark for one that hasn't. One home
/// for both symbol names *and* for the predicate, because the glyph made a
/// latent fork visible: the inspector's Re-analyze keyed off
/// `evaluations.contains { $0 != nil }` while the search filter keyed off
/// `!evaluations.isEmpty` — different answers for a non-empty all-nil
/// array. Both now route here. (D33′'s bar/graph presence gate stays its
/// own `evaluations.isEmpty` deliberately: it asks "is there anything to
/// draw", not "did an analysis pass run".)
internal enum AnalysisGlyph {

    /// "Has been analyzed", spelled once: any ply carries a recorded
    /// evaluation.
    internal static func isAnalyzed(_ game: PGN) -> Bool {
        game.evaluations.contains { $0 != nil }
    }

    internal static func name(analyzed: Bool) -> String {
        analyzed ? "gear.badge.checkmark" : "gear.badge.xmark"
    }

    /// The per-game convenience the three single-game call sites read.
    internal static func name(for game: PGN) -> String {
        name(analyzed: isAnalyzed(game))
    }
}
