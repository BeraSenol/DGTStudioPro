//
//  PGN.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 15/04/2026.
//

import Foundation
import SwiftData

internal enum GameResult: String, Codable {
    case whiteWins = "1-0"
    case blackWins = "0-1"
    case draw      = "1/2-1/2"
    case ongoing   = "*"
}

private enum PGNPlaceholder: String, Codable {
    case general = "?"
    case date  = "????.??.??"
}

@Model
internal final class PGN {
    
    // MARK: Stored Properties — Seven Tag Roster
    internal var event: String
    internal var site: String
    internal var date: Date?
    internal var round: Int?
    internal var white: String
    internal var black: String
    internal var result: GameResult
    
    // MARK: Stored Properties — Metadata
    internal var importedAt: Date
    
    // MARK: Computed Properties
    internal var displayDate: String {
        guard let date else { return PGNPlaceholder.date.rawValue }
        return date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
    }
    
    internal var displayRound: String {
        guard let round else { return PGNPlaceholder.general.rawValue }
        return String(round)
    }
    
    // MARK: Initializers
    internal init(
        event: String = PGNPlaceholder.general.rawValue,
        site: String = PGNPlaceholder.general.rawValue,
        date: Date? = nil,
        round: Int? = nil,
        white: String = PGNPlaceholder.general.rawValue,
        black: String = PGNPlaceholder.general.rawValue,
        result: GameResult = .ongoing
    ) {
        self.event = event
        self.site = site
        self.date = date
        self.round = round
        self.white = white
        self.black = black
        self.result = result
        self.importedAt = .now
    }
}
