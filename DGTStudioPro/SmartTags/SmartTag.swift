//
//  SmartTag.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 04/05/2026.
//

import SwiftUI

internal enum SmartTag: String, CaseIterable, Identifiable {
    case checkmate
    case timeControlled
    case firstRound

    internal var id: String { rawValue }

    internal var displayName: String {
        switch self {
        case .checkmate:       return "Checkmate"
        case .timeControlled:  return "Timed"
        case .firstRound:      return "First Round"
        }
    }

    internal var systemImage: String {
        switch self {
        case .checkmate:       return "crown"
        case .timeControlled:  return "clock"
        case .firstRound:      return "1.circle"
        }
    }

    internal var color: Color {
        switch self {
        case .checkmate:       return .red
        case .timeControlled:  return .orange
        case .firstRound:      return .blue
        }
    }

    internal func matches(_ pgn: PGN) -> Bool {
        switch self {
        case .checkmate:
            return pgn.moves.last?.hasSuffix("#") == true
        case .timeControlled:
            return pgn.timeControl != nil
        case .firstRound:
            return pgn.round == 1
        }
    }
}
