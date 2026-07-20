//
//  RankingsIconsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import SwiftUI

internal struct RankingsIconsView: View {
    
    // MARK: Static Constants
    private static let columnCount = 6
    private static let columnSpacing: CGFloat = 16
    
    // MARK: Stored Properties
    let players: [RankedPlayer]
    @Binding var selectedKey: PlayerStats.ID?
    let onShowInLibrary: (PlayerStats.ID) -> Void
    
    // MARK: Computed Properties
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 120), spacing: Self.columnSpacing),
            count: Self.columnCount
        )
    }
    
    // MARK: Body
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Self.columnSpacing) {
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
            .padding(16)
        }
    }
}
