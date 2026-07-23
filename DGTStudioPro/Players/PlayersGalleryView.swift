//
//  PlayersGalleryView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import SwiftUI

internal struct PlayersGalleryView: View {
    
    let players: [PlayerStats]
    @Binding var selectedKey: PlayerStats.ID?
    let onShowInLibrary: (PlayerStats.ID) -> Void
    
    private var selectedPlayer: PlayerStats? {
        guard let selectedKey else { return nil }
        return players.first { $0.key == selectedKey }
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
                PlayerMonogram(name: player.name, diameter: 96)
                Text(player.name)
                    .font(.title2.weight(.semibold))
                
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    GridRow {
                        statCell("Games", "\(player.games)")
                        statCell("Record", "\(player.wins)–\(player.draws)–\(player.losses)")
                        statCell("Win Rate", player.winRate.formatted(.percent.precision(.fractionLength(0))))
                    }
                    GridRow {
                        statCell("Mates", "\(player.matesDelivered)")
                        statCell("First", player.firstPlayed.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
                        statCell("Last", player.lastPlayed.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
                    }
                }
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
    
    private func statCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospacedDigit())
        }
    }
    
    private var filmstrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(players) { player in
                        PlayerCardView(
                            stats: player,
                            isSelected: selectedKey == player.key,
                            onSelect: { selectedKey = player.key },
                            onShowInLibrary: { onShowInLibrary(player.key) }
                        )
                        .frame(width: 160)
                        .id(player.key)
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
    
    PlayersIconsView(          // → PlayersGalleryView / PlayersColumnsView
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

#Preview("Gallery — Preselected") {
    @Previewable @State var selection: PlayerStats.ID? = PreviewFixtures.topStats().id
    
    PlayersGalleryView(
        players: PreviewFixtures.playerStats(),
        selectedKey: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 420)
}
