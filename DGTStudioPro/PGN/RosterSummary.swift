import Foundation

/// One game's Seven Tag Roster, ready for a sidebar (D22′).
///
/// The point is the *set*. PGN defines Event, Site, Date, Round, White, Black
/// and Result as one mandatory unit, so every surface that shows the roster
/// shows all seven, in the standard's order, formatted identically. Before
/// this type the Board inspector showed four of them and formatted `Round`
/// itself, while the live inspector carried its own copies of `displayDate`
/// and `displayRound` — the same six lines as `PGN`'s, free to drift.
///
/// Values are stored in **tag form**, not display form: `white`/`black` keep
/// the "Last, First" the PGN carries and `date`/`round` stay typed, because
/// the same values feed `GameHeadline` and the content hash: storage stays
/// raw and `PlayerName.displayForm(of:)` applies at the render boundary.
/// `subscript(_:)` is therefore the single place the display rules live,
/// which also makes the placeholder contract testable without a model or a
/// container. (D23′ made the transform idempotent, so a second application
/// is no longer a correctness trap — rendering once, here, is still the
/// shape, but it is no longer load-bearing.)
internal struct RosterSummary: Equatable, Sendable {
    
    // MARK: Placeholders
    
    /// An unset tag, in PGN's own vocabulary. Distinct from the section's
    /// "no game at all" em-dash: `?` means this game doesn't say, `—` means
    /// there is no game to ask (the absent/corrupt distinction, applied to
    /// metadata).
    internal static let unknownTag = "?"
    internal static let unknownDate = "????.??.??"
    
    // MARK: Stored Properties
    
    internal let event: String
    internal let site: String
    internal let date: Date?
    internal let round: Int?
    internal let white: String
    internal let black: String
    internal let result: GameResult

    /// True only for the live projection — set by `init(_:result:)`, never by
    /// the `PGN` one.
    ///
    /// It exists for exactly one display rule: `*` is *true* while a game is
    /// being recorded and a *placeholder* everywhere else. Decision #3 says `*`
    /// never archives, so an archived game carrying one got it from the import
    /// door, which admits it deliberately — and there it means "this file
    /// didn't say", which is an unknown like any other. Same token, two
    /// meanings, and only the constructor knows which.
    ///
    /// A `var` with a default rather than a `let`: the synthesized memberwise
    /// init keeps its existing shape for every fixture and preview that builds
    /// a summary directly, so this field is additive rather than a call-site
    /// sweep.
    internal var isRecording: Bool = false


    // MARK: Display
    
    /// Every unknown, on every display surface, is this. One glyph — an em dash,
    /// not the PGN vocabulary and not a hyphen (D55′).
    ///
    /// The em dash is the app's existing house glyph: `OpeningSection` and
    /// `SevenTagRosterSection` already spelled "nothing to show" this way. The
    /// change was never about which mark but about there being *four* — `?`,
    /// `????.??.??`, `*`, `—` — on one panel, reading as four different kinds
    /// of problem. A hyphen was tried for one revision and lost, because an em
    /// dash is visibly a placeholder rather than possibly a value, which matters
    /// most beside `1-0` in a Result column.
    ///
    /// **This collapses a distinction D22′ drew on purpose**, and the collapse
    /// is the decision rather than a side effect. That entry kept `?` ("this
    /// game doesn't say") apart from the em dash ("there is no game to ask") —
    /// real, and invisible in use, since a reader sees one inspector at a time
    /// and cannot tell which question a glyph is answering.
    ///
    /// **Display only.** `tagValue(for:)` is untouched and must stay that way:
    /// D24′ pins export to the reference files byte for byte, where an unknown
    /// *is* `?`, a missing date *is* `????.??.??`, and `*` is a real result
    /// token. The two near-identical switches are exactly the duplication a
    /// future reader would collapse, which is why the split has its own pin.
    internal static let displayUnknown = "—"

    /// A stored tag value as it should be *shown* — the PGN unknown folded to
    /// the display glyph, everything else verbatim.
    private static func shown(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed == unknownTag ? displayUnknown : raw
    }

    /// The value for a tag, formatted for display. Reached by the section
    /// through `SevenTagRoster.allCases`, so adding a case to that enum is a
    /// compile error here — the roster cannot quietly lose a tag.
    internal subscript(tag: SevenTagRoster) -> String {
        switch tag {
        case .event:  Self.shown(event)
        case .site:   Self.shown(site)
        case .date:   Self.displayDate(date)
        case .round:  Self.displayRound(round)
        case .white:  Self.shown(PlayerName.displayForm(of: white))
        case .black:  Self.shown(PlayerName.displayForm(of: black))
        // `*` shows only while a game is actually being recorded, where it is
        // the truth — the game *is* ongoing. On an archived game the same
        // token came from the import door (Decision #3 admits it there and
        // refuses it at the archive door) and means "this file didn't say",
        // so it takes the placeholder like every other unknown.
        case .result: result == .ongoing && !isRecording ? Self.displayUnknown : result.rawValue
        }
    }
    
    /// The **stored** value for a tag — tag form, untransformed.
    ///
    /// D24′'s export shape needs `"Senol, Bera"`, not `"Bera Senol"`;
    /// `subscript(_:)` is the display renderer and belongs to the sidebars.
    /// That split used to live only in a comment on `PGNSerializer`, which
    /// hard-coded the seven tag names and so would have silently dropped an
    /// eighth. Driven from `allCases` on both sides, adding a roster case is
    /// now a compile error in the export path too.
    internal func tagValue(for tag: SevenTagRoster) -> String {
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
    
    /// The app's one short-date rendering. `PGN.displayDate` delegates here,
    /// the live inspector's private copy is gone, and the Players surfaces
    /// (list, inspector, gallery) route through it rather than each spelling
    /// `.dateTime.year().month(.twoDigits).day(.twoDigits)` again — five
    /// copies of one format, all identical, none of them the "one".
    internal static func displayDate(_ date: Date?) -> String {
        // `unknownDate` (`????.??.??`) stays as the *export* vocabulary and is
        // still what `PGNParser.pgnDateString` writes; this is the display
        // side, so it takes the one display glyph.
        guard let date else { return displayUnknown }
        return date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
    }

    internal static func displayRound(_ round: Int?) -> String {
        guard let round else { return displayUnknown }
        return String(round)
    }
}

// MARK: Projections

extension RosterSummary {
    
    /// The archived-game projection — the `PGN.gameRecord` seam pattern, kept
    /// here rather than in its own file because it's six lines and imports
    /// nothing (referencing the model type needs no SwiftData import, so
    /// purity holds).
    internal init(_ pgn: PGN) {
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
    
    /// The live projection. `Roster` carries six of the seven by design —
    /// the result lives on the game, because it changes while the roster
    /// doesn't (its own doc comment says so).
    ///
    /// Deliberately **not** `@MainActor`, which it carried until D44′ on the
    /// stated reason that `Roster` inherits `LiveGame`'s isolation by being
    /// nested inside it. That reason was false: a global actor isolates a
    /// type's *members*, never the types *nested* in it — SE-0449 spells out
    /// this exact shape. `Roster` is nonisolated, so the attribute bought
    /// nothing and cost this init the right to be called from anywhere.
    ///
    /// Worth knowing why it survived a month: every suite that builds a
    /// `Roster` is `@MainActor` already, for `LiveGame`'s sake, so no test
    /// ever had occasion to disprove it. A claim about the *language* is not
    /// checked by a green build unless something in the tree exercises it.
    internal init(_ roster: LiveGame.Roster, result: GameResult) {
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
