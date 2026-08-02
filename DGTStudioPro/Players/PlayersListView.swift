//
//  PlayersListView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import SwiftUI

internal struct PlayersListView: View {

    let players: [RankedPlayer]
    /// A set since 2 Aug 2026 (the Library's selection model, adopted):
    /// `Table` gives ⌘/⇧-click multi-select for free once the binding
    /// allows it.
    @Binding var selectedKeys: Set<PlayerStats.ID>
    let onShowInLibrary: (PlayerStats.ID) -> Void

    var body: some View {
        Table(players, selection: $selectedKeys) {
            TableColumn("Rank") { player in
                // The rank cell carries the order-pinning identifier
                // (`rankingRow.1.Liren Ding`) so the ladder UITest asserts
                // the computed order without geometry queries; the Player
                // cell keeps `playerRow(name)` for the rename/merge flows.
                // Two cells, two currencies — one element can't serve both.
                Group {
                    if RankMedal(rank: player.rank) != nil {
                        RankBadge(rank: player.rank)
                    } else {
                        Text("\(player.rank)").monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier(
                    AccessibilityID.rankingRow(player.rank, player.stats.name)
                )
            }
            .width(52)
            TableColumn("Player") { player in
                Text(player.stats.name)
                    .accessibilityIdentifier(AccessibilityID.playerRow(player.stats.name))
            }
            TableColumn("Games") { player in
                Text("\(player.stats.games)").foregroundStyle(.secondary)
            }
            .width(60)
            TableColumn("W") { Text("\($0.stats.wins)") }.width(40)
            TableColumn("D") { Text("\($0.stats.draws)").foregroundStyle(.secondary) }.width(40)
            TableColumn("L") { Text("\($0.stats.losses)").foregroundStyle(.secondary) }.width(40)
            TableColumn("Win %") { player in
                Text(player.stats.winRate.formatted(.percent.precision(.fractionLength(0))))
                    .foregroundStyle(.secondary)
            }
            .width(60)
            TableColumn("Rating") { player in
                Text(player.rating?.displaySummary ?? "—")
                    .foregroundStyle(.secondary)
            }
            .width(120)
            TableColumn("Last Played") { player in
                Text(RosterSummary.displayDate(player.stats.lastPlayed))
                    .foregroundStyle(.secondary)
            }
            .width(100)
        }
        .contextMenu(forSelectionType: PlayerStats.ID.self) { keys in
            if let key = keys.first {
                Button {
                    onShowInLibrary(key)
                } label: {
                    Label("Show in Library", systemImage: "books.vertical")
                }
                .accessibilityIdentifier(AccessibilityID.contextShowInLibrary)
            }
        }
        .accessibilityIdentifier(AccessibilityID.playersTable)
    }
}

// MARK: Previews

#Preview("With Players") {
    @Previewable @State var selection: Set<PlayerStats.ID> = []

    PlayersListView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 320)
}

#Preview("Selected Row") {
    @Previewable @State var selection: Set<PlayerStats.ID> = [PreviewFixtures.topStats().id]

    PlayersListView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 320)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PlayerStats.ID> = []

    PlayersListView(players: [], selectedKeys: $selection, onShowInLibrary: { _ in })
        .frame(width: 720, height: 320)
}
