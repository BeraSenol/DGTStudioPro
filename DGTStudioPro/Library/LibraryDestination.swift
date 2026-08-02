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
    // Shared with Players (see `StorageKeys.collectionViewMode`): the last
    // view mode used in either collection destination is what both show.
    // The `.list` default is the documented twin of PlayersDestination's.
    @AppStorage(StorageKeys.collectionViewMode) private var viewMode: CollectionViewMode = .list
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
    
    // MARK: Search & Filters (2 Aug 2026 — native `.searchable`, restored
    // the same day after a custom toolbar field was tried and reverted: the
    // system field claims the toolbar's trailing edge and that isn't
    // negotiable, but native search behavior won over field placement.)
    @State private var searchText = ""
    /// The two toolbar-menu filters; nil means "any". They are filters and
    /// not search scopes deliberately: they answer in the field's own
    /// vocabulary rather than free text, they stay useful with no query
    /// typed, and their active state is visible on the toolbar (the filled
    /// filter glyph) — a scope bar exists only while searching, which would
    /// make an empty-query filter invisible after the field closes.
    @State private var resultFilter: GameResult?
    @State private var analysisFilter: Bool?
    
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
    
    /// Sidebar filter → search → menu filters, in that order — narrowing
    /// only, so the stages compose without caring about each other. Every
    /// downstream consumer (`selectedPGN`, `gamesInDisplayOrder`, and
    /// therefore batch analyze/export/delete) reads the same narrowed list,
    /// which is exactly how the tag filter already behaved: a hidden game
    /// is out of every bulk action, never silently included.
    private var filteredGames: [PGN] {
        var result = games
        if let filter {
            result = result.filter { filter.matches($0) }
        }
        // The emptiness guard only skips the walk — an empty query matches
        // everything by the matcher's own contract.
        if !searchText.isEmpty {
            result = result.filter {
                SearchMatch.matches(query: searchText, fields: searchFields(of: $0))
            }
        }
        if let resultFilter {
            result = result.filter { $0.result == resultFilter }
        }
        if let analysisFilter {
            // `AnalysisGlyph.isAnalyzed`, not a bare `isEmpty` check: the
            // filter and the gear glyphs must answer "analyzed?" the same
            // way, and that type is the one spelling.
            result = result.filter { AnalysisGlyph.isAnalyzed($0) == analysisFilter }
        }
        return result
    }
    
    /// The model side of the `LibraryFilter` split: the pure matcher takes
    /// strings, this maps a game into its searchable ones. Every field,
    /// always — the scope picker that once narrowed this set
    /// (`LibrarySearchScope`) was retired 2 Aug 2026, because a query
    /// already names its field: "1-0" is a result, "C60" is an opening, a
    /// surname is a player. The result's raw value is included on purpose
    /// for exactly that reason.
    private func searchFields(of game: PGN) -> [String] {
        [game.name, game.whiteDisplayName, game.blackDisplayName,
         game.event, game.site, game.result.rawValue,
         game.opening?.code, game.opening?.fullName].compactMap { $0 }
    }
    
    /// Whether the empty gate should read as "no matches" rather than
    /// "no games".
    private var isNarrowedBySearchOrFilters: Bool {
        !searchText.isEmpty || resultFilter != nil || analysisFilter != nil
    }
    
    private var hasActiveMenuFilters: Bool {
        resultFilter != nil || analysisFilter != nil
    }
    
    /// The single selected game, nil for empty *and* multiple — the columns
    /// detail's rule (2 Aug 2026): the inspector details one thing, and
    /// with a rubber-band or ⌘-click selection "the first of the set" is an
    /// arbitrary game wearing a specific game's face. The inspector gets
    /// the count instead and names it.
    private var selectedPGN: PGN? {
        guard selectedPGNs.count == 1, let id = selectedPGNs.first else { return nil }
        return filteredGames.first(where: { $0.id == id })
    }
    
    /// Resolves a selection to models in **display order**. A `Set` carries
    /// none, and the order is load-bearing twice: the queue crunches
    /// top-to-bottom as shown, and D24′'s export *numbers the filenames* from
    /// it. Three callers had this line copied.
    private func gamesInDisplayOrder(_ ids: Set<PGN.ID>) -> [PGN] {
        filteredGames.filter { ids.contains($0.id) }
    }
    
    // MARK: Body
    internal var body: some View {
        coreContent
            .alert(
                "Delete Game?",
                isPresented: Binding(present: $pendingDeletion),
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
                isPresented: Binding(present: $pendingDirtyDeletion),
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
                isPresented: Binding(present: $pendingBatchDeletion),
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
        // `.task`, not a fourth line in `onAppear`: this one has to await
        // the ECO table, and awaiting it is the entire point — see
        // `backfillClassifications()`.
            .task {
                await backfillClassifications()
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
                    // Two vocabularies for one gate: an empty *library*
                    // invites importing; an empty *result set* names the
                    // narrowing that caused it. The identifier stays on the
                    // true empty state — the UITests' seeded runs never
                    // search.
                    if isNarrowedBySearchOrFilters {
                        ContentUnavailableView(
                            "No Matches",
                            systemImage: "magnifyingglass",
                            description: Text("No games match the current search or filters.")
                        )
                    } else {
                        emptyState
                            .accessibilityIdentifier(AccessibilityID.libraryEmptyState)
                    }
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
                selectionCount: selectedPGNs.count,
                queue: tabState.analysisQueue
            )
            .inspectorColumnWidth(min: 310, ideal: 310, max: 430)
        }
        .toolbar { toolbarContent }
        .searchable(
            text: $searchText,
            placement: .toolbarPrincipal,
            prompt: "Search Games"
        )
        .sheet(isPresented: Binding(present: $importProgress)) {
            if let importProgress {
                ImportStatusView(progress: importProgress) {
                    self.importProgress = nil
                }
                // The footer button is disabled until the batch finishes for
                // exactly this reason, but ⎋ doesn't route through the button.
                // Dismissing mid-run nils the progress while `runImport` keeps
                // going, so the rest of the batch imports invisibly and the
                // completion log reports zero.
                .interactiveDismissDisabled(!importProgress.isFinished)
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
                games: filteredGames,
                selectedPGNs: $selectedPGNs,
                boardStyle: boardStyle,
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
        let ordered = gamesInDisplayOrder(ids)
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
        filterToolbarItem
        ToolbarSpacer(.flexible)
        analysisToolbarItems
        ToolbarSpacer(.fixed)
        transferToolbarItems
        ToolbarSpacer(.fixed)
        trailingToolbarItems
    }
    
    /// The search-independent half of the 2 Aug 2026 search feature — see
    /// the `resultFilter` declaration for why these are a menu and not
    /// scopes. Content side of the break, the Maintenance-menu argument:
    /// it acts on what the list shows.
    @ToolbarContentBuilder
    private var filterToolbarItem: some ToolbarContent {
        ToolbarItem {
            Menu {
                Picker("Result", selection: $resultFilter) {
                    Text("Any Result").tag(GameResult?.none)
                    ForEach(GameResult.allCases, id: \.self) { result in
                        Text(Self.filterLabel(for: result)).tag(GameResult?.some(result))
                    }
                }
                Picker("Analysis", selection: $analysisFilter) {
                    Text("Any Analysis").tag(Bool?.none)
                    Text("Analyzed").tag(Bool?.some(true))
                    Text("Not Analyzed").tag(Bool?.some(false))
                }
                if hasActiveMenuFilters {
                    Divider()
                    Button("Clear Filters") {
                        resultFilter = nil
                        analysisFilter = nil
                    }
                }
            } label: {
                Label("Filter", systemImage: hasActiveMenuFilters
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
            }
            .menuIndicator(.hidden)
            .help(hasActiveMenuFilters
                  ? "Filters are narrowing the list"
                  : "Filter by result or analysis state")
        }
    }
    
    /// Menu copy pairs the word with PGN's own vocabulary — the raw value
    /// stays the app's one rendering of a result (RosterSummary shows it
    /// verbatim); this label only introduces it.
    private static func filterLabel(for result: GameResult) -> String {
        switch result {
        case .whiteWins: "White Wins (1-0)"
        case .blackWins: "Black Wins (0-1)"
        case .draw:      "Draw (1/2-1/2)"
        case .ongoing:   "Ongoing (*)"
        }
    }
    
    /// The Library's two file doors, in and out — one toolbar cell, with a
    /// vertical divider between them. A single `ToolbarItem` (not two split
    /// by a `ToolbarSpacer`) so the pair shares one capsule: they are the
    /// two directions of the same job, and the explicit `Divider` marks the
    /// direction change inside it. Identifiers, helps and the disabled
    /// state stay on the individual buttons, so the UITest lookups and the
    /// per-button affordances are unmoved by the shared container.
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
            .help("Import PGN files")
            .accessibilityIdentifier(AccessibilityID.libraryImportButton)
        }
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
            .accessibilityIdentifier(AccessibilityID.libraryExportButton)
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
                // Aggregate glyph: the checkmark only once *every* selected
                // game is analyzed — until then the button has work left,
                // which is what the xmark says. An empty (disabled)
                // selection reads as work too, harmlessly.
                Label("Analyze", systemImage: AnalysisGlyph.name(
                    analyzed: {
                        let games = gamesInDisplayOrder(selectedPGNs)
                        return !games.isEmpty && games.allSatisfy(AnalysisGlyph.isAnalyzed)
                    }()
                ))
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
    
    /// The pinned tail, shared with Players by arrangement: the inspector
    /// toggle is always the trailing-most item, and the view-mode picker
    /// always sits immediately to its left — the same two controls in the
    /// same two places whichever collection destination is showing. The
    /// spacer between them is `.fixed`, not flexible: adjacent, but the
    /// toggle keeps its own group rather than sharing a pill with content
    /// controls (the `InspectorToggleContent` contract — it acts on the
    /// window, the picker on the destination's content).
    @ToolbarContentBuilder
    private var trailingToolbarItems: some ToolbarContent {
        viewModeToolbarItem
        ToolbarSpacer(.fixed)
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
        let games = gamesInDisplayOrder(ids)
        guard !games.isEmpty else { return }
        if games.count == 1 {
            // Through the alert, not straight to `delete(_:)`. The card menus
            // set `pendingDeletion` and get the "Delete Game?" confirmation;
            // this path skipped it, so ⌫ and the toolbar deleted a single game
            // outright while deleting *two* still asked. The alert's action
            // calls `delete(_:)`, so the dirty-changes fork is unchanged.
            pendingDeletion = games[0]
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
            let store = PGNStore(modelContext: modelContext)
            try store.backfillPlayerLinks()
            // D29′ — after links, which it reads (see the store doc).
            try store.backfillPlayerTagNames()
        } catch {
            Self.logger.error("Player-link backfill failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// D34′'s eager half: an opening name costs a dictionary probe, so the
    /// Library heals pre-M4 rows on appearance rather than making the user
    /// re-run a depth-18 analysis to learn one.
    ///
    /// Its own method with its own error sink, deliberately not a third line
    /// inside `backfillPlayerLinks()` — that sink logs "Player-link backfill
    /// failed", which a classification failure would turn into a lie. Unique
    /// to the Library among the three collection destinations: Players and
    /// Rankings read neither field (see the store doc).
    ///
    /// Async, and riding `.task` rather than `onAppear`, because the first
    /// call is what forces the ECO table's parse. Awaiting `warmed()` puts
    /// that work on a background thread and *suspends* the main actor instead
    /// of blocking it; the model work after the await resumes on the main
    /// actor, where the context needs it. Doing this synchronously in
    /// `onAppear` hung the first Library appearance long enough to break two
    /// UITest suites — the `LibraryGamePreviewView` lesson, in a new place.
    private func backfillClassifications() async {
        let table = await ECOTable.warmed()
        do {
            try PGNStore(modelContext: modelContext).backfillClassifications(using: table)
        } catch {
            Self.logger.error("Classification backfill failed: \(error.localizedDescription, privacy: .public)")
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
        let ordered = gamesInDisplayOrder(ids)
        guard !ordered.isEmpty else { return }
        Self.logger.info("Export requested: \(ordered.count) game(s)")
        PGNExporter.export(ordered)
    }
}

// MARK: Presentation Bindings

extension Binding where Value == Bool {
    /// A presentation flag over optional state: `true` while a value is
    /// present, and a dismissal clears the source. **Seven** `@State`
    /// optionals open-code the same getter/setter pair otherwise — four
    /// here, one in `ContentView` that couldn't see this while it was
    /// `fileprivate`, and two in `PlayersDestination` (M5's refusal alert
    /// and D40′'s orphan sweep).
    ///
    /// That count has now been wrong twice, in opposite directions: this
    /// comment said "five" until M5 and D40′ added a site each without
    /// touching it, and the instructions' forward note said "six" because
    /// it caught the first of those two and not the second. A caller count
    /// written into a doc comment is a claim about seven other files that
    /// nothing recompiles — which is the enumerated-caller-list anti-pattern
    /// the working agreements already name, kept here only because the
    /// forward note below needs to know how much disappears.
    ///
    /// `BoardDestination`'s offer bindings look identical and are deliberately
    /// **not** folded in: they ignore dismissal (`set: { _ in }` — D#3 is a
    /// fork, not a suggestion), and routing them through here would erase
    /// that. Same shape, different contract.
    ///
    /// **Waived, with a sunset condition.** These two captures are the app
    /// target's only strict-concurrency residue: `Binding` is not `Sendable`
    /// while `Binding.init(get:set:)` demands `@Sendable` closures, so the
    /// helper cannot hold the source without tripping it. Constraining
    /// `T: Sendable` would fix it and lock out the `@Model` call sites,
    /// which are most of them; the alternatives are the unsafe-`nonisolated`
    /// and unchecked-`Sendable` opt-outs this codebase has none of. (Both
    /// spelled around on purpose — writing either token verbatim would put a
    /// permanent false positive into the sweep's own prohibition grep.)
    /// Telling detail: the diagnostic stays a *warning* under language mode
    /// 6 rather than becoming an error, so the compiler is treating it as
    /// framework-side friction rather than a defect here. The 2027 SDK's
    /// item-based `alert` and `confirmationDialog` overloads retire all seven
    /// call sites and this helper with them — at which point the waiver is
    /// not lifted, it is deleted.
    ///
    /// Those two are spelled around as well, for the reason the paragraph
    /// above already gives about the concurrency tokens. The rule got applied
    /// to the prohibition grep the author was thinking about and not to the
    /// beta-surface grep in the next section of the same sweep, which is the
    /// whole failure mode: writing a token verbatim to explain why you must
    /// not is one keystroke away in every direction.
    internal init<T>(present source: Binding<T?>) {
        self.init(
            get: { source.wrappedValue != nil },
            set: { if !$0 { source.wrappedValue = nil } }
        )
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
    .environment(InspectorSectionCollapse.preview)
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
    .environment(InspectorSectionCollapse.preview)
}
