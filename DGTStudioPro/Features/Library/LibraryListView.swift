import SwiftData
import SwiftUI

internal struct LibraryListView: View {
    let games: [PGN]
    /// The Analysis column's input (D72′), off the memoized projection — the per-row blob decode
    /// this replaced was the last one standing, on the mode most on screen during a batch.
    let analyzedIDs: Set<PGN.ID>
    @Binding var selectedPGNs: Set<PGN.ID>
    /// Takes the set (D56′), like every action here.
    let onOpen: ([PGN]) -> Void
    let onAnalyzeIDs: (Set<PGN.ID>) -> Void
    let onExportIDs: (Set<PGN.ID>) -> Void
    let onDeleteIDs: (Set<PGN.ID>) -> Void

    /// Column visibility and order, from the header's right-click menu. **Visibility and order
    /// only** — `TableColumnCustomization` cannot carry a width. IDs are stored state, never
    /// derived from titles (titles are editable prose).
    @AppStorage(StorageKeys.libraryColumns)
    private var columnCustomization = TableColumnCustomization<PGN>()

    /// Ambient — the Analysis column tells "analyzed" from "on the engine now".
    @Environment(\.analysisRunningGameID) private var runningAnalysisID

    /// Header sort. **A binding, not `@State`**: display order feeds D24′ export numbering, queue
    /// order and D56′ tab order through `gamesInDisplayOrder`, so the sort must live where
    /// `filteredGames` applies it. Not persisted, unlike column customization.
    @Binding var sortOrder: [KeyPathComparator<PGN>]

    var body: some View {
        Table(games,
              selection: $selectedPGNs,
              sortOrder: $sortOrder,
              columnCustomization: $columnCustomization) {
            // D58′ — the file's ordinal, leading because that is where a filing number reads. Em dash for
            // nil (ECO's blank is the documented exception).
            TableColumn("#", sortUsing: KeyPathComparator(\PGN.libraryIndex)) { game in
                Text(game.libraryIndex.map(String.init) ?? RosterSummary.displayUnknown)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 34, ideal: 44, max: 64)
            .customizationID("index")

            // Carries `gameRow(name)` and is hideable anyway (D51′ — no cell is a guaranteed address).
            // Sorted on the **display** form: the stored tag would order by a surname the cell doesn't print.
            TableColumn("White", value: \.whiteDisplayName) { game in
                Text(game.whiteDisplayName)
                    .accessibilityIdentifier(AccessibilityID.gameRow(game.name))
            }
            .customizationID("white")
            TableColumn("Black", value: \.blackDisplayName) { Text($0.blackDisplayName) }
                .customizationID("black")

            // The analysis column; clicking queues that game. **The tenth column — the ceiling**:
            // `TableColumnBuilder` tops out at ten; an eleventh fails type-check obscurely (remedy: `Group`).
            // The only column with a control — the fact and the verb are one thought.
            TableColumn("Analysis") { game in
                Button {
                    // The singular set, not `selectedPGNs`: a row's button is a statement about that row. Same
                    // closure as the context menu, so threshold and ordering apply identically.
                    onAnalyzeIDs([game.id])
                } label: {
                    AnalysisLabel(
                        state: AnalysisGlyph.state(
                            of: game,
                            isAnalyzed: analyzedIDs.contains(game.id),
                            runningID: runningAnalysisID
                        )
                    )
                }
                // `.borderless`, or every row grows a bordered button.
                .buttonStyle(.borderless)
                // Live while analyzing: `enqueue` skips a running id, so a second click is a no-op.
                .help("Analyze this game with Stockfish")
            }
            .width(min: 96, ideal: 116, max: 160)
            .customizationID("analysis")
            // Raw value, so the order is PGN's own vocabulary — at least it matches what the cell prints.
            TableColumn("Result", value: \.result.rawValue) { game in
                Text(game.result.rawValue).foregroundStyle(.secondary)
            }
            .width(60)
            .customizationID("result")
            // Code only (the family truncates at column width; the inspector has all three rows). Nothing
            // rather than an em dash — a column of dashes is noise. Read and sorted through `opening`,
            // never `ecoCode` — rehydrates per sort recompute (memoized since D78′), censused.
            TableColumn("ECO", sortUsing: KeyPathComparator(\PGN.opening?.code)) { game in
                Text(game.opening?.code ?? "").foregroundStyle(.secondary)
            }
            .width(min: 44, ideal: 52)
            .customizationID("eco")
            // D34′'s other half — classified, stamped and cleared together, so showing only the opening was
            // an asymmetry. Sorted on the stored rawValue (1:1 with display).
            TableColumn("Checkmate Type", sortUsing: KeyPathComparator(\PGN.specialCheckmate?.rawValue)) { game in
                Text(game.specialCheckmate?.displayName ?? RosterSummary.displayUnknown)
                    .foregroundStyle(.secondary)
            }
            // The customization ID stays `"mate"` — stored state; a rename must not reset a column layout.
            .width(min: 96, ideal: 110)
            .customizationID("mate")
            TableColumn("Event", value: \.event) { Text($0.event).lineLimit(1) }
                .customizationID("event")
            // `effectiveDate` (date ?? importedAt) — the app's one ordering rule (D10′), so this column
            // agrees with every pure fold. Display and sort diverge for an undated game on purpose.
            TableColumn("Date", value: \.effectiveDate) { game in
                Text(game.displayDate).foregroundStyle(.secondary)
            }
            .width(100)
            .customizationID("date")
            TableColumn("Round", sortUsing: KeyPathComparator(\PGN.round)) { game in
                Text(game.displayRound).foregroundStyle(.secondary)
            }
            .width(60)
            .customizationID("round")
        }
        .accessibilityIdentifier(AccessibilityID.libraryGamesTable)
        .contextMenu(forSelectionType: PGN.ID.self) { ids in
            // `ids` is the full selection when a selected row is right-clicked, else that row. Resolved to
            // models *here*: the filter puts games in display order, which a `Set` cannot carry.
            GameActionsMenu(
                games: games.filter { ids.contains($0.id) },
                onOpen: onOpen,
                onAnalyze: { onAnalyzeIDs(Set($0.map(\.id))) },
                onExport: { onExportIDs(Set($0.map(\.id))) },
                onDelete: { onDeleteIDs(Set($0.map(\.id))) }
            )
        } primaryAction: { ids in
            // Fires on double-click and Return. **Opens the whole set (D56′)** — this read `ids.first`
            // once: "some row, in `Set` order", a game wearing another's face.
            onOpen(games.filter { ids.contains($0.id) })
        }
    }
}

