import Foundation
import SwiftData

/// What the Library is narrowed to: a smart tag or a player - one filter seam for both.
enum LibraryFilter {
    case smartTag(SmartTag)
    case player(Player)

    /// Takes the record alongside the model, rather than projecting one per call (the memo pass).
    /// **The record must be `pgn`'s own** - a mismatched pair type-checks and silently filters on
    /// the wrong game's facts; the pairing is the caller's contract.
    func matches(_ pgn: PGN, record: GameRecord) -> Bool {
        switch self {
        case .smartTag(let tag):
            return tag.matches(record)
        case .player(let player):
            // Resolved links, never raw tags - the M-prs.1 identity door.
            return pgn.whitePlayer?.persistentModelID == player.persistentModelID
            || pgn.blackPlayer?.persistentModelID == player.persistentModelID
        }
    }

    /// The narrowing identity as a value: everything `matches` reads that can move without
    /// the games' content moving - a tag's rules are editable on the live model, and a rule edit
    /// must invalidate the narrow memo. A missed input here is stale rows on screen.
    struct Signature: Equatable {
        let tagID: PersistentIdentifier?
        let matchAll: Bool?
        let rules: [TagRule]?
        let playerID: PersistentIdentifier?
    }

    var signature: Signature {
        switch self {
        case .smartTag(let tag):
            Signature(
                tagID: tag.persistentModelID, matchAll: tag.matchAll,
                rules: tag.rules, playerID: nil
            )
        case .player(let player):
            Signature(
                tagID: nil, matchAll: nil,
                rules: nil, playerID: player.persistentModelID
            )
        }
    }

    /// For the filter chip and window titles (M-prs.6 wires the chip).
    var displayName: String {
        switch self {
        case .smartTag(let tag):  tag.name
        case .player(let player): player.name
        }
    }

    /// The chip's prefix - so "Blitz" the tag and a hypothetical player
    /// named "Blitz" never render identically.
    var kindLabel: String {
        switch self {
        case .smartTag: "Tag"
        case .player:   "Player"
        }
    }

    /// The chip's and the filtered empty state's icon.
    var systemImage: String {
        switch self {
        case .smartTag: "tag"
        case .player:   "person"
        }
    }
}
