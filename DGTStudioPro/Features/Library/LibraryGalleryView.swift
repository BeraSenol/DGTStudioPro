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
    /// The menu's new-tab door, reached since 23 Aug 2026 - the icons grid's twin, whose property
    /// carries the full account of the unreached years.
    let onOpen: ([PGN]) -> Void
    /// Double-click's door (17 Aug 2026): this tab, not a new one.
    var onOpenInPlace: (PGN) -> Void = { _ in }
    /// Set-taking since 23 Aug 2026, the icons grid's 17 Aug correction arriving here six days
    /// late: these were `(PGN) -> Void`, so a ⌘A'd gallery's card menu deleted one game of the
    /// selection - the exact "select all, delete all, it deletes one" shape the grid had already
    /// fixed, surviving in the mode nobody re-checked. Resolved through the same
    /// `IconGridSelection.subjects` rule.
    let onAnalyze: ([PGN]) -> Void
    let onExport: ([PGN]) -> Void
    let onDelete: ([PGN]) -> Void

    // MARK: Private Properties

    /// Ambient - `LibraryIconsView`'s twin, argued at the environment value.
    @Environment(\.analysisRunningGameID) private var runningAnalysisID

    /// The card's read, not the strip's - the icons grid's arrangement. The strip keeps its own
    /// card size; the inscription follows the same choice everywhere the card renders, because
    /// "what the sheet says" is a fact about the Library, not about a mode.
    @Environment(CollectionViewOptions.self) private var options

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
                inscription: options.libraryCardInscription,
                isSelected: isSelected,
                onSelect:  select,
                onOpen:    { onOpenInPlace(game) }
            )
            // Host-attached, the icons grid's arrangement - see its comment for the why. A card
            // menu wins over the gallery's own background `ShowViewOptionsButton` menu inside the
            // card's bounds, which is the scaffold's stated contract.
            .contextMenu {
                GameActionsMenu(
                    games: subjects(for: game),
                    onOpen: onOpen,
                    onAnalyze: onAnalyze,
                    onExport: onExport,
                    onDelete: onDelete
                )
            }
        }
    }

    /// Finder's rule, the icons grid's spelling - one shared implementation, ordered off `games`.
    /// A gallery selects one-at-a-time by gesture, but ⌘A binds the same set the grid's does, so
    /// the plural case is reachable here too.
    private func subjects(for game: PGN) -> [PGN] {
        IconGridSelection.subjects(for: game, in: games, selection: selectedPGNs)
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
    .environment(PreviewFixtures.viewOptions())
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
    .environment(PreviewFixtures.viewOptions())
    .modelContainer(for: PGN.self, inMemory: true)
}
