import Foundation

/// One game's Seven Tag Roster as a value - the *set* is the point: every surface shows
/// all seven, standard order, formatted identically. Values stored in **tag form**; display
/// happens once, in the subscript.
struct RosterSummary: Equatable, Sendable {
    
    // MARK: Placeholders
    
    /// An unset tag, in PGN's own vocabulary - export's word, not display's.
    static let unknownTag = "?"
    static let unknownDate = "????.??.??"
    
    // MARK: Stored Properties
    
    let event: String
    let site: String
    let date: Date?
    let round: Int?
    let white: String
    let black: String
    let result: GameResult

    /// True only for the live projection (`init(_:result:)` sets it; the `PGN` one never does).
    /// One display rule: `*` is *true* on a live game and an import-door unknown on a stored one -
    /// same token, two meanings, and only the constructor knows which.
    var isRecording: Bool = false


    // MARK: Display
    
    /// Every display unknown is this one glyph: `?`, `????.??.??` and an archived `*` all fold
    /// to it (four spellings on one panel read as four kinds of problem). A plain hyphen since
    /// 16 Aug 2026, Bera's call; it was the em dash before that, and the one-glyph rule is
    /// what mattered, not which glyph. **Display only:** `tagValue(for:)` is untouched and must
    /// stay so; export is pinned to reference bytes.
    static let displayUnknown = "-"

    /// A stored value as *shown* - PGN's unknown folded to the glyph, everything else verbatim.
    private static func shown(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed == unknownTag ? displayUnknown : raw
    }

    /// Display value per tag, reached through `SevenTagRoster.allCases` - a new case is a compile
    /// error here, so the roster cannot quietly lose a tag.
    subscript(tag: SevenTagRoster) -> String {
        switch tag {
        case .event:  Self.shown(event)
        case .site:   Self.shown(site)
        case .date:   Self.displayDate(date)
        case .round:  Self.displayRound(round)
        case .white:  Self.shown(PlayerName.displayForm(of: white))
        case .black:  Self.shown(PlayerName.displayForm(of: black))
        // `*` shows only while actually recording - there it is the truth; on an archived game the same
        // token means "this file didn't say" and takes the placeholder.
        case .result: result == .ongoing && !isRecording ? Self.displayUnknown : result.rawValue
        }
    }
    
    /// The **stored** value - tag form, untransformed: export needs "Senol, Bera". The
    /// display/export split is structural, not a comment (pinned).
    func tagValue(for tag: SevenTagRoster) -> String {
        switch tag {
        case .event:  event
        case .site:   site
        case .date:   PGNParser.pgnDateString(date)
        case .round:  round.map(String.init) ?? Self.unknownTag
        case .white:  white
        case .black:  black
        case .result: result.rawValue
        }
    }
    
    /// The app's one short-date rendering - five identical copies collapsed here.
    static func displayDate(_ date: Date?) -> String {
        // `????.??.??` stays the *export* vocabulary; this is display, so the one glyph.
        guard let date else { return displayUnknown }
        return date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
    }

    static func displayRound(_ round: Int?) -> String {
        guard let round else { return displayUnknown }
        return String(round)
    }
}

// MARK: Projections

extension RosterSummary {
    
    /// The archived-game projection; kept here - six lines, imports nothing, purity holds.
    init(_ pgn: PGN) {
        self.init(
            event:  pgn.event,
            site:   pgn.site,
            date:   pgn.date,
            round:  pgn.round,
            white:  pgn.white,
            black:  pgn.black,
            result: pgn.result
        )
    }
    
    /// The live projection; `Roster` carries six of seven (the result lives on the game).
    /// Deliberately **not** @MainActor: a global actor isolates a type's members, never
    /// nested types - pinned from the nonisolated side, where the claim would break.
    init(_ roster: LiveGame.Roster, result: GameResult) {
        self.init(
            event:  roster.event,
            site:   roster.site,
            date:   roster.date,
            round:  roster.round,
            white:  roster.white,
            black:  roster.black,
            result: result,
            isRecording: true
        )
    }
}
