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

    internal var name: String = ""
    internal var importedAt: Date
    internal var contentHash: String

    // MARK: Computed Properties
    internal var id: PersistentIdentifier { persistentModelID }

    internal var displayDate: String {
        guard let date else { return PGNPlaceholder.date.rawValue }
        return date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
    }

    internal var displayRound: String {
        guard let round else { return PGNPlaceholder.general.rawValue }
        return String(round)
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

    // MARK: Initializers
    internal init(
        event: String = PGNPlaceholder.general.rawValue,
        site: String = PGNPlaceholder.general.rawValue,
        date: Date? = nil,
        round: Int? = nil,
        white: String = PGNPlaceholder.general.rawValue,
        black: String = PGNPlaceholder.general.rawValue,
        moves: [String] = [],
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
