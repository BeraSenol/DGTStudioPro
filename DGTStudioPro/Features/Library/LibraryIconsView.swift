import SwiftData
import SwiftUI

/// The Library's icons grid - the card and its four verbs. Finder's two selection gestures (arrow
/// stepping and the rubber band), the frame observation and the focus chrome live in
/// `IconGridView`, which is the half that must not fork; this file is what makes the grid the
/// *Library's*.
struct LibraryIconsView: View {

    // MARK: Stored Properties
    let games: [PGN]
    /// Which games count as analyzed, off the memoized projection - never off the models, so
    /// a card render costs no blob decode.
    let analyzedIDs: Set<PGN.ID>
    @Binding var selectedPGNs: Set<PGN.ID>

    /// The menu's new-tab door - **reached again since 23 Aug 2026**: the menu moved off the card
    /// and onto this grid, and its Open item routes here with the whole subject set, exactly as
    /// the list's does. (From 17 to 23 Aug it was supplied and unreached - the card's own menu
    /// sent every door to `onOpenInPlace`, so an item labelled "Open in New Tabs" opened one game
    /// in place. The 18 Aug note recording that stood here.)
    let onOpen: ([PGN]) -> Void
    /// Double-click's door (17 Aug 2026): one game, into the tab the reader is already in.
    /// Defaulted so previews stand.
    var onOpenInPlace: (PGN) -> Void = { _ in }
    /// All three verbs take the set, resolved through `IconGridSelection.subjects` - Finder's rule
    /// for every card action, not just Open. They were `(PGN) -> Void` until 17 Aug 2026 and acted
    /// on one game however many were selected, while the list's `.contextMenu(forSelectionType:)`
    /// got the whole selection free - the "select all, delete all, it deletes one" report.
    let onAnalyze: ([PGN]) -> Void
    let onExport: ([PGN]) -> Void
    let onDelete: ([PGN]) -> Void

    // MARK: Private Properties

    /// Read here, not in `IconGridView`: the shared grid owns the gesture, the call site owns the
    /// card and therefore everything the card reads.
    @Environment(CollectionViewOptions.self) private var options

    /// Ambient, written once by the destination; nil in previews, which is honest.
    @Environment(\.analysisRunningGameID) private var runningAnalysisID

    // MARK: Body
    var body: some View {
        IconGridView(
            items: games,
            selection: $selectedPGNs,
            space: "libraryIconsGrid",
            collection: .library
        ) { game, isSelected, select in
            LibraryGameCardView(
                game: game,
                glyphWidth: options.glyphWidth(for: .library),
                analysisState: AnalysisGlyph.state(
                    of: game,
                    isAnalyzed: analyzedIDs.contains(game.id),
                    runningID: runningAnalysisID
                ),
                inscription: options.libraryCardInscription,
                isSelected: isSelected,
                onSelect: select,
                // Double-click opens THIS card in place - never the whole selection, which would be
                // N tabs from one gesture.
                onOpen: { onOpenInPlace(game) }
            )
            // The host attaches the menu (23 Aug 2026), because only the host can count: the card
            // rendered `GameActionsMenu(games: [game])`, so a fifty-game selection read "Export
            // PGN" and offered Get Info while the verbs acted on the whole set - labels and
            // actions disagreeing about the same click. One subject rule, one shared menu, all
            // four modes; the verbs pass through untouched.
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

    // MARK: Instance Methods

    /// Finder's rule, from the shared grammar - ordered off `games`, which is tab and processing
    /// order. (It was spelled here by hand until 18 Aug 2026; it is a pure function of an array and
    /// a set, so it belongs where it can be tested.)
    private func subjects(for game: PGN) -> [PGN] {
        IconGridSelection.subjects(for: game, in: games, selection: selectedPGNs)
    }
}

// MARK: Previews

/// Seven cards over six columns: a partial second row, so overflow and wrap are exercisable.
/// First three carry the analyzed badge so both verdicts render.
#Preview("With Games") {
    @Previewable @State var selection: Set<PGN.ID> = []

    let games = LibraryPreviewFixtures.games()

    LibraryIconsView(
        games: games,
        analyzedIDs: Set(games.prefix(3).map(\.id)),
        selectedPGNs: $selection,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 900, height: 480)
    .environment(PreviewFixtures.viewOptions())
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PGN.ID> = []

    LibraryIconsView(
        games: [],
        analyzedIDs: [],
        selectedPGNs: $selection,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 720, height: 480)
    .environment(PreviewFixtures.viewOptions())
    .modelContainer(for: PGN.self, inMemory: true)
}
