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

    /// Takes the record alongside the model since 7 Aug 2026, rather than
    /// projecting one per call.
    ///
    /// `pgn.gameRecord` decodes two Codable arrays off the model (`moves` and
    /// `evaluations`), and this ran once per game per render — so an active
    /// smart tag put two blob decodes per game on every keystroke, click and
    /// drag callback. The caller memoizes the projection now
    /// (`CollectionFoldKey`), which it can only do if the projection is passed
    /// in rather than taken here.
    ///
    /// **The record must be `pgn`'s own**, which is the trap the signature
    /// cannot state: handing over a mismatched pair type-checks and silently
    /// filters the Library against the wrong game. The one caller zips the two
    /// arrays it already holds in the same order.
    ///
    /// The `.player` arm ignores the record deliberately — a link comparison
    /// is the M-prs.1 identity door and a projection would flatten it back to
    /// the raw tags that door exists to bypass.
    internal func matches(_ pgn: PGN, record: GameRecord) -> Bool {
        switch self {
        case .smartTag(let tag):
            return tag.matches(record)
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
