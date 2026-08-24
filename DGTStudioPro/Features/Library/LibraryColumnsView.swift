import Foundation
import SwiftData
import SwiftUI

/// Finder-column shape: flat game list left, selected game's detail filling the rest -
/// inspection density, not navigation (the smart tags own grouping).
struct LibraryColumnsView: View {

    // MARK: Stored Properties
    let games: [PGN]
    /// Row badges' input, off the destination's memoized projection.
    let analyzedIDs: Set<PGN.ID>
    @Binding var selectedPGNs: Set<PGN.ID>
    let boardStyle: BoardStyle
    /// Takes the set - Open's door owns the count threshold.
    let onOpen: ([PGN]) -> Void
    /// The detail pane's Open button (17 Aug 2026): this tab, not a new one - the gesture's
    /// meaning is now uniform across every mode.
    var onOpenInPlace: (PGN) -> Void = { _ in }
    /// The list's set doors, verbatim, since 23 Aug 2026. These were `(PGN) -> Void` with the
    /// menu fanning out through `forEach` - which read fine and was wrong twice: "Delete 5
    /// Games" assigned `pendingDeletion` five times so the confirmation deleted only the last,
    /// and "Export 5 PGNs" would have run the single-export door five times. A verb whose label
    /// counts must reach a door that takes the count.
    let onAnalyzeIDs: (Set<PGN.ID>) -> Void
    let onExportIDs: (Set<PGN.ID>) -> Void
    let onDeleteIDs: (Set<PGN.ID>) -> Void

    /// Shared with list mode through the destination - one binding, so a sort survives the mode switch.
    @Binding var sortOrder: [KeyPathComparator<PGN>]

    /// "No value" for derived rows (`OpeningSection`'s placeholder meaning, restated per surface);
    /// roster rows never need it - `RosterSummary` speaks PGN's own `?`.
    private static let noValue = RosterSummary.displayUnknown

    /// Ambient rather than a parameter - argument at the environment value's declaration.
    @Environment(\.analysisRunningGameID) private var runningAnalysisID

    /// The serialized movetext, memoized on the game's own identity-of-content value
    /// (21 Aug 2026). `PGN.pgnText` runs the whole game back through `PGNSerializer`, and it sat
    /// bare in `gameDetail`'s body - so every render of the detail pane rebuilt the entire
    /// document string *and* re-laid out a large selectable monospaced text. The census note that
    /// stood here ("one game per render") was the right observation with the wrong conclusion:
    /// one game is bounded, but the renders are not.
    ///
    /// Synchronous memo rather than `.task(id:)`: the work is a string build, and hopping it off
    /// the render pass would trade a real cost for an empty first frame.
    @State private var pgnTextCache = CollectionFoldCache<String, String>()

    // MARK: Computed Properties

    /// Single selection or nil - the detail pane details one thing; multi gets a counting
    /// placeholder, never an arbitrary `first`.
    private var selectedGame: PGN? {
        guard selectedPGNs.count == 1, let id = selectedPGNs.first else { return nil }
        return games.first { $0.id == id }
    }

