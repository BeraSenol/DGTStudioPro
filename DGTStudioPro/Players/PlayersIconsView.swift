//
//  PlayersIconsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import SwiftUI

internal struct PlayersIconsView: View {
    
    // MARK: Static Constants
    private static let columnCount = 6
    private static let columnSpacing: CGFloat = 16
    
    // MARK: Stored Properties
    let players: [PlayerStats]
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
                        stats: player,
                        isSelected: selectedKey == player.key,
                        onSelect: { selectedKey = player.key },
                        onShowInLibrary: { onShowInLibrary(player.key) }
                    )
                }
            }
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
