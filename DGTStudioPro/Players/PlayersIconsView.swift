//
//  PlayersIconsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import SwiftUI

internal struct PlayersIconsView: View {

    // MARK: Stored Properties
    let players: [RankedPlayer]
    @Binding var selectedKey: PlayerStats.ID?
    let onShowInLibrary: (PlayerStats.ID) -> Void

    // MARK: Body
    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: CollectionGridMetrics.columns,
                spacing: CollectionGridMetrics.spacing
            ) {
                ForEach(players) { player in
                    // Rank always rides the card (D48′) — in name order too,
                    // because the rank is a fact about the player, not about
                    // the current sort.
                    PlayerCardView(
                        stats: player.stats,
                        isSelected: selectedKey == player.id,
                        onSelect: { selectedKey = player.id },
                        rank: player.rank,
                        onShowInLibrary: { onShowInLibrary(player.id) }
                    )
                }
            }
            .padding(CollectionGridMetrics.inset)
        }
    }
}

// MARK: Previews

#Preview("With Players") {
    @Previewable @State var selection: PlayerStats.ID?

    PlayersIconsView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKey: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 420)
}

/// Wide enough for a full row — wrapping only shows itself with more players
/// than one row holds; the column count lives in `CollectionGridMetrics`.
#Preview("Wraps To Two Rows") {
    @Previewable @State var selection: PlayerStats.ID? = PreviewFixtures.topStats().id

    PlayersIconsView(
        players: PreviewFixtures.deepRankedPlayers(),
        selectedKey: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 860, height: 420)
}

#Preview("Empty") {
    @Previewable @State var selection: PlayerStats.ID?

    PlayersIconsView(players: [], selectedKey: $selection, onShowInLibrary: { _ in })
        .frame(width: 720, height: 420)
}
