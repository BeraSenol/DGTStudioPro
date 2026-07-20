//
//  PlayersInspectorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import SwiftData
import SwiftUI

/// The player profile (M-prs.3): pure-value inputs — stats and rating
/// arrive computed; only the recent-games list carries models, for the
/// `openWindow` handle. The rating row is D11′'s secondary stat in its
/// per-player home; the trend chart is the Rankings inspector's job
/// (M-prs.4).
internal struct PlayersInspectorView: View {

    // MARK: Stored Properties
    internal let stats: PlayerStats?
    internal let rating: Glicko1.Rating?
    internal let recentGames: [PGN]

    // MARK: Body
    internal var body: some View {
        List {
            if let stats {
                ProfileSection(stats: stats, rating: rating)
                    .id(stats.key)   // reset per-player, the Library-inspector idiom
                RecentGamesSection(playerKey: stats.key, games: recentGames)
            } else {
                emptySection
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: Instance Methods
    private var emptySection: some View {
        Section {
            Text("No player selected")
                .foregroundStyle(.secondary)
        } header: {
            Text("Player Profile")
        }
    }
}

// MARK: - Profile

private struct ProfileSection: View {

    let stats: PlayerStats
    let rating: Glicko1.Rating?

    var body: some View {
        Section {
            HStack(spacing: 12) {
                PlayerMonogram(name: stats.name, diameter: 44)
                Text(stats.name)
                    .font(.headline)
            }
            .padding(.vertical, 4)

            LabeledContent("Games", value: "\(stats.games)")
            LabeledContent("Record", value: "\(stats.wins)–\(stats.draws)–\(stats.losses)")
            LabeledContent("As White", value: "\(stats.whiteWins)–\(stats.whiteDraws)–\(stats.whiteLosses)")
            LabeledContent("As Black", value: "\(stats.blackWins)–\(stats.blackDraws)–\(stats.blackLosses)")
            LabeledContent("Win Rate", value: stats.winRate.formatted(.percent.precision(.fractionLength(0))))
            LabeledContent("Mates Delivered", value: "\(stats.matesDelivered)")
            LabeledContent("First Played", value: stats.firstPlayed.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
            LabeledContent("Last Played", value: stats.lastPlayed.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
            LabeledContent("Rating", value: ratingDescription)
        } header: {
            Text("Player Profile")
        }
        .accessibilityIdentifier(AccessibilityID.playersInspectorProfile)
    }

    /// "Unrated" until the player has a rated game (decided, both sides
    /// resolved — the `Glicko1.histories` rule); provisional while the
    /// deviation stays wide.
    private var ratingDescription: String {
        guard let rating else { return "Unrated" }
        let mean = Int(rating.mean.rounded())
        return rating.isProvisional ? "\(mean) (provisional)" : "\(mean)"
    }
}

// MARK: - Recent Games

private struct RecentGamesSection: View {

    let playerKey: String
    let games: [PGN]

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Section {
            if games.isEmpty {
                Text("No games")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(games.prefix(10)) { game in
                    row(for: game)
                }
                if games.count > 10 {
                    Text("and \(games.count - 10) more…")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("Recent Games")
        }
    }

    /// Row tap opens the game — the inspector's open affordance, same
    /// `openWindow(value:)` route as the Library inspector (macOS dedups
    /// and tabs the windows).
    private func row(for game: PGN) -> some View {
        Button {
            openWindow(value: game.persistentModelID)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.name)
                        .lineLimit(1)
                    Text(game.displayDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(perspectiveGlyph(for: game))
                    .font(.callout.weight(.semibold).monospaced())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The result from *this player's* seat: W/L/D, or the PGN's own `*`
    /// for ongoing. Seat is decided by the resolved link, never raw tags.
    private func perspectiveGlyph(for game: PGN) -> String {
        let isWhite = game.whitePlayer?.normalizedName == playerKey
        switch game.result {
        case .whiteWins: return isWhite ? "W" : "L"
        case .blackWins: return isWhite ? "L" : "W"
        case .draw:      return "D"
        case .ongoing:   return GameResult.ongoing.rawValue
        }
    }
}

// MARK: Previews
#Preview {
    PlayersInspectorView(stats: nil, rating: nil, recentGames: [])
        .frame(width: 300, height: 400)
}
