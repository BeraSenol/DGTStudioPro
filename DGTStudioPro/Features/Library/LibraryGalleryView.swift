import SwiftData
import SwiftUI

struct LibraryGalleryView: View {
    let games: [PGN]
    /// The badge's input, off the memoized projection (see `LibraryIconsView.analyzedIDs`).
    let analyzedIDs: Set<PGN.ID>
    @Binding var selectedPGNs: Set<PGN.ID>
    let boardStyle: BoardStyle
    /// Takes the set — degenerate here: a gallery selection is single by construction.
    let onOpen: ([PGN]) -> Void
    let onAnalyze: (PGN) -> Void
    let onExport: (PGN) -> Void
    let onDelete: (PGN) -> Void
    
    private var selectedPGN: PGN? {
        guard let id = selectedPGNs.first else { return nil }
        return games.first(where: { $0.id == id })
    }
    
    // MARK: Private Properties

    /// The gallery itself is the focusable; a thumbnail click hands it focus, ← / → step the strip.
    @FocusState private var isFocused: Bool

    /// Ambient — `LibraryIconsView`'s twin, argued at the environment value.
    @Environment(\.analysisRunningGameID) private var runningAnalysisID

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
        // The whole gallery is the background target — almost no empty space to aim at; card menus win
        // over their own bounds.
        .contextMenu { ShowViewOptionsButton() }
    }

    /// ← / → step, ↑ / ↓ hold — `IconGridSelection.destination`'s one-row degenerate case
    /// (`columnCount == count`); the previewed card is the anchor.
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
    
    /// Selection-driven, no `games.first` fallback: an unselected gallery shows an empty board —
    /// never preview what the user didn't pick.
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
            // 180 fits the card at the filmstrip size — the strip sizes itself to the card, never the reverse.
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
            analysisState: AnalysisGlyph.state(
                of: game,
                isAnalyzed: analyzedIDs.contains(game.id),
                runningID: runningAnalysisID
            ),
            isSelected: selectedPGNs.contains(game.id),
            onSelect:  { selectedPGNs = [game.id]; isFocused = true },
            onOpen:    { onOpen([game]) },
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
        analyzedIDs: Set(games.prefix(1).map(\.id)),
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
        analyzedIDs: [],
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