    // MARK: Body
    var body: some View {
        HSplitView {
            // 160/200/300 floors: columns is the one mode that must survive narrow windows.
            // `.layoutPriority(1)` enforces the floor - `HSplitView` honours `minWidth` only while the
            // other side yields.
            gameList
                .frame(minWidth: 160, idealWidth: 200, maxWidth: 300, maxHeight: .infinity)
                .layoutPriority(1)

            detail
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Instance Methods

    /// The empty arm is unreachable in production (destination gates first), but previews construct
    /// this view directly, and an empty `List` with a selection binding renders as a bare void.
    @ViewBuilder
    private var gameList: some View {
        if games.isEmpty {
            VStack {
                Spacer()
                Text("No games")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            // A one-column `Table`, not a `List` (Bera's call): the un-suppressible header became the sort
            // affordance. **No `columnCustomization`, load-bearing** - a hidden column here is a broken mode.
            Table(games, selection: $selectedPGNs, sortOrder: $sortOrder) {
                TableColumn("Name", value: \.name) { game in
                    row(for: game)
                }
                // The 160 twice is NOT the twin pattern: the frame's floor governs the *pane*, this one the
                // *column*. All three bounds - min-only did not stop mid-truncation at wide widths.
                .width(min: 160, ideal: 200, max: .infinity)
            }
            .tableStyle(.inset)
            // Selection-typed (the `LibraryListView` shape): inherits ⌘/⇧-click multi-select and hands the
            // whole set to `GameActionsMenu` - counted plurals were unreachable from this mode before.
            .contextMenu(forSelectionType: PGN.ID.self) { ids in
                GameActionsMenu(
                    games: games.filter { ids.contains($0.id) },
                    onOpen: onOpen,
                    onAnalyze: { onAnalyzeIDs(Set($0.map(\.id))) },
                    onExport: { onExportIDs(Set($0.map(\.id))) },
                    onDelete: { onDeleteIDs(Set($0.map(\.id))) }
                )
            }
        }
    }

    /// Finder's row: one icon, one name, one line - plus the analysis glyph at the trailing edge
    ///: the one fact the detail pane only answers for games you have not clicked yet.
    private func row(for game: PGN) -> some View {
        let state = AnalysisGlyph.state(
            of: game,
            isAnalyzed: analyzedIDs.contains(game.id),
            runningID: runningAnalysisID
        )
        return HStack(spacing: 6) {
            // `document.fill` - the app's one glyph for one game (21 Aug 2026).
            Image(systemName: "document.fill")
                .imageScale(.medium)
            Text(game.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            AnalysisBadgeIcon(state: state)
                .font(.caption)
                .accessibilityLabel(AnalysisGlyph.statusLabel(state))
        }
        .padding(.vertical, 1)
        // The menu moved to the `Table` as selection-typed - a per-row `.contextMenu` in a cell would
        // shadow it and act on one game regardless of selection.
    }

    @ViewBuilder
    private var detail: some View {
        if let game = selectedGame {
            gameDetail(game)
        } else if selectedPGNs.count > 1 {
            // Bulk verbs live on the row menus (the toolbar buttons were removed 6 Aug 2026).
            ContentUnavailableView(
                "\(selectedPGNs.count) Games Selected",
                systemImage: "square.on.square",
                description: Text("Right-click any selected game to analyze, export or delete the whole selection.")
            )
        } else {
            ContentUnavailableView(
                "No Game Selected",
                systemImage: "document.fill",
                description: Text("Select a game in the list to see its details.")
            )
        }
    }

    /// Raw PGN above, facts below. The preview board is gone - it was the squeeze: a view *asking*
    /// for space rather than taking what is given. `PGN.pgnText` is the inspector's same accessor,
    /// byte-identical to Export; read through `pgnTextCache` so a re-render is not a re-serialize.
    private func gameDetail(_ game: PGN) -> some View {
        let pgnText = pgnTextCache.value(for: game.contentHash) { game.pgnText }
        return VStack(spacing: 0) {
            ScrollView {
                // A centred, width-capped container (17 Aug 2026, by request) - full-pane
                // monospaced text put sixty-character lines against a very wide margin. The
                // inner frame caps the column; the outer greedy frame centres the cap.
                Text(pgnText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            factsAndActions(game)
        }
    }

    private func factsAndActions(_ game: PGN) -> some View {
        let roster = RosterSummary(game)
        return VStack(spacing: 16) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                ForEach(SevenTagRoster.allCases, id: \.self) { tag in
                    factRow(tag.rawValue, roster[tag])
                }
                factRow("Opening", game.opening.map { "\($0.code) · \($0.fullName)" } ?? Self.noValue)
                factRow("Moves", game.moves.isEmpty ? Self.noValue : "\((game.moves.count + 1) / 2)")
                factRow("Time Control", game.timeControl ?? Self.noValue)
                factRow("Board", game.board ?? Self.noValue)
            }
            .frame(maxWidth: 420)

            HStack(spacing: 12) {
                Button {
                    // Singular by construction: the detail pane renders only for a count of one.
                    onOpenInPlace(game)
                } label: {
                    Label("Open", systemImage: "arrow.up.forward.square")
                }
                .buttonStyle(.borderedProminent)
                .help("Open this game in this tab")

                Button {
                    // The set door with a one-game set - singular by construction (the pane
                    // renders only for a count of one), and one door for both surfaces.
                    onAnalyzeIDs([game.id])
                } label: {
                    // The projection overload - the same input the row badges read, so button and badge
                    // cannot disagree.
                    AnalysisLabel(
                        state: AnalysisGlyph.state(
                            of: game,
                            isAnalyzed: analyzedIDs.contains(game.id),
                            runningID: runningAnalysisID
                        )
                    )
                }
                .help("Analyze this game with Stockfish")
            }
        }
        .padding(20)
    }

    /// Finder's info-row shape; values truncate in the middle - serials and site names carry their
    /// information at the ends.
    private func factRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.callout)
    }
}

// MARK: Previews

#Preview("Detail") {
    @Previewable @State var selection: Set<PGN.ID> = []
    @Previewable @State var sort = LibraryDestination.defaultSortOrder

    let games = LibraryPreviewFixtures.datedGames()

    LibraryColumnsView(
        games: games,
        analyzedIDs: Set(games.prefix(1).map(\.id)),
        selectedPGNs: $selection,
        boardStyle: .walnut,
        onOpen: { _ in },
        onAnalyzeIDs: { _ in },
        onExportIDs: { _ in },
        onDeleteIDs: { _ in },
        sortOrder: $sort
    )
    .frame(width: 900, height: 620)
    .onAppear {
        if let id = games.first?.id { selection = [id] }
    }
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Multi-Selection") {
    @Previewable @State var selection: Set<PGN.ID> = []
    @Previewable @State var sort = LibraryDestination.defaultSortOrder

    let games = LibraryPreviewFixtures.datedGames()

    LibraryColumnsView(
        games: games,
        analyzedIDs: Set(games.prefix(1).map(\.id)),
        selectedPGNs: $selection,
        boardStyle: .walnut,
        onOpen: { _ in },
        onAnalyzeIDs: { _ in },
        onExportIDs: { _ in },
        onDeleteIDs: { _ in },
        sortOrder: $sort
    )
    .frame(width: 900, height: 620)
    .onAppear {
        selection = Set(games.prefix(2).map(\.id))
    }
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("No Selection") {
    @Previewable @State var selection: Set<PGN.ID> = []
    @Previewable @State var sort = LibraryDestination.defaultSortOrder

    LibraryColumnsView(
        games: LibraryPreviewFixtures.datedGames(),
        analyzedIDs: [],
        selectedPGNs: $selection,
        boardStyle: .rosewood,
        onOpen: { _ in },
        onAnalyzeIDs: { _ in },
        onExportIDs: { _ in },
        onDeleteIDs: { _ in },
        sortOrder: $sort
    )
    .frame(width: 900, height: 620)
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PGN.ID> = []
    @Previewable @State var sort = LibraryDestination.defaultSortOrder

    LibraryColumnsView(
        games: [],
        analyzedIDs: [],
        selectedPGNs: $selection,
        boardStyle: .walnut,
        onOpen: { _ in },
        onAnalyzeIDs: { _ in },
        onExportIDs: { _ in },
        onDeleteIDs: { _ in },
        sortOrder: $sort
    )
    .frame(width: 900, height: 620)
    .modelContainer(for: PGN.self, inMemory: true)
}
