//
//  LibraryDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import os
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

internal struct LibraryDestination: View {
    
    // MARK: Static Constants
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "library"
    )
    
    // MARK: Stored Properties
    internal let filter: SmartTag?
    
    // MARK: Tab State (lives on enclosing `ContentView`)
    @Bindable internal var tabState: TabState
    
    // MARK: Private Properties
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut
    @AppStorage(StorageKeys.libraryViewMode) private var viewMode: CollectionViewMode = .list
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(OpenGamesRegistry.self) private var openGames
    @Query(sort: \PGN.importedAt, order: .reverse) private var games: [PGN]
    @State private var pendingDeletion: PGN?
    @State private var pendingDirtyDeletion: PGN?
    @State private var pendingBatchDeletion: [PGN]?
    @State private var selectedPGNs: Set<PGN.ID> = []
    @State private var importProgress: ImportProgress?
    
    /// One-shot handoff to the inspector's analysis driver — set by
    /// `requestAnalysis`, nilled by the inspector's consumed callback.
    @State private var pendingAnalysisID: PGN.ID?
    
    // MARK: Initializers
    internal init(filter: SmartTag? = nil, tabState: TabState) {
        self.filter = filter
        self.tabState = tabState
    }
    
    // MARK: Computed Properties
    private var filteredGames: [PGN] {
        guard let filter else { return games }
        return games.filter { filter.matches($0) }
    }
    
    private var selectedPGN: PGN? {
        guard let id = selectedPGNs.first else { return nil }
        return filteredGames.first(where: { $0.id == id })
    }
    
    private var importSheetBinding: Binding<Bool> {
        Binding(
            get: { importProgress != nil },
            set: { if !$0 { importProgress = nil } }
        )
    }
    
    private var pendingDeletionBinding: Binding<Bool> {        Binding(
        get: { pendingDeletion != nil },
        set: { if !$0 { pendingDeletion = nil } }
    )
    }
    
    private var pendingDirtyDeletionBinding: Binding<Bool> {
        Binding(
            get: { pendingDirtyDeletion != nil },
            set: { if !$0 { pendingDirtyDeletion = nil } }
        )
    }
    
    private var pendingBatchDeletionBinding: Binding<Bool> {
        Binding(
            get: { pendingBatchDeletion != nil },
            set: { if !$0 { pendingBatchDeletion = nil } }
        )
    }
    
    // MARK: Body
    internal var body: some View {
        coreContent
            .alert(
                "Delete Game?",
                isPresented: pendingDeletionBinding,
                presenting: pendingDeletion,
                actions: { game in
                    Button("Delete", role: .destructive) { delete(game) }
                    Button("Cancel", role: .cancel) {}
                },
                message: { game in
                    Text("\(game.name) will be permanently deleted.")
                }
            )
            .alert(
                "Discard Unsaved Changes?",
                isPresented: pendingDirtyDeletionBinding,
                presenting: pendingDirtyDeletion,
                actions: { game in
                    Button("Delete Anyway", role: .destructive) {
                        performDelete(game)
                    }
                    Button("Cancel", role: .cancel) {}
                },
                message: { game in
                    Text("\(game.name) is open with unsaved changes. Deleting it will discard those changes and close its tab.")
                }
            )
            .alert(
                "Delete \(pendingBatchDeletion?.count ?? 0) Games?",
                isPresented: pendingBatchDeletionBinding,
                presenting: pendingBatchDeletion,
                actions: { games in
                    Button("Delete \(games.count) Games", role: .destructive) {
                        performBatchDelete(games)
                    }
                    Button("Cancel", role: .cancel) {}
                },
                message: { games in
                    Text("\(games.count) games will be permanently deleted. This can't be undone.")
                }
            )
            .onDeleteCommand {
                requestDeleteSelection()
            }
            .onAppear {
                backfillEmptyNames()
                if viewMode == .gallery { tabState.libraryInspectorPresented = true }
            }
            .onChange(of: viewMode) { _, mode in
                if mode == .gallery { tabState.libraryInspectorPresented = true }
            }
    }
    
    /// The library content plus its inspector, toolbar, drop target, and
    /// import sheet — split out from the deletion alerts so neither modifier
    /// chain trips SwiftUI's per-expression type-check budget. (Adding the
    /// third alert pushed the single combined chain over that limit, which the
    /// compiler reports as an "unable to type-check in reasonable time" error
    /// pinned to an arbitrary modifier.)
    private var coreContent: some View {
        Group {
            if filteredGames.isEmpty {
                emptyState
                    .accessibilityIdentifier(AccessibilityID.libraryEmptyState)
            } else {
                modeView
            }
        }
        .accessibilityIdentifier(AccessibilityID.libraryContent)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(filter?.displayName ?? "Library")
        .dropDestination(for: URL.self) { urls, _ in
            Self.logger.info("Drop received: \(urls.count) URL(s)")
            importURLs(urls)
            return true
        }
        .inspector(isPresented: $tabState.libraryInspectorPresented) {
            LibraryInspectorView(
                pgn: selectedPGN,
                pendingAnalysisID: pendingAnalysisID,
                onPendingAnalysisConsumed: { pendingAnalysisID = nil }
            )
            .inspectorColumnWidth(min: 260, ideal: 300, max: 400)
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: importSheetBinding) {
            if let importProgress {
                ImportStatusView(progress: importProgress) {
                    self.importProgress = nil
                }
            }
        }
    }
    
    // MARK: Instance Methods
    @ViewBuilder
    private var modeView: some View {
        switch viewMode {
        case .icons:
            LibraryIconsView(
                games: filteredGames,
                selectedPGNs: $selectedPGNs,
                onOpen:    openGame,
                onAnalyze: requestAnalysis,
                onDelete:  { pendingDeletion = $0 }
            )
            .accessibilityIdentifier(AccessibilityID.libraryModeIcons)
        case .list:
            LibraryListView(
                games: filteredGames,
                selectedPGNs: $selectedPGNs,
                onOpen:      openGame,
                onAnalyze:   requestAnalysis,
                onDeleteIDs: { requestDelete(ids: $0) }
            )
            .accessibilityIdentifier(AccessibilityID.libraryModeList)
        case .columns:
            LibraryColumnsView(
                games: filteredGames,
                selectedPGNs: $selectedPGNs,
                onOpen:    openGame,
                onAnalyze: requestAnalysis,
                onDelete:  { pendingDeletion = $0 }
            )
            .accessibilityIdentifier(AccessibilityID.libraryModeColumns)
        case .gallery:
            LibraryGalleryView(
                games: filteredGames,
                selectedPGNs: $selectedPGNs,
                boardStyle: boardStyle,
                onOpen:    openGame,
                onAnalyze: requestAnalysis,
                onDelete:  { pendingDeletion = $0 }
            )
            .accessibilityIdentifier(AccessibilityID.libraryModeGallery)
        }
    }
    
    /// Single resolution point for "open a game in its own window."
    /// Threaded into every Library view as the `onOpen` callback so the
    /// views stay window-system-unaware. macOS handles dedup, tabbing
    /// (with "Prefer Tabs: Always"), and restoration.
    private func openGame(_ pgn: PGN) {
        Self.logger.info("Open requested: '\(pgn.name, privacy: .public)'")
        openWindow(value: pgn.persistentModelID)
    }
    
    /// Single resolution point for "analyze a game" (toolbar button and
    /// context menus). The engine work stays where it already lives — the
    /// inspector's per-selection `GameAnalysisDriver` — so this only
    /// routes: select the game, surface the inspector (which shows the
    /// progress, the Stop button, and the graph), and hand it a one-shot
    /// request. Rejected alternative: a second driver owned here, which
    /// would race the inspector's over the same PGN and report a status
    /// its controls don't reflect. Selection-change semantics are
    /// unchanged — picking a different game still cancels a running pass,
    /// exactly as the inspector's own Analyze button always has.
    private func requestAnalysis(_ pgn: PGN) {
        Self.logger.info("Analyze requested: '\(pgn.name, privacy: .public)'")
        selectedPGNs = [pgn.id]
        tabState.libraryInspectorPresented = true
        pendingAnalysisID = pgn.id
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            // NOTE: On macOS a `.segmented` Picker built from
            // `Label(_:systemImage:)` renders icon-only, and each segment
            // is exposed to UI tests as a radioButton keyed by its SF
            // Symbol name (e.g. "square.grid.2x2"), NOT by any
            // per-segment accessibilityIdentifier. The identifier below
            // only tags the picker container; tests address the segments
            // by symbol name. See DGTStudioProUITests.
            Picker("View Mode", selection: $viewMode) {
                ForEach(CollectionViewMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(AccessibilityID.libraryViewModePicker).accessibilityIdentifier(AccessibilityID.libraryImportButton)
        }
        ToolbarSpacer()
        ToolbarItem {
            Button {
                if let pgn = selectedPGN { requestAnalysis(pgn) }
            } label: {
                Label("Analyze", systemImage: "wand.and.stars")
            }
            // Single-game action — the inspector's driver runs one pass
            // at a time (batch analysis is out of scope for v1), so a
            // multi-selection disables the button rather than analyzing
            // an arbitrary member of the Set.
            .disabled(selectedPGNs.count != 1)
            .help(
                selectedPGNs.count == 1
                ? "Analyze the selected game with Stockfish"
                : "Select a single game to analyze"
            )
            .accessibilityIdentifier(AccessibilityID.libraryAnalyzeButton)
        }
        ToolbarSpacer()
        ToolbarItem {
            Button(role: .destructive) {
                requestDeleteSelection()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(selectedPGNs.isEmpty)
            .help(selectedPGNs.count > 1 ? "Delete \(selectedPGNs.count) selected games" : "Delete selected game")
            .accessibilityIdentifier(AccessibilityID.libraryDeleteButton)
        }
        ToolbarSpacer()
        ToolbarItem {
            Button {
                tabState.libraryInspectorPresented.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.trailing")
            }
            .accessibilityIdentifier(AccessibilityID.libraryInspectorToggle)
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        if let filter {
            ContentUnavailableView {
                Label("No \(filter.displayName) Games", systemImage: "tag")
            } description: {
                Text("No games match this tag yet.")
            }
        } else {
            ContentUnavailableView {
                Label("No Games", systemImage: "books.vertical")
            } description: {
                Text("Import a PGN file to get started.")
            }
        }
    }
    
    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "pgn") ?? .plainText]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK {
            importURLs(panel.urls)
        }
    }
    
    private func importURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        Task { await runImport(urls) }
    }
    
    /// Imports a batch, recording a per-file result and never aborting on
    /// a failure — a bad file in the middle no longer drops the files
    /// after it. Runs on the main actor (PGNStore touches the
    /// `ModelContext`), yielding between files so the progress bar in the
    /// status sheet animates as work proceeds.
    @MainActor
    private func runImport(_ urls: [URL]) async {
        Self.logger.info("Import batch starting: \(urls.count) URL(s)")
        let store = PGNStore(modelContext: modelContext)
        importProgress = ImportProgress(total: urls.count)
        
        for url in urls {
            let outcome: ImportResult.Outcome
            do {
                let pgn = try store.importPGN(from: url)
                outcome = .imported(name: pgn.name)
            } catch let error as PGNStore.Error {
                Self.logger.error("Import failed for \(url.lastPathComponent, privacy: .public)")
                outcome = .failed(error)
            } catch {
                Self.logger.error("Import failed for \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                outcome = .failed(.fileReadFailed(url, underlying: error))
            }
            
            importProgress?.results.append(
                ImportResult(fileName: url.lastPathComponent, outcome: outcome)
            )
            // Let SwiftUI render the updated progress before the next file.
            await Task.yield()
        }
        
        importProgress?.isFinished = true
        let imported = importProgress?.importedCount ?? 0
        Self.logger.info("Import batch complete: \(imported)/\(urls.count) imported")
    }
    
    /// Routes a delete request for the current selection (toolbar button, ⌫).
    private func requestDeleteSelection() {
        requestDelete(ids: selectedPGNs)
    }
    
    /// Routes a delete request for a specific set of game IDs (the context
    /// menu's contextual selection). One game reuses the single-game flow (with
    /// its dirty-changes confirmation); two or more go through a batch
    /// confirmation.
    private func requestDelete(ids: Set<PGN.ID>) {
        let games = filteredGames.filter { ids.contains($0.id) }
        guard !games.isEmpty else { return }
        if games.count == 1 {
            delete(games[0])
        } else {
            pendingBatchDeletion = games
        }
    }
    
    /// Deletes every game in `pgns` in a single transaction, closing any open
    /// tabs first. Unsaved changes are discarded without a per-game prompt —
    /// acceptable while the dirty path is dormant (no editor yet); the
    /// single-game delete still routes dirty games through their confirmation.
    private func performBatchDelete(_ pgns: [PGN]) {
        for pgn in pgns {
            let id = pgn.persistentModelID
            openGames.markClean(id)
            // Close the open tab (if any) before teardown, so it never renders
            // against a tombstoned PGN.
            dismissWindow(value: id)
        }
        selectedPGNs.removeAll()
        
        let store = PGNStore(modelContext: modelContext)
        do {
            try store.delete(pgns)
        } catch {
            Self.logger.error(
                "Failed to batch-delete \(pgns.count) PGNs: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
    
    /// Entry point from the "Delete Game?" confirmation. Routes to a
    /// second discard confirmation if the game is open with unsaved
    /// changes; otherwise deletes and closes immediately.
    private func delete(_ pgn: PGN) {
        if openGames.isDirty(pgn.persistentModelID) {
            pendingDirtyDeletion = pgn
        } else {
            performDelete(pgn)
        }
    }
    
    /// Performs the deletion and closes any tab showing this game.
    /// `dismissWindow(value:)` targets the window/tab presenting the
    /// given value regardless of which tab invokes it, and is a harmless
    /// no-op when no tab is open for the game.
    private func performDelete(_ pgn: PGN) {
        let id = pgn.persistentModelID
        selectedPGNs.remove(pgn.id)
        openGames.markClean(id)
        
        // Close the open tab (if any) before the model is torn down, so
        // the tab never renders against a tombstoned PGN.
        dismissWindow(value: id)
        
        let store = PGNStore(modelContext: modelContext)
        do {
            try store.delete(pgn)
        } catch {
            Self.logger.error("Failed to delete PGN: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func backfillEmptyNames() {
        let toFix = games.filter { game in
            game.name.isEmpty || game.name == game.legacyDefaultName
        }
        guard !toFix.isEmpty else { return }
        for game in toFix {
            game.name = game.defaultDisplayName
        }
        do {
            try modelContext.save()
            Self.logger.info("Backfilled names for \(toFix.count) game(s)")
        } catch {
            Self.logger.error("Name backfill save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: Previews
#Preview("With Games") {
    let container = try! ModelContainer(
        for: PGN.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let samples: [PGN] = [
        PGN(event: "World Championship", site: "Dubai", round: 11,
            white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian", result: .whiteWins),
        PGN(event: "Tata Steel Masters", site: "Wijk aan Zee", round: 7,
            white: "Giri, Anish", black: "Caruana, Fabiano", result: .draw),
        PGN(event: "Norway Chess", site: "Stavanger", round: 3,
            white: "Firouzja, Alireza", black: "Ding, Liren", result: .blackWins)
    ]
    for sample in samples { container.mainContext.insert(sample) }
    
    return NavigationSplitView {
        List { Label("Library", systemImage: "books.vertical") }
            .navigationSplitViewColumnWidth(min: 80, ideal: 100, max: 120)
    } detail: {
        LibraryDestination(tabState: TabState())
    }
    .modelContainer(container)
    .environment(OpenGamesRegistry())
}

#Preview("Empty") {
    NavigationSplitView {
        List { Label("Library", systemImage: "books.vertical") }
            .navigationSplitViewColumnWidth(min: 80, ideal: 100, max: 120)
    } detail: {
        LibraryDestination(tabState: TabState())
    }
    .modelContainer(for: PGN.self, inMemory: true)
    .environment(OpenGamesRegistry())
}
