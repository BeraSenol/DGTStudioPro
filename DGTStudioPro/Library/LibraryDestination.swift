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
    internal let filter: LibraryFilter?
    
    /// Clears the active filter back to the full Library (M-prs.6).
    /// Owned by `ContentView` because a filter *is* a sidebar selection —
    /// the destination can render the chip, but only the selection's
    /// owner can leave it. Nil when unfiltered; the chip renders its ✕
    /// unconditionally because every filtered construction passes it.
    internal let onClearFilter: (() -> Void)?
    
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
    @State private var isQueuePopoverPresented = false
    
    // MARK: Initializers
    internal init(
        filter: LibraryFilter? = nil,
        tabState: TabState,
        onClearFilter: (() -> Void)? = nil
    ) {
        self.filter = filter
        self.tabState = tabState
        self.onClearFilter = onClearFilter
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
    
    private var pendingDeletionBinding: Binding<Bool> {
        Binding(
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
                backfillPlayerLinks()
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
        VStack(spacing: 0) {
            if let filter {
                filterChipBar(for: filter)
                Divider()
            }
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
        }
        .navigationTitle(filter?.displayName ?? "Library")
        .dropDestination(for: URL.self) { urls, _ in
            Self.logger.info("Drop received: \(urls.count) URL(s)")
            importURLs(urls)
            return true
        }
        .inspector(isPresented: $tabState.libraryInspectorPresented) {
            LibraryInspectorView(
                pgn: selectedPGN,
                queue: tabState.analysisQueue
            )
            .inspectorColumnWidth(min: 325, ideal: 320, max: 430)
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
    
    /// The clearable filter chip (M-prs.6): "Tag: X ✕" / "Player: Y ✕".
    /// For a smart-tag filter it doubles the sidebar highlight; for a
    /// programmatic player filter it *is* the whole UI — the state's one
    /// visible face and its exit (there is no sidebar row to un-click).
    private func filterChipBar(for filter: LibraryFilter) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: filter.systemImage)
                Text("\(filter.kindLabel): \(filter.displayName)")
                    .lineLimit(1)
                Button {
                    onClearFilter?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Show the full Library")
                .accessibilityIdentifier(AccessibilityID.libraryFilterChipClear)
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(.secondary.opacity(0.15)))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.libraryFilterChip)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
                onExport:  requestExport,
                onDelete:  { pendingDeletion = $0 }
            )
            .accessibilityIdentifier(AccessibilityID.libraryModeIcons)
        case .list:
            LibraryListView(
                games: filteredGames,
                selectedPGNs: $selectedPGNs,
                onOpen:       openGame,
                onAnalyzeIDs: { requestAnalysis(ids: $0) },
                onExportIDs:  { requestExport(ids: $0) },
                onDeleteIDs:  { requestDelete(ids: $0) }
            )
            .accessibilityIdentifier(AccessibilityID.libraryModeList)
        case .columns:
            LibraryColumnsView(
                selectedPGNs: $selectedPGNs,
                games: filteredGames,
                onOpen:    openGame,
                onAnalyze: requestAnalysis,
                onExport:  requestExport,
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
                onExport:  requestExport,
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
    
    /// Single-game entry (card context menus, the gallery, the one-row
    /// list case). Analysis is a batch of one since M-batch — see
    /// `AnalysisQueueController`, decision 1 — so this enqueues, then
    /// keeps the pre-queue affordance: select the game and surface the
    /// inspector, which shows this game's progress, its skip control,
    /// and the graph filling in. The one-shot `pendingAnalysisID` relay
    /// this used to set is gone with the per-inspector driver it fed.
    private func requestAnalysis(_ pgn: PGN) {
        Self.logger.info("Analyze requested: '\(pgn.name, privacy: .public)'")
        selectedPGNs = [pgn.id]
        tabState.libraryInspectorPresented = true
        tabState.analysisQueue.enqueue([pgn], modelContext: modelContext)
    }
    
    /// Multi-game entry (the toolbar button, the list's contextual
    /// selection): enqueues in **display order** — a `Set` carries none,
    /// and top-to-bottom-as-shown is the order a batch should crunch in.
    /// Leaves selection and inspector untouched: collapsing a hand-built
    /// multi-selection to show progress would be hostile, and the
    /// toolbar's queue item carries batch progress instead. A single id
    /// routes through the single-game path, so right-click → Analyze on
    /// one row keeps opening the inspector exactly as before.
    private func requestAnalysis(ids: Set<PGN.ID>) {
        let ordered = filteredGames.filter { ids.contains($0.id) }
        guard !ordered.isEmpty else { return }
        if ordered.count == 1 {
            requestAnalysis(ordered[0])
            return
        }
        Self.logger.info("Batch analyze requested: \(ordered.count) game(s)")
        tabState.analysisQueue.enqueue(ordered, modelContext: modelContext)
    }
    
    /// Split into named groups because `ToolbarContentBuilder` — like every
    /// result builder — accepts at most ten statements per block, and D24′'s
    /// Export item was the eleventh. Grouping rather than golfing keeps room
    /// for the next item; the same move `coreContent` made when the third
    /// alert blew the type-check budget.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        transferToolbarItems
        ToolbarSpacer()
        viewModeToolbarItem
        ToolbarSpacer()
        analysisToolbarItems
        ToolbarSpacer()
        trailingToolbarItems
    }
    
    /// The Library's two file doors, in and out.
    @ToolbarContentBuilder
    private var transferToolbarItems: some ToolbarContent {
        ToolbarItem {
            // Restored in M-batch. The button had been lost in an earlier
            // toolbar edit, leaving three fossils: `presentOpenPanel()`
            // orphaned, this identifier copy-pasted onto the view-mode
            // picker's chain (where the outer of two chained identifiers
            // won, mislabeling the picker), and the import-button UITest
            // green against that mislabeled picker. Drag-and-drop had
            // silently become the only import route.
            Button {
                presentOpenPanel()
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .help("Import PGN files…")
            .accessibilityIdentifier(AccessibilityID.libraryImportButton)
        }
        ToolbarSpacer()
        ToolbarItem {
            Button {
                requestExport(ids: selectedPGNs)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(selectedPGNs.isEmpty)
            .help(
                selectedPGNs.count > 1
                ? "Export \(selectedPGNs.count) selected games as PGN files"
                : "Export the selected game as a PGN file"
            )
            .accessibilityIdentifier(AccessibilityID.libraryExport)
        }
    }
    
    @ToolbarContentBuilder
    private var viewModeToolbarItem: some ToolbarContent {
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
            .accessibilityIdentifier(AccessibilityID.libraryViewModePicker)
        }
    }
    
    @ToolbarContentBuilder
    private var analysisToolbarItems: some ToolbarContent {
        ToolbarItem {
            Button {
                requestAnalysis(ids: selectedPGNs)
            } label: {
                Label("Analyze", systemImage: "wand.and.stars")
            }
            // Queue-of-N since M-batch: any non-empty selection enqueues
            // in display order (see `requestAnalysis(ids:)`). The old
            // single-game-only guard died with the per-inspector driver
            // it protected.
            .disabled(selectedPGNs.isEmpty)
            .help(
                selectedPGNs.count > 1
                ? "Queue \(selectedPGNs.count) selected games for analysis"
                : "Analyze the selected game with Stockfish"
            )
            .accessibilityIdentifier(AccessibilityID.libraryAnalyzeButton)
        }
        // Visible only while a batch runs or a drained batch left
        // failures behind — see `queueStatusLabel` for the full rule.
        if tabState.analysisQueue.queue.isActive || tabState.analysisQueue.queue.hasFailures {
            ToolbarItem {
                Button {
                    isQueuePopoverPresented.toggle()
                } label: {
                    queueStatusLabel
                }
                .help("Analysis queue")
                .accessibilityIdentifier(AccessibilityID.libraryQueueStatus)
                .popover(
                    isPresented: $isQueuePopoverPresented,
                    arrowEdge: .bottom
                ) {
                    AnalysisQueueStatusView(controller: tabState.analysisQueue)
                }
            }
        }
    }
    
    @ToolbarContentBuilder
    private var trailingToolbarItems: some ToolbarContent {
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
    
    /// The queue toolbar item's label: a spinner with "2/5" while the
    /// run is live, a warning triangle with the counts once a drained
    /// run left failures behind. The item renders only in those two
    /// states — after a clean drain it disappears (the filled-in graphs
    /// are the visible result), and while failures linger it stays until
    /// the popover's Dismiss acknowledges them, so an error is never
    /// silently swallowed by the batch ending.
    private var queueStatusLabel: some View {
        HStack(spacing: 6) {
            if tabState.analysisQueue.queue.isActive {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "exclamationmark.triangle")
            }
            Text("\(tabState.analysisQueue.queue.completedCount)/\(tabState.analysisQueue.queue.totalCount)")
                .monospacedDigit()
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        if let filter {
            ContentUnavailableView {
                Label("No \(filter.displayName) Games", systemImage: filter.systemImage)
            } description: {
                Text("No games match this \(filter.kindLabel.lowercased()) yet.")
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
            // Before the store delete — see `performDelete` for the why.
            tabState.analysisQueue.gameWasDeleted(id)
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
        // Before the store delete: `gameWasDeleted` stops any running
        // pass on this game synchronously (the analysis walk checks its
        // cancellation flag before every PGN touch), so the engine never
        // writes into a tombstoned model.
        tabState.analysisQueue.gameWasDeleted(id)
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
        let toFix = games.filter(\.hasStaleDefaultName)
        guard !toFix.isEmpty else { return }
        for game in toFix {
            game.name = game.defaultDisplayName
        }
        do {
            try modelContext.save()
            let healed = toFix.map(\.name).joined(separator: ", ")
            Self.logger.info(
                "Backfilled \(toFix.count) legacy game name(s): \(healed, privacy: .public)"
            )
        } catch {
            Self.logger.error("Name backfill save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// M-prs.1 sibling of `backfillEmptyNames()`: the logic is store-owned and
    /// idempotent, so all three collection destinations call it from their own
    /// `onAppear` (Players and Rankings do the same). This is only the
    /// Library's call site and its error sink.
    private func backfillPlayerLinks() {
        do {
            try PGNStore(modelContext: modelContext).backfillPlayerLinks()
        } catch {
            Self.logger.error("Player-link backfill failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: Export (D24′)
    
    /// Single-game entry (a card's context menu). One game means a save
    /// panel: the user names the file.
    private func requestExport(_ pgn: PGN) {
        Self.logger.info("Export requested: '\(pgn.name, privacy: .public)'")
        PGNExporter.export([pgn])
    }
    
    /// Multi-game entry (the list's contextual selection). Resolves the set
    /// against `filteredGames` for the same reason `requestAnalysis(ids:)`
    /// does — a `Set` carries no order, and here the order is *visible*: it
    /// numbers the filenames. Leaves selection and inspector untouched.
    private func requestExport(ids: Set<PGN.ID>) {
        let ordered = filteredGames.filter { ids.contains($0.id) }
        guard !ordered.isEmpty else { return }
        Self.logger.info("Export requested: \(ordered.count) game(s)")
        PGNExporter.export(ordered)
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
