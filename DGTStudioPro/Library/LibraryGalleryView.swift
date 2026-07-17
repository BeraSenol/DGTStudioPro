//
//  LibraryGalleryView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 29/04/2026.
//

import SwiftData
import SwiftUI

internal struct LibraryGalleryView: View {
    let games: [PGN]
    @Binding var selectedPGNs: Set<PGN.ID>
    let boardStyle: BoardStyle
    let onOpen: (PGN) -> Void
    let onAnalyze: (PGN) -> Void
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
            LibraryGamePreviewView(game: game, boardStyle: boardStyle)
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "square.dashed",
                description: Text("Select a game to preview.")
            )
        }
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
            .frame(height: 160)
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
        LibraryGameCardView(
            game: game,
            isSelected: selectedPGNs.contains(game.id),
            onSelect:  { selectedPGNs = [game.id] },
            onOpen:    { onOpen(game) },
            onAnalyze: { onAnalyze(game) },
            onDelete:  { onDelete(game) }
        )
        .frame(width: 180)
    }
}

// MARK: Previews
private func galleryPreviewGames() -> [PGN] {
    [
        PGN(event: "World Championship", site: "Dubai", round: 11,
            white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian", result: .whiteWins),
        PGN(event: "Tata Steel Masters", site: "Wijk aan Zee", round: 7,
            white: "Giri, Anish", black: "Caruana, Fabiano", result: .draw),
        PGN(event: "Norway Chess", site: "Stavanger", round: 3,
            white: "Firouzja, Alireza", black: "Ding, Liren", result: .blackWins)
    ]
}

#Preview("With Selection") {
    @Previewable @State var selection: Set<PGN.ID> = []
    
    let games = galleryPreviewGames()
    
    LibraryGalleryView(
        games: games,
        selectedPGNs: $selection,
        boardStyle: .walnut,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 720, height: 600)
    .onAppear {
        // Pre-select the second game so selection styling shows.
        if let id = games.dropFirst().first?.id {
            selection = [id]
        }
    }
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("No Selection (Fallback to First)") {
    @Previewable @State var selection: Set<PGN.ID> = []
    
    LibraryGalleryView(
        games: galleryPreviewGames(),
        selectedPGNs: $selection,
        boardStyle: .rosewood,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 720, height: 600)
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PGN.ID> = []
    
    LibraryGalleryView(
        games: [],
        selectedPGNs: $selection,
        boardStyle: .walnut,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 720, height: 600)
    .modelContainer(for: PGN.self, inMemory: true)
}
