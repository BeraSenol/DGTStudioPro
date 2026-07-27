//
//  LibraryFilter.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import Foundation
import SwiftData

/// What the Library is currently narrowed to (M-prs.5): a smart tag or a
/// player — one filter seam for both, built once against final types
/// (which is exactly why it waited for this slice instead of wrapping
/// the old enum and swapping payloads later). Holds live models, so it
/// stays inside the `@MainActor` view layer; the pure logic it fronts is
/// `TagRule.evaluate` and the resolved-link comparison.
internal enum LibraryFilter {
    case smartTag(SmartTag)
    case player(Player)

    internal func matches(_ pgn: PGN) -> Bool {
        switch self {
        case .smartTag(let tag):
            return tag.matches(pgn.gameRecord)
        case .player(let player):
            // Resolved links, never raw tags — the M-prs.1 identity door.
            return pgn.whitePlayer?.persistentModelID == player.persistentModelID
            || pgn.blackPlayer?.persistentModelID == player.persistentModelID
        }
    }

    /// For the filter chip and window titles (M-prs.6 wires the chip).
    internal var displayName: String {
        switch self {
        case .smartTag(let tag):  tag.name
        case .player(let player): player.name
        }
    }

    /// The chip's prefix — so "Blitz" the tag and a hypothetical player
    /// named "Blitz" never render identically.
    internal var kindLabel: String {
        switch self {
        case .smartTag: "Tag"
        case .player:   "Player"
        }
    }

    /// The chip's and the filtered empty state's icon.
    internal var systemImage: String {
        switch self {
        case .smartTag: "tag"
        case .player:   "person"
        }
    }
}
