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
    
    // MARK: Private Properties

    /// The grids' focus arrangement (4 Aug 2026): the gallery itself is the
    /// focusable, a thumbnail click hands it focus, and ← / → step the strip.
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            preview
            Divider()
            thumbnailStrip
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onMoveCommand { direction in
            move(direction)
        }
    }

    /// ← / → step the filmstrip; ↑ / ↓ hold (4 Aug 2026). The stepping is
    /// `IconGridSelection.destination` in its **one-row degenerate case** —
    /// `columnCount == count` — so the strip speaks the exact grammar the
    /// icons grids speak rather than a fourth hand-rolled ±1: left/right
    /// clamp at the ends (a strip has no next row to wrap onto), and the
    /// vertical keys hold via the top-row and last-row guards. No anchor
    /// state, unlike the grids: the previewed card *is* the anchor, and with
    /// nothing selected the first arrow lands on the first card. The strip's
    /// own `.onChange(of:)` scroll-to does the rest.
    private func move(_ direction: MoveCommandDirection) {
        guard !games.isEmpty else { return }
        let target: Int
        if let id = selectedPGNs.first,
           let current = games.firstIndex(where: { $0.id == id }) {
            target = IconGridSelection.destination(
                from: current,
                direction: direction,
                columnCount: games.count,
                count: games.count
            )
        } else {
            target = 0
        }
        selectedPGNs = [games[target].id]
    }
    
    /// Selection-driven with no fallback to `games.first`: an unselected
    /// gallery shows an empty board rather than silently previewing a game
    /// the user didn't pick. (Retires the old `ContentUnavailableView` arm,
    /// which was unreachable — `LibraryDestination` gates on
    /// `filteredGames.isEmpty` before the mode views are ever built.)
    /// `PlayersGalleryView` adopted this rule on 4 Aug 2026, closing the
    /// last gallery parity residue.
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
            // 260 fits the card at its ideal height — the now-rigid glyph
            // block (~138 pt with its padding), a three-line name, the date,
            // and the paddings (4 Aug 2026). 180 was the height that *caused*
            // the icon-vs-gallery size difference: the strip sized the card,
            // and the card's one flexible element was the symbol it exists
            // to show.
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
            onSelect:  { selectedPGNs = [game.id]; isFocused = true },
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
