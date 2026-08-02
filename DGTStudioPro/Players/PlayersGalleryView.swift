//
//  PlayersGalleryView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import SwiftUI

internal struct PlayersGalleryView: View {
    
    let players: [RankedPlayer]
    @Binding var selectedKey: PlayerStats.ID?
    let onShowInLibrary: (PlayerStats.ID) -> Void

    private var selectedPlayer: RankedPlayer? {
        guard let selectedKey else { return nil }
        return players.first { $0.id == selectedKey }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            preview
            Divider()
            filmstrip
        }
    }
    
    @ViewBuilder
    private var preview: some View {
        if let player = selectedPlayer ?? players.first {
            VStack(spacing: 12) {
                PlayerMonogram(name: player.stats.name, diameter: 96)
                HStack(spacing: 8) {
                    // The retired Rankings gallery's identity row, kept: the
                    // rank is the destination's default sort and earns the
                    // medal styling beside the name.
                    Text("#\(player.rank)")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(RankMedal.style(forRank: player.rank))
                    Text(player.stats.name)
                        .font(.title2.weight(.semibold))
                }

                // One grid, each fact once (D48′), shared since the columns
                // redesign made a second host — see `PlayerStatsGrid` for
                // the history this extraction closes.
                PlayerStatsGrid(stats: player.stats, rating: player.rating)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "person.crop.circle.dashed",
                description: Text("Select a player to preview.")
            )
        }
    }

    private var filmstrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(players) { player in
                        PlayerCardView(
                            stats: player.stats,
                            isSelected: selectedKey == player.id,
                            onSelect: { selectedKey = player.id },
                            rank: player.rank,
                            onShowInLibrary: { onShowInLibrary(player.id) }
                        )
                        .frame(width: 160)
                        .id(player.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 170)
            .background(.thinMaterial)
            .onChange(of: selectedKey) { _, newKey in
                guard let newKey else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newKey, anchor: .center)
                }
            }
        }
    }
}

// MARK: Previews

#Preview("With Players") {
    @Previewable @State var selection: PlayerStats.ID?
    
    PlayersGalleryView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKey: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 420)
}

#Preview("Empty") {
    @Previewable @State var selection: PlayerStats.ID?
    
    PlayersGalleryView(players: [], selectedKey: $selection, onShowInLibrary: { _ in })
        .frame(width: 720, height: 420)
}

#Preview("Gallery — Preselected") {
    @Previewable @State var selection: PlayerStats.ID? = PreviewFixtures.topStats().id
    
    PlayersGalleryView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKey: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 420)
}
