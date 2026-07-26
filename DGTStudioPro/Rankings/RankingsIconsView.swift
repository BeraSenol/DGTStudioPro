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

/// Six fixed columns at a 120pt minimum, so wrapping only shows itself with
/// more players than one row holds — the width here is deliberately enough
/// for a full row, since a too-narrow canvas hides the grid's real behaviour
/// behind horizontal squeeze instead.
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
