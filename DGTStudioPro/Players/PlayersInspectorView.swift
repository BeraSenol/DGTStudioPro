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
        ContentUnavailableView(
            "No Player Selected",
            systemImage: "person.fill",
            description: Text(
                "Select a player to view their profile and recent games."
            )
        )
    }
}

// MARK: Profile

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
    /// resolved — the `Glicko1.histories` rule); the number itself
    /// formats through the one shared rule.
    private var ratingDescription: String {
        rating?.displaySummary ?? "Unrated"
    }
}

// MARK: Recent Games

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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.name)
                        .lineLimit(1)
                    Text(game.displayDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(game.result.rawValue)
                    .font(.callout.weight(.semibold).monospaced())
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Previews

#Preview("Empty") {
    PlayersInspectorView(stats: nil, rating: nil, recentGames: [])
        .frame(width: 300, height: 400)
}

/// The two rating display branches meeting the same layout: an established
/// rating renders bare, a provisional one carries its qualifier and is the
/// longer string — the one that can wrap in a 260 pt inspector.
#Preview("Provisional Rating") {
    PlayersInspectorView(
        stats: PreviewFixtures.playerStats().last!,
        rating: Glicko1.Rating(mean: 1487.0, deviation: 218.6),
        recentGames: []
    )
    .frame(width: 260, height: 400)
    .modelContainer(for: PGN.self, inMemory: true)
}

/// Unrated: a resolved player whose games never produced a rated pairing.
/// The nil branch is the call site's own "Unrated" copy, per `Rating`'s doc.
#Preview("Unrated") {
    PlayersInspectorView(
        stats: PreviewFixtures.topStats(),
        rating: nil,
        recentGames: []
    )
    .frame(width: 300, height: 400)
    .modelContainer(for: PGN.self, inMemory: true)
}
