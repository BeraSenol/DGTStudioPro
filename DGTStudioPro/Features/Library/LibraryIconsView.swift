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

    /// **Currently unreached from this grid** (noted 18 Aug 2026, in the shared-grid pass, not
    /// changed by it): the card has one Open door, and both double-click and the menu's Open item
    /// route to `onOpenInPlace`. The destination still supplies this and its comment there still
    /// calls it "the menu's new-tab door", which the grid has not been since the card's menu was
    /// wired. Kept rather than deleted - removing a destination-supplied door is a behaviour
    /// decision, not a de-duplication - but recorded so it reads as known, not as an oversight.
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
                isSelected: isSelected,
                onSelect: select,
                // Double-click opens THIS card in place - never the whole selection, which would be
                // N tabs from one gesture.
                onOpen:    { onOpenInPlace(game) },
                onAnalyze: { onAnalyze(subjects(for: game)) },
                onExport:  { onExport(subjects(for: game)) },
                onDelete:  { onDelete(subjects(for: game)) }
            )
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
