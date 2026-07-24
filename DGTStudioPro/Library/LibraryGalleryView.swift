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
    let onExport: (PGN) -> Void
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
    
    /// Selection-driven with no fallback to `games.first`: an unselected
    /// gallery shows an empty board rather than silently previewing a game
    /// the user didn't pick. (Retires the old `ContentUnavailableView` arm,
    /// which was unreachable — `LibraryDestination` gates on
    /// `filteredGames.isEmpty` before the mode views are ever built.)
    private var preview: some View {
        LibraryGamePreviewView(game: selectedPGN, boardStyle: boardStyle)
    }
    
    private var thumbnailStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(games) { game in
                        thumbnail(for: game).id(game.id)
                    }
                }
                .padding()
            }
            .frame(height: 180)
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
            onExport:  { onExport(game) },
            onDelete:  { onDelete(game) }
        )
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
        onExport: { _ in },
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

#Preview("No Selection") {
    @Previewable @State var selection: Set<PGN.ID> = []
    
    LibraryGalleryView(
        games: galleryPreviewGames(),
        selectedPGNs: $selection,
        boardStyle: .rosewood,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 720, height: 600)
    .modelContainer(for: PGN.self, inMemory: true)
}
