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

    /// M5's three operations, as closures rather than store reach.
    ///
    /// This view is pure-value by design — stats and rating arrive computed —
    /// and rename/merge/delete all need a resolved `Player`, a `modelContext`
    /// and somewhere to put a sheet. Handing it closures keeps that property
    /// intact: the destination already owns the context and the key→row bridge
    /// (`showInLibrary`'s route), so it owns these too, and the inspector
    /// stays previewable without a container.
    ///
    /// Defaulted so the three previews below and any future host can omit
    /// them; the app always wires all three.
    internal var onRename: () -> Void = {}
    internal var onMerge: () -> Void = {}
    internal var onDelete: () -> Void = {}

    /// Whether Delete can do anything for this player (D38′'s orphan guard).
    ///
    /// The store door refuses a linked player because `.nullify` plus the next
    /// `backfillPlayerLinks()` would recreate it; the menu says so up front
    /// rather than offering an item that reports failure. Computed from
    /// `recentGames` — the same games the section below lists, so the disabled
    /// state and the visible reason can't disagree.
    private var canDelete: Bool { recentGames.isEmpty }

    // MARK: Body
    internal var body: some View {
        // D26′ — empty renders outside the `List`; see `InspectorEmptyState`.
        if let stats {
            List {
                ProfileSection(
                    stats: stats,
                    rating: rating,
                    canDelete: canDelete,
                    onRename: onRename,
                    onMerge: onMerge,
                    onDelete: onDelete
                )
                .id(stats.key)   // reset per-player, the Library-inspector idiom
                RecentGamesSection(playerKey: stats.key, games: recentGames)
            }
            .listStyle(.sidebar)
        } else {
            emptyState
        }
    }
    
    // MARK: Instance Methods
    private var emptyState: some View {
        InspectorEmptyState(
            title: "No Player Selected",
            systemImage: "person.fill",
            message: "Select a player to view their profile and recent games.",
            identifier: AccessibilityID.playersInspectorEmpty
        )
    }
}

// MARK: Profile

private struct ProfileSection: View {

    let stats: PlayerStats
    let rating: Glicko1.Rating?
    let canDelete: Bool
    let onRename: () -> Void
    let onMerge: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Section {
            LabeledContent("Games", value: "\(stats.games)")
            LabeledContent("Win Rate", value: stats.winRate.formatted(.percent.precision(.fractionLength(0))))
            LabeledContent("Mates Delivered", value: "\(stats.matesDelivered)")
            LabeledContent("First Played", value: RosterSummary.displayDate(stats.firstPlayed))
            LabeledContent("Last Played", value: RosterSummary.displayDate(stats.lastPlayed))
            LabeledContent("Rating", value: ratingDescription)
        } header: {
            // The player's name, not "Player Profile" — the destination
            // already says what kind of thing this is, and the header is the
            // one place that can say *which*. The monogram-and-name row this
            // replaces was the same name twice once the header carried it;
            // the monogram stays where it identifies something the reader is
            // choosing between, on the cards and rows.
            InspectorSectionHeader(stats.name) {
                // Two controls, the Library inspector's PGN-header shape: the
                // D26′ pencil keeps its one fixed meaning (edit *this* thing's
                // name), and everything that isn't a rename lives in a menu
                // beside it. Widening the pencil to also merge and delete
                // would turn a named affordance into a generic icon button and
                // lose the guarantee three inspectors' pencils currently give.
                HStack(spacing: 12) {
                    InspectorEditButtonView(
                        label: "Rename Player",
                        identifier: AccessibilityID.playersRenameButton,
                        action: onRename
                    )
                    actionsMenu
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.playersInspectorProfile)
    }

    private var actionsMenu: some View {
        Menu {
            Button("Merge Into…", action: onMerge)
                .accessibilityIdentifier(AccessibilityID.playersMergeMenuItem)
            Divider()
            Button("Delete Player", role: .destructive, action: onDelete)
                .disabled(!canDelete)
                .accessibilityIdentifier(AccessibilityID.playersDeleteMenuItem)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        // `InspectorEditButtonView`'s reason: a glyph at header font size is
        // an ~11 pt mouse target.
        .font(.body)
        .help(canDelete ? "Merge or delete this player" : "Merge this player")
        .accessibilityIdentifier(AccessibilityID.playersActionsMenu)
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
