//
//  RosterSummary.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 23/07/2026.
//

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
    
    // MARK: Display
    
    /// The value for a tag, formatted. Reached by the section through
    /// `SevenTagRoster.allCases`, so adding a case to that enum is a
    /// compile error here — the roster can't quietly lose a tag.
    internal subscript(tag: SevenTagRoster) -> String {
        switch tag {
        case .event:  event
        case .site:   site
        case .date:   Self.displayDate(date)
        case .round:  Self.displayRound(round)
        case .white:  PlayerName.displayForm(of: white)
        case .black:  PlayerName.displayForm(of: black)
        case .result: result.rawValue
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
        guard let date else { return unknownDate }
        return date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
    }
    
    internal static func displayRound(_ round: Int?) -> String {
        guard let round else { return unknownTag }
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
    /// `@MainActor` because `Roster` is nested in a `@MainActor` class and
    /// inherits that isolation; the only caller is a view, so it costs
    /// nothing. If your build resolves `Roster` as nonisolated, dropping the
    /// attribute is a safe simplification.
    @MainActor
    internal init(_ roster: LiveGame.Roster, result: GameResult) {
        self.init(
            event:  roster.event,
            site:   roster.site,
            date:   roster.date,
            round:  roster.round,
            white:  roster.white,
            black:  roster.black,
            result: result
        )
    }
}
