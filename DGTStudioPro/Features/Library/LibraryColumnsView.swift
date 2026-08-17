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
    /// Takes the set. Deliberately not adapted with a `forEach` like the others: those fan
    /// out to per-game doors, while Open's door owns the count threshold.
    let onOpen: ([PGN]) -> Void
    let onAnalyze: (PGN) -> Void
    let onExport: (PGN) -> Void
    let onDelete: (PGN) -> Void

    /// Shared with list mode through the destination - one binding, so a sort survives the mode switch.
    @Binding var sortOrder: [KeyPathComparator<PGN>]

    /// "No value" for derived rows (`OpeningSection`'s placeholder meaning, restated per surface);
    /// roster rows never need it - `RosterSummary` speaks PGN's own `?`.
    private static let noValue = RosterSummary.displayUnknown

    /// Ambient rather than a parameter - argument at the environment value's declaration.
    @Environment(\.analysisRunningGameID) private var runningAnalysisID

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
                    onAnalyze: { $0.forEach(onAnalyze) },
                    onExport: { $0.forEach(onExport) },
                    onDelete: { $0.forEach(onDelete) }
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
            Image(systemName: "text.document.fill")
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
                systemImage: "square.dashed",
                description: Text("Select a game in the list to see its details.")
            )
        }
    }

    /// Raw PGN above, facts below. The preview board is gone - it was the squeeze: a view *asking*
    /// for space rather than taking what is given. `PGN.pgnText` is the inspector's same accessor,
    /// byte-identical to Export; one game per render, censused.
    private func gameDetail(_ game: PGN) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                // A centred, width-capped container (17 Aug 2026, by request) - full-pane
                // monospaced text put sixty-character lines against a very wide margin. The
                // inner frame caps the column; the outer greedy frame centres the cap.
                Text(game.pgnText)
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
                    onOpen([game])
                } label: {
                    Label("Open", systemImage: "arrow.up.forward.square")
                }
                .buttonStyle(.borderedProminent)
                .help("Open this game in its own window")

                Button {
                    onAnalyze(game)
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
private func columnsPreviewGames() -> [PGN] {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy.MM.dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")

    return [
        // Fully-populated branch: every derived facts row has a value.
        PGN(event: "World Championship", site: "Dubai",
            date: formatter.date(from: "2021.12.10"),
            round: 11,
            white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian",
            moves: ["e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#"],
            result: .whiteWins,
            timeControl: "40/7200"),
        PGN(event: "Tata Steel Masters", site: "Wijk aan Zee",
            date: formatter.date(from: "2024.01.20"),
            round: 7,
            white: "Giri, Anish", black: "Caruana, Fabiano", result: .draw),
        PGN(event: "Norway Chess", site: "Stavanger",
            date: formatter.date(from: "2023.06.03"),
            round: 3,
            white: "Firouzja, Alireza", black: "Ding, Liren", result: .blackWins),
        // Undated and moveless: the placeholder branch of every derived row at once.
        PGN(event: "Norway Chess", site: "Stavanger",
            date: nil,
            round: 5,
            white: "Carlsen, Magnus", black: "Firouzja, Alireza", result: .whiteWins)
    ]
}

#Preview("Detail") {
    @Previewable @State var selection: Set<PGN.ID> = []
    @Previewable @State var sort = LibraryDestination.defaultSortOrder

    let games = columnsPreviewGames()

    LibraryColumnsView(
        games: games,
        analyzedIDs: Set(games.prefix(1).map(\.id)),
        selectedPGNs: $selection,
        boardStyle: .walnut,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in },
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

    let games = columnsPreviewGames()

    LibraryColumnsView(
        games: games,
        analyzedIDs: Set(games.prefix(1).map(\.id)),
        selectedPGNs: $selection,
        boardStyle: .walnut,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in },
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
        games: columnsPreviewGames(),
        analyzedIDs: [],
        selectedPGNs: $selection,
        boardStyle: .rosewood,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in },
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
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in },
        sortOrder: $sort
    )
    .frame(width: 900, height: 620)
    .modelContainer(for: PGN.self, inMemory: true)
}
