//
//  LibraryGalleryView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 29/04/2026.
//

import SwiftUI

internal struct LibraryGalleryView: View {
    let games: [PGN]
    @Binding var selectedPGNs: Set<PGN.ID>
    let boardStyle: BoardStyle
    let onDelete: (PGN) -> Void
    
    private var selectedPGN: PGN? {
        guard let id = selectedPGNs.first else { return nil }
        return games.first(where: { $0.id == id })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            preview
            Divider()
            thumbnailStrip
        }
    }
    
    @ViewBuilder
    private var preview: some View {
        if let game = selectedPGN ?? games.first {
            VStack(spacing: 16) {
                playerHeader(for: game)
                board
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "square.dashed",
                description: Text("Select a game to preview.")
            )
        }
    }
    
    private func playerHeader(for game: PGN) -> some View {
        VStack(spacing: 6) {
            Text(game.name)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(game.result.rawValue)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
    
    // TODO: replay `game.moves` to render the final position once the SAN
    // parser lands in Phase 7. Until then, show the starting position.
    private var board: some View {
        BoardView(
            position: .starting,
            pieceTracker: .starting,
            style: boardStyle,
            perspective: .white,
            lastMove: nil,
            checkSquare: nil,
            selectedSquare: nil
        )
        .frame(maxWidth: 600, maxHeight: 600)
    }
    
    private var thumbnailStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(games) { game in
                        thumbnail(for: game).id(game.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 140)
            .background(.thinMaterial)
            .onChange(of: selectedPGNs) { _, newSelection in
                guard let id = newSelection.first else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }
    
    private func thumbnail(for game: PGN) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            resultChip(game.result)
            Spacer(minLength: 0)
            Text(game.name)
                .font(.caption)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(width: 140, height: 110, alignment: .topLeading)
        .libraryGameCard(
            isSelected: selectedPGNs.contains(game.id),
            onSelect: { selectedPGNs = [game.id] },
            onDelete: { onDelete(game) }
        )
    }
}
