//
//  RankingsListView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import SwiftUI

internal struct RankingsListView: View {
    
    let players: [RankedPlayer]
    @Binding var selectedKey: PlayerStats.ID?
    let onShowInLibrary: (PlayerStats.ID) -> Void
    
    var body: some View {
        Table(players, selection: $selectedKey) {
            TableColumn("Rank") { player in
                Text("\(player.rank)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(44)
            TableColumn("Player") { player in
                // Rank travels in the identifier so the UI test pins the
                // ladder's computed *order* without geometry queries.
                Text(player.stats.name)
                    .accessibilityIdentifier(
                        AccessibilityID.rankingRow(player.rank, player.stats.name)
                    )
            }
            TableColumn("Wins") { player in
                Text("\(player.stats.wins)")
            }
            .width(50)
            TableColumn("Win %") { player in
                Text(player.stats.winRate.formatted(.percent.precision(.fractionLength(0))))
                    .foregroundStyle(.secondary)
            }
            .width(60)
            TableColumn("Games") { player in
                Text("\(player.stats.games)").foregroundStyle(.secondary)
            }
            .width(60)
            TableColumn("Rating") { player in
                Text(player.rating?.displaySummary ?? "—")
                    .foregroundStyle(.secondary)
            }
            .width(120)
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
        .accessibilityIdentifier(AccessibilityID.rankingsTable)
    }
}

// MARK: Previews

#Preview("Ladder") {
    @Previewable @State var selection: PlayerStats.ID?
    
    RankingsListView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKey: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 760, height: 320)
}

/// The provisional/unrated column states: the newcomer's single game leaves
/// RD above the D11′ threshold, and an unrated row renders the nil branch.
#Preview("Provisional & Unrated") {
    @Previewable @State var selection: PlayerStats.ID?
    
    let ranked = PreviewFixtures.rankedPlayers()
    let unrated = ranked.map { RankedPlayer(rank: $0.rank, stats: $0.stats, rating: nil) }
    
    RankingsListView(
        players: ranked + unrated.suffix(1),
        selectedKey: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 760, height: 320)
}

#Preview("Empty") {
    @Previewable @State var selection: PlayerStats.ID?
    
    RankingsListView(players: [], selectedKey: $selection, onShowInLibrary: { _ in })
        .frame(width: 760, height: 320)
}
