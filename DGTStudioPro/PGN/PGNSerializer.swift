import Foundation

/// Writes the DGT reference shape (D24′), byte for byte — pinned to the three reference files,
/// not the standard: LF endings; nine tags in fixed order (roster, `Board`, `TimeControl`); one
/// blank line; one full move per line with a white-only final line; result alone on the last
/// line; single trailing `\n`; no wrapping; evaluations and classification never written.
internal enum PGNSerializer {
    
    // MARK: Placeholders
    
    private static let unknownTag = RosterSummary.unknownTag
    private static let noTimeControl = "-"
    
    // MARK: Text
    
    /// `RosterSummary` is the value carrier, **not** its own renderer — export needs the raw
    /// `"Senol, Bera"`; the display subscript belongs to the sidebars.
    internal static func text(
        roster: RosterSummary,
        board: String?,
        timeControl: String?,
        moves: [String]
    ) -> String {
        var out = ""
        // The seven from the enum that owns the order — an eighth roster tag is a compile error, not a
        // line that quietly stops being written. Board and TimeControl follow (D24′).
        for tag in SevenTagRoster.allCases {
            out += self.tag(tag.rawValue, roster.tagValue(for: tag))
        }
        out += tag("Board",       board ?? unknownTag)
        out += tag("TimeControl", timeControl ?? noTimeControl)
        out += "\n"
        out += movetext(moves)
        out += "\(roster.result.rawValue)\n"
        return out
    }
    
    private static func tag(_ key: String, _ value: String) -> String {
        "[\(key) \"\(value)\"]\n"
    }
    
    /// One full move per line; a game ending on White's move gets a white-only final line. Zero
    /// moves emit nothing — blank line and result still stand.
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
    
    /// The reference filename shape: ordinal, then **given** names, White vs Black — given names is
    /// what those files do.
    internal static func fileName(white: String, black: String, index: Int) -> String {
        "\(index). \(givenName(white)) vs \(givenName(black)).pgn"
    }

    /// The reader half of `fileName` (D58′) — here because the type that owns a convention owns
    /// both directions. **Reads the ordinal and nothing else**: the folder uses full names where
    /// the writer uses given names, so verifying seats would reject exactly the files this reads.
    /// Requiring the period is the guard — `1961 Candidates.pgn` is a year, not game 1961.
    internal static func libraryIndex(fromFileName name: String) -> Int? {
        let digits = name.prefix { $0.isNumber }
        guard !digits.isEmpty,
              name.dropFirst(digits.count).first == "."
        else { return nil }
        return Int(digits)
    }
    
    /// The leading token of the display form ("Senol, Bera" → "Bera"); empty/placeholder falls back
    /// to `?` rather than collapsing into " vs ".
    private static func givenName(_ rawTag: String) -> String {
        let first = PlayerName.displayForm(of: rawTag)
            .split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? unknownTag : sanitized(first)
    }
    
    /// `/` is illegal on APFS and `:` the legacy separator — both become `-` so near-identical
    /// names don't collide.
    private static func sanitized(_ component: String) -> String {
        component
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }
}
