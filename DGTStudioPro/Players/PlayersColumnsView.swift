//
//  PlayersColumnsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import SwiftData
import SwiftUI

/// The Finder-column shape (2 Aug 2026 redesign, with `LibraryColumnsView`):
/// a flat list of players in the first column, the selected player's detail
/// filling the rest. The list follows `players`' own display order, so the
/// toolbar's Sort picker is what it obeys — rank order and name order both
/// arrive already sequenced, and the rank badge stays honest either way
/// because rank is computed under D11′ regardless of display order.
///
/// Replaces the grouped browser (letter / win-band buckets): the groups were
/// a navigation aid for a card grid, and the grid is gone. The win-band
/// table and the "a ranked list grouped alphabetically would fight its own
/// sort" argument went with it — that argument was about which grouping
/// vocabulary to use, and a flat list uses none.
///
/// The detail pane is the gallery's identity block plus what the extra room
/// buys: the shared `PlayerStatsGrid`, the Show in Library hop, and the
/// player's recent games — the same `recentGames` input the inspector
/// receives, so the two surfaces can't disagree about what "recent" means.
internal struct PlayersColumnsView: View {

    // MARK: Stored Properties
    let players: [RankedPlayer]
    /// A set since 2 Aug 2026 (the shared selection model); the list
    /// multi-selects, and the detail pane counts a plural selection the
    /// way `LibraryColumnsView`'s does.
    @Binding var selectedKeys: Set<PlayerStats.ID>
    /// The selected player's games, newest first — the destination's
    /// `selectedGames`, threaded exactly as `PlayersInspectorView` gets it.
    let recentGames: [PGN]
    let onShowInLibrary: (PlayerStats.ID) -> Void

    @Environment(\.openWindow) private var openWindow

    // MARK: Computed Properties

    /// Single or nothing — the detail pane details one thing (the
    /// `LibraryColumnsView` rule).
    private var selectedPlayer: RankedPlayer? {
        guard selectedKeys.count == 1, let key = selectedKeys.first else { return nil }
        return players.first { $0.id == key }
    }

    // MARK: Body
    var body: some View {
        HSplitView {
            playerList
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 340, maxHeight: .infinity)

            detail
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Instance Methods

    /// Two independent empty states that both have to hold, as before the
    /// redesign: the list takes its own "No players" arm rather than
    /// rendering an empty `List` — unreachable in production, where the
    /// destination gates on `players.isEmpty`, but previews build this view
    /// directly — and the detail pane shows its placeholder.
    @ViewBuilder
    private var playerList: some View {
        if players.isEmpty {
            VStack {
                Spacer()
                Text("No players")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            List(selection: $selectedKeys) {
                ForEach(players) { player in
                    row(for: player)
                        .tag(player.id)
                }
            }
            .listStyle(.plain)
        }
    }

    private func row(for player: RankedPlayer) -> some View {
        HStack(spacing: 8) {
            PlayerMonogram(name: player.stats.name, diameter: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(player.stats.name)
                    .lineLimit(1)
                Text("\(player.stats.games) games")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("#\(player.rank)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(RankMedal.style(forRank: player.rank))
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button {
                onShowInLibrary(player.id)
            } label: {
                Label("Show in Library", systemImage: "books.vertical")
            }
            .accessibilityIdentifier(AccessibilityID.contextShowInLibrary)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let player = selectedPlayer {
            playerDetail(player)
        } else if selectedKeys.count > 1 {
            // The multi-selection vocabulary every counting surface shares
            // (the Library columns pane, both inspectors' multi states).
            ContentUnavailableView(
                "\(selectedKeys.count) Players Selected",
                systemImage: "person.2.fill",
                description: Text("Select a single player to see their profile.")
            )
        } else {
            ContentUnavailableView(
                "No Player Selected",
                systemImage: "person.crop.circle.dashed",
                description: Text("Select a player in the list to see their profile and recent games.")
            )
        }
    }

    /// A scrolling profile, unlike the Library's fixed facts block: nothing
    /// here fights for aspect ratio the way a board does, and the recent
    /// games list is the part that grows.
    private func playerDetail(_ player: RankedPlayer) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                PlayerMonogram(name: player.stats.name, diameter: 96)

                // The gallery's identity row, kept in both hosts: the rank
                // is the destination's default sort and earns the medal
                // styling beside the name.
                HStack(spacing: 8) {
                    Text("#\(player.rank)")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(RankMedal.style(forRank: player.rank))
                    Text(player.stats.name)
                        .font(.title2.weight(.semibold))
                }

                PlayerStatsGrid(stats: player.stats, rating: player.rating)

                Button {
                    onShowInLibrary(player.id)
                } label: {
                    Label("Show in Library", systemImage: "books.vertical")
                }
                .help("Filter the Library to this player's games")

                Divider()
                    .frame(maxWidth: 420)

                recentGamesBlock
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    /// The inspector's recent-games rules, restated for this host: capped at
    /// ten with an "and N more…" tail, rows open the game via the same
    /// `openWindow(value:)` route (macOS dedups and tabs the windows). Two
    /// hosts' two decisions that agree today — the row is private on each
    /// side deliberately, the `OpeningSection` em-dash precedent, because
    /// one lives in a `List` section and one in a plain stack and a shared
    /// view would have to be generic over that difference.
    private var recentGamesBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Games")
                .font(.headline)

            if recentGames.isEmpty {
                Text("No games")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentGames.prefix(10)) { game in
                    gameRow(for: game)
                }
                if recentGames.count > 10 {
                    Text("and \(recentGames.count - 10) more…")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
    }

    private func gameRow(for game: PGN) -> some View {
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

#Preview("Selected") {
    @Previewable @State var selection: Set<PlayerStats.ID> = [PreviewFixtures.topStats().id]

    PlayersColumnsView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        recentGames: [
            PGN(event: "Test Open", site: "Memory", round: 1,
                white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian", result: .whiteWins),
            PGN(event: "Test Open", site: "Memory", round: 2,
                white: "Nepomniachtchi, Ian", black: "Carlsen, Magnus", result: .draw)
        ],
        onShowInLibrary: { _ in }
    )
    .frame(width: 860, height: 520)
    .modelContainer(for: PGN.self, inMemory: true)
}

/// The no-games branch of the detail — a selected player whose recent list
/// is empty renders "No games", not a collapsed void.
#Preview("Selected — No Games") {
    @Previewable @State var selection: Set<PlayerStats.ID> = [PreviewFixtures.topStats().id]

    PlayersColumnsView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        recentGames: [],
        onShowInLibrary: { _ in }
    )
    .frame(width: 860, height: 520)
    .modelContainer(for: PGN.self, inMemory: true)
}

/// The counting branch — a plural selection in the list, the state the
/// single-select columns could never render.
#Preview("Multi-Selection") {
    @Previewable @State var selection: Set<PlayerStats.ID> = Set(
        PreviewFixtures.rankedPlayers().prefix(2).map(\.id)
    )

    PlayersColumnsView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        recentGames: [],
        onShowInLibrary: { _ in }
    )
    .frame(width: 860, height: 520)
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("No Selection") {
    @Previewable @State var selection: Set<PlayerStats.ID> = []

    PlayersColumnsView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        recentGames: [],
        onShowInLibrary: { _ in }
    )
    .frame(width: 860, height: 520)
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PlayerStats.ID> = []

    PlayersColumnsView(
        players: [],
        selectedKeys: $selection,
        recentGames: [],
        onShowInLibrary: { _ in }
    )
    .frame(width: 860, height: 520)
}
