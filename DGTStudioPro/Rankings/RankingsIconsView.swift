//
//  RankingsIconsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import SwiftUI

internal struct RankingsIconsView: View {
    
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

#Preview("Ladder") {
    @Previewable @State var selection: PlayerStats.ID?
    
    RankingsIconsView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKey: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 860, height: 300)
}

/// The canvas is deliberately wide enough for a full row: wrapping only shows
/// itself with more players than one row holds, and a too-narrow canvas hides
/// the grid's real behaviour behind horizontal squeeze instead. The column
/// count and floor that decide what "a full row" is live in
/// `CollectionGridMetrics`.
#Preview("Wraps To Two Rows") {
    @Previewable @State var selection: PlayerStats.ID? = PreviewFixtures.topStats().id
    
    RankingsIconsView(
        players: PreviewFixtures.deepRankedPlayers(),
        selectedKey: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 860, height: 420)
}

#Preview("Empty") {
    @Previewable @State var selection: PlayerStats.ID?
    
    RankingsIconsView(players: [], selectedKey: $selection, onShowInLibrary: { _ in })
        .frame(width: 860, height: 300)
}
