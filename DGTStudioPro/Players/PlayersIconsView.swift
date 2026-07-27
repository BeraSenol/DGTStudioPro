//
//  PlayersIconsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import SwiftUI

internal struct PlayersIconsView: View {
    
    // MARK: Stored Properties
    let players: [PlayerStats]
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
                        stats: player,
                        isSelected: selectedKey == player.key,
                        onSelect: { selectedKey = player.key },
                        onShowInLibrary: { onShowInLibrary(player.key) }
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
        players: PreviewFixtures.playerStats(),
        selectedKey: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 420)
}

#Preview("Empty") {
    @Previewable @State var selection: PlayerStats.ID?
    
    PlayersIconsView(players: [], selectedKey: $selection, onShowInLibrary: { _ in })
        .frame(width: 720, height: 420)
}
