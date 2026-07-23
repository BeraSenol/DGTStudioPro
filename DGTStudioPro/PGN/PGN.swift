//
//  PGN.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 15/04/2026.
//

import Foundation
import SwiftData

internal enum GameResult: String, CaseIterable, Codable {
    case whiteWins = "1-0"
    case blackWins = "0-1"
    case draw      = "1/2-1/2"
    case ongoing   = "*"
}

internal enum SevenTagRoster: String, CaseIterable, Sendable {
    case event  = "Event"
    case site   = "Site"
    case date   = "Date"
    case round  = "Round"
    case white  = "White"
    case black  = "Black"
    case result = "Result"
}

private enum PGNPlaceholder: String, Codable {
    case general = "?"
    case date  = "????.??.??"
}

@Model
internal final class PGN: Identifiable {
    
    // MARK: Stored Properties
    internal var event: String
    internal var site: String
    internal var date: Date?
    internal var round: Int?
    internal var white: String
    internal var black: String
    internal var result: GameResult
    internal var timeControl: String?
    
    internal var moves: [String]
    
    /// Engine evaluations parallel to ``moves``, indexed by ply. The element
    /// at index `i` is the evaluation of the position reached *after*
    /// `moves[i]` is played — matching the Lichess / Chess.com `[%eval ...]`
    /// PGN convention where the comment follows the move it scored.
    ///
    /// Invariant: this array is either empty (no analysis has ever been
    /// recorded for this game) or exactly the same length as ``moves``.
    /// Individual entries may be `nil` for plies that weren't analyzed.
    /// Use ``evaluation(atPly:)`` to read safely against both shapes.
    internal var evaluations: [Evaluation?] = []
    
    internal var name: String = ""
    internal var importedAt: Date
    internal var contentHash: String
    
    /// Resolved player identities for the `white`/`black` tags (M-prs.1),
    /// maintained exclusively by `PGNStore` — both doors, the backfill,
    /// and `applyEdit`. Optional because `"?"` placeholders resolve to no
    /// player, and rows predating the schema start nil until backfilled.
    /// Deliberately absent from `init`: a link assigned anywhere but the
    /// resolver would bypass the single creation door. Sibling of the
    /// one-hash rule: any edit to `white`/`black` outside
    /// `PGNStore.applyEdit` silently rots these links.
    internal var whitePlayer: Player?
    internal var blackPlayer: Player?
    
    // MARK: Computed Properties
    internal var id: PersistentIdentifier { persistentModelID }
    
    internal var displayDate: String {
        RosterSummary.displayDate(date)
    }
    
    internal var displayRound: String {
        RosterSummary.displayRound(round)
    }
    
    internal var whiteDisplayName: String {
        Self.displayPlayerName(white)
    }
    
    internal var blackDisplayName: String {
        Self.displayPlayerName(black)
    }
    
    /// Default `name` for a game with these players, in display form.
    /// Used both for new imports and the backfill comparison.
    internal var defaultDisplayName: String {
        "\(whiteDisplayName) vs \(blackDisplayName)"
    }
    
    /// Legacy `name` form for games imported before display-name support.
    /// Used by the backfill to recognize a stored default and rewrite it.
    internal var legacyDefaultName: String {
        "\(white) vs \(black)"
    }
    
    /// Whether `name` is a **stale stored default** that should be rewritten
    /// to `defaultDisplayName`. True only when the rewrite would change the
    /// value: an empty name, or a legacy raw-tag default whose display
    /// transform differs. Deliberately false when `name` already equals
    /// `defaultDisplayName` even if it also equals the legacy form — for
    /// comma-free players the raw and display forms coincide, so the old
    /// `name == legacyDefaultName` test false-positived on every freshly
    /// archived game (the archive door stores `defaultDisplayName`), logging
    /// a spurious backfill and dirtying the context with a no-op save (the
    /// 20 July field finding). Custom names match neither branch and survive.
    internal static func nameIsStaleDefault(
        storedName: String, white: String, black: String
    ) -> Bool {
        let legacyDefault = "\(white) vs \(black)"
        let displayDefault =
        "\(displayPlayerName(white)) vs \(displayPlayerName(black))"
        return (storedName.isEmpty || storedName == legacyDefault)
        && storedName != displayDefault
    }
    
    /// Instance form for the Library backfill's `filter(\.hasStaleDefaultName)`.
    internal var hasStaleDefaultName: Bool {
        Self.nameIsStaleDefault(storedName: name, white: white, black: black)
    }
    
    // MARK: Instance Methods
    /// Returns the evaluation recorded for the position reached after the
    /// move at `ply` is played, or `nil` if no analysis is present for
    /// that ply. Safe against both invariant shapes of ``evaluations`` —
    /// returns `nil` when the array is empty (no analysis ever run) or
    /// when the entry at that index is itself `nil`.
    internal func evaluation(atPly ply: Int) -> Evaluation? {
        guard ply >= 0, ply < evaluations.count else { return nil }
        return evaluations[ply]
    }
    
    // MARK: Initializers
    internal init(
        event: String = PGNPlaceholder.general.rawValue,
        site: String = PGNPlaceholder.general.rawValue,
        date: Date? = nil,
        round: Int? = nil,
        white: String = PGNPlaceholder.general.rawValue,
        black: String = PGNPlaceholder.general.rawValue,
        moves: [String] = [],
        evaluations: [Evaluation?] = [],
        name: String? = nil,
        result: GameResult = .ongoing,
        timeControl: String? = nil,
        contentHash: String = ""
    ) {
        self.event = event
        self.site = site
        self.date = date
        self.round = round
        self.white = white
        self.black = black
        self.result = result
        self.timeControl = timeControl
        self.moves = moves
        self.evaluations = evaluations
        self.name = name ?? "\(Self.displayPlayerName(white)) vs \(Self.displayPlayerName(black))"
        self.importedAt = .now
        self.contentHash = contentHash
    }
    
    // MARK: Static Methods
    /// Transforms a PGN-style "Last, First" player tag into "First Last" form
    /// for display. Inputs without a comma pass through unchanged. Multi-part
    /// first names are preserved ("Heylen, Christophe Maria" → "Christophe
    /// Maria Heylen"). Trailing whitespace and stray commas are trimmed.
    internal static func displayPlayerName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return trimmed }
        guard let commaIndex = trimmed.firstIndex(of: ",") else { return trimmed }
        
        let last = trimmed[..<commaIndex].trimmingCharacters(in: .whitespaces)
        let rest = trimmed[trimmed.index(after: commaIndex)...].trimmingCharacters(in: .whitespaces)
        
        if rest.isEmpty { return last }
        if last.isEmpty { return rest }
        return "\(rest) \(last)"
    }
}