// MARK: Previews
private func listPreviewGames() -> [PGN] {
    [
        PGN(event: "World Championship", site: "Dubai", round: 11,
            white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian", result: .whiteWins),
        PGN(event: "Tata Steel Masters", site: "Wijk aan Zee", round: 7,
            white: "Giri, Anish", black: "Caruana, Fabiano", result: .draw),
        PGN(event: "Norway Chess", site: "Stavanger", round: 3,
            white: "Firouzja, Alireza", black: "Ding, Liren", result: .blackWins),
        PGN(event: "Candidates Tournament", site: "Madrid", round: 14,
            white: "Nepomniachtchi, Ian", black: "Ding, Liren", result: .ongoing)
    ]
}

#Preview("With Games") {
    @Previewable @State var selection: Set<PGN.ID> = []
    @Previewable @State var sort = LibraryDestination.defaultSortOrder

    let games = listPreviewGames()

    LibraryListView(
        games: games,
        analyzedIDs: Set(games.prefix(2).map(\.id)),
        selectedPGNs: $selection,
        onOpen: { _ in },
        onAnalyzeIDs: { _ in },
        onExportIDs: { _ in },
        onDeleteIDs: { _ in },
        sortOrder: $sort
    )
    .frame(width: 720, height: 360)
    .modelContainer(for: PGN.self, inMemory: true)
    // Never `.standard`: column layout is `@AppStorage`, and a canvas on the real suite renders
    // whatever I last hid in the app.
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}

/// The one canvas showing a sorted table looking sorted (non-empty `sortOrder` draws the
/// chevron). Round on purpose: optional-valued, so it renders the `sortUsing:` arm.
#Preview("Sorted by Round") {
    @Previewable @State var selection: Set<PGN.ID> = []
    @Previewable @State var sort: [KeyPathComparator<PGN>] =
        [KeyPathComparator(\PGN.round)]

    LibraryListView(
        games: listPreviewGames().sorted(using: sort),
        analyzedIDs: [],
        selectedPGNs: $selection,
        onOpen: { _ in },
        onAnalyzeIDs: { _ in },
        onExportIDs: { _ in },
        onDeleteIDs: { _ in },
        sortOrder: $sort
    )
    .frame(width: 720, height: 360)
    .modelContainer(for: PGN.self, inMemory: true)
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PGN.ID> = []
    @Previewable @State var sort = LibraryDestination.defaultSortOrder

    LibraryListView(
        games: [],
        analyzedIDs: [],
        selectedPGNs: $selection,
        onOpen: { _ in },
        onAnalyzeIDs: { _ in },
        onExportIDs: { _ in },
        onDeleteIDs: { _ in },
        sortOrder: $sort
    )
    .frame(width: 720, height: 360)
    .modelContainer(for: PGN.self, inMemory: true)
    // Never `.standard` — same reason as above.
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}
