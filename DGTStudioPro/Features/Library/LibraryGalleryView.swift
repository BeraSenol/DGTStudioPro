import SwiftData
import SwiftUI

/// The Library gallery: a board preview of the selected game over a filmstrip of cards. The
/// scaffold - focus, ← / → stepping, scroll-sync, the strip itself - is `FilmstripGalleryView`'s;
/// what is here is the preview pane and the card's four verbs.
struct LibraryGalleryView: View {

    // MARK: Stored Properties
    let games: [PGN]
    /// The badge's input, off the memoized projection (see `LibraryIconsView.analyzedIDs`).
    let analyzedIDs: Set<PGN.ID>
    @Binding var selectedPGNs: Set<PGN.ID>
    let boardStyle: BoardStyle
    /// **Currently unreached from this gallery**, the icons grid's twin - both doors on the card
    /// route to `onOpenInPlace`. Noted 18 Aug 2026, not changed by that pass; the grid's property
    /// carries the full account.
    let onOpen: ([PGN]) -> Void
    /// Double-click's door (17 Aug 2026): this tab, not a new one.
    var onOpenInPlace: (PGN) -> Void = { _ in }
    let onAnalyze: (PGN) -> Void
    let onExport: (PGN) -> Void
    let onDelete: (PGN) -> Void

    // MARK: Private Properties

    /// Ambient - `LibraryIconsView`'s twin, argued at the environment value.
    @Environment(\.analysisRunningGameID) private var runningAnalysisID

    private var selectedPGN: PGN? {
        guard let id = selectedPGNs.first else { return nil }
        return games.first(where: { $0.id == id })
    }

    // MARK: Body
    var body: some View {
        FilmstripGalleryView(
            items: games,
            selection: $selectedPGNs,
            metrics: .library
        ) {
            // Selection-driven, no `games.first` fallback: an unselected gallery shows an empty
            // board - never preview what the user didn't pick.
            LibraryGamePreviewView(game: selectedPGN, boardStyle: boardStyle)
        } card: { game, isSelected, select in
            LibraryGameCardView(
                game: game,
                analysisState: AnalysisGlyph.state(
                    of: game,
                    isAnalyzed: analyzedIDs.contains(game.id),
                    runningID: runningAnalysisID
                ),
                isSelected: isSelected,
                onSelect:  select,
                onOpen:    { onOpenInPlace(game) },
                onAnalyze: { onAnalyze(game) },
                onExport:  { onExport(game) },
                onDelete:  { onDelete(game) }
            )
        }
    }
}

// MARK: Previews

#Preview("With Selection") {
    @Previewable @State var selection: Set<PGN.ID> = []

    let games = LibraryPreviewFixtures.games(3)

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
        games: LibraryPreviewFixtures.games(3),
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
