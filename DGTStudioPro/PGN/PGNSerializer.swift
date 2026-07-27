//
//  PGNSerializer.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/07/2026.
//

import Foundation

/// Writes a game back out in the DGT reference shape (D17′/D24′), byte for
/// byte. The format is pinned to the three reference exports the user
/// interchanges — `1. Bera vs Reinaud.pgn` and its siblings — not to the
/// parser's internal movetext form, so the suite round-trips those files:
/// import → serialize → identical bytes.
///
/// Read off the files rather than off the standard; where they differ, the
/// files win:
/// - **Nine tags, fixed order** — the Seven Tag Roster, then `Board`, then
///   `TimeControl`. Always all nine: a missing value prints PGN's own
///   unknown vocabulary (`?`, `????.??.??`, `-`) rather than dropping the
///   line, so the tag block is a constant shape and a diff between two
///   exports is about the game, not about which tags happened to be set.
/// - **LF line endings**, not CRLF. The reference files are LF, the app is
///   macOS-only, and the parser accepts both (its own line-ending note), so
///   the asymmetry costs nothing on re-import.
/// - **One full move per line**, with a white-only final line when the game
///   ends on White's move. No 80-column wrapping.
/// - **The result alone on the last line**, then a single trailing newline.
///
/// Moves are emitted **verbatim**: the parser strips only `!`/`?`, so check
/// and mate suffixes are already stored (`GameRecord.endedInMate` depends on
/// it) and there is nothing to re-derive. Stored evaluations are deliberately
/// **not** written — the reference shape has no `{[%eval ...]}` comments, and
/// an export that grew them would stop matching the files this format exists
/// to match.
///
/// Rejected: emitting only the tags that carry values (shape becomes
/// data-dependent), and the standard's 80-column export wrapping (the
/// reference files don't wrap).
internal enum PGNSerializer {
    
    // MARK: Placeholders
    
    private static let unknownTag = RosterSummary.unknownTag
    private static let noTimeControl = "-"
    
    // MARK: Text
    
    /// `RosterSummary` is the seven-tag value carrier here, **not** its own
    /// renderer: this reads its stored properties, because export needs the
    /// raw `"Senol, Bera"` the file carries. `subscript(_:)` — which applies
    /// `PlayerName.displayForm(of:)` — belongs to the sidebars.
    internal static func text(
        roster: RosterSummary,
        board: String?,
        timeControl: String?,
        moves: [String]
    ) -> String {
        var out = ""
        // The seven, in the standard's order, from the enum that owns it —
        // so an eighth roster tag is a compile error at `tagValue(for:)`
        // rather than a line that quietly stops being written. `Board` and
        // `TimeControl` follow because D24′ pins them there, outside the
        // roster.
        for tag in SevenTagRoster.allCases {
            out += self.tag(tag.rawValue, roster.tagValue(for: tag))
        }
        out += tag("Board",       board ?? unknownTag)
        out += tag("TimeControl", timeControl ?? noTimeControl)
        out += tag("TimeControl", timeControl ?? noTimeControl)
        out += "\n"
        out += movetext(moves)
        out += "\(roster.result.rawValue)\n"
        return out
    }
    
    private static func tag(_ key: String, _ value: String) -> String {
        "[\(key) \"\(value)\"]\n"
    }
    
    /// One full move per line. A game ending on White's move gets a
    /// white-only final line ("39. Qxe1"), which is what the reference files
    /// do and what the parser reads back unchanged. Zero moves emit nothing
    /// at all — the blank line and the result still stand, which is the
    /// honest shape for an unplayed game.
    private static func movetext(_ moves: [String]) -> String {
        var lines: [String] = []
        var ply = 0
        while ply < moves.count {
            let black = ply + 1 < moves.count ? " \(moves[ply + 1])" : ""
            lines.append("\(ply / 2 + 1). \(moves[ply])\(black)")
            ply += 2
        }
        return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
    }
    
    // MARK: Filename
    
    /// The reference exports' filename shape: `1. Bera vs Reinaud.pgn` —
    /// the game's ordinal within the export, then the two players' **given**
    /// names in White-vs-Black order. Given names, not display names, is
    /// what those files do; over-the-board opponents are first names.
    internal static func fileName(white: String, black: String, index: Int) -> String {
        "\(index). \(givenName(white)) vs \(givenName(black)).pgn"
    }
    
    /// The leading token of the display form — "Senol, Bera" → "Bera Senol"
    /// → "Bera"; a single-token tag is its own given name. An empty or
    /// placeholder seat falls back to `?` rather than collapsing the name
    /// into " vs ".
    private static func givenName(_ rawTag: String) -> String {
        let first = PlayerName.displayForm(of: rawTag)
            .split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? unknownTag : sanitized(first)
    }
    
    /// `/` is illegal in an APFS filename and `:` is the legacy path
    /// separator Finder still remaps. Both become `-` rather than being
    /// dropped, so two players differing only there don't collide.
    private static func sanitized(_ component: String) -> String {
        component
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }
}
