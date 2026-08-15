// Explicit: `selectAll(_:)` is an AppKit protocol member; MemberImportVisibility requires the import.
import AppKit
import os
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryDestination: View {
    
    // MARK: Static Constants
    private static let logger = AppLog.logger(.library)

    /// Above this many, Open asks first (D56′) — the one bulk action that confirms on count, not consequence.
    private static let openConfirmationThreshold = 10
    
    // MARK: Stored Properties
    let filter: LibraryFilter?
    
    /// Clears the active filter; owned by `ContentView` because a filter is a sidebar selection. Nil when unfiltered.
    let onClearFilter: (() -> Void)?
    
    // MARK: Tab State (lives on enclosing `ContentView`)
    @Bindable var tabState: TabState
    
    // MARK: Private Properties
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut
    // Shared with Players (StorageKeys.collectionViewMode); the `.list` default is the documented twin of PlayersDestination's.
    @AppStorage(StorageKeys.collectionViewMode) private var viewMode: CollectionViewMode = .list
    @Environment(\.modelContext) private var modelContext

    /// View Options panel subject — read here because this destination owns the sort.
    @Environment(CollectionViewOptions.self) private var options

    /// Resolves the key window's value: nil whenever another window is front, which is the signal the mirror needs.
    @FocusedValue(\.collectionViewOptionsSubject) private var focusedSubject

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(OpenGamesRegistry.self) private var openGames
    /// App-global: the queue window needs an owner a scene can reach.
    @Environment(AnalysisQueueController.self) private var analysisQueue
    @Query(sort: \PGN.importedAt, order: .reverse) private var games: [PGN]
    @State private var pendingDeletion: PGN?
    @State private var pendingDirtyDeletion: PGN?
    @State private var pendingBatchDeletion: [PGN]?

    /// D56′'s speed bump, held between offer and confirmation.
    @State private var pendingBatchOpen: [PGN]?
    @State private var selectedPGNs: Set<PGN.ID> = []
    @State private var importProgress: ImportProgress?

    /// Memo key for the `GameRecord` projection: content plus an analysis signal.
    /// The signal is the queue's counters, never the `evaluations` array — an array read would defeat the memo.
    /// Internal (not private) so the D78′ key-completeness suite can construct one.
    struct FoldKey: Equatable {
        let content: CollectionFoldKey
        let running: PersistentIdentifier?
        let completed: Int
        let hasFailures: Bool
    }

    /// The Library's `GameRecord` projection, memoized — rebuilt only when `FoldKey` moves.
    @State private var foldCache = CollectionFoldCache<FoldKey, [GameRecord]>()

    /// The narrowing inputs as one value (D78′): the projection's key plus everything filter,
    /// search and sort read. A missed input here is stale rows on screen — the suite pins the
    /// field list, which is the only defence a memo key has.
    struct NarrowKey: Equatable {
        let fold: FoldKey
        let filter: LibraryFilter.Signature?
        let query: String
        let tokens: [LibrarySearchToken]
        let sort: [KeyPathComparator<PGN>]
    }

    /// Narrowed pairs and their sorted projection, cached as one unit — the sort was the last
    /// unconditional per-render O(n log n) (the ECO comparator rehydrates per comparison, censused).
    struct NarrowResult {
        let pairs: [(game: PGN, record: GameRecord)]
        let sorted: [PGN]
    }

    @State private var narrowCache = CollectionFoldCache<NarrowKey, NarrowResult>()

    /// D58′ backfill result for the report alert; failure is separate state — it means the folder itself was unreadable.
    @State private var backfillReport: PGNStore.LibraryIndexBackfill?
    @State private var backfillFailure: String?
    
    // MARK: Search & Filters
    @State private var searchText = ""
    /// Non-text facets as chips inside the search field; the Filter menu stays the discoverable entry point.
    @State private var searchTokens: [LibrarySearchToken] = []

    /// List-mode column sort. Defaults to `#` descending (D58′). One comparator, so clicking `#` twice
    /// reproduces the launch order; ties are unordered (`sorted(using:)` is not stable). Display only.
    private var sortOrder: Binding<[KeyPathComparator<PGN>]> {
        Binding(
            get: { options.librarySort.comparators },
            set: { newValue in
                guard let sort = CollectionSort<LibrarySortField>(comparators: newValue) else { return }
                options.librarySort = sort
            }
        )
    }

    /// Launch order, stated once. `nonisolated`: `View` conformance would infer @MainActor and lock out previews.
    nonisolated static var defaultSortOrder: [KeyPathComparator<PGN>] {
        [KeyPathComparator(\PGN.libraryIndex, order: .reverse)]
    }
    
    // MARK: Initializers
    init(
        filter: LibraryFilter? = nil,
        tabState: TabState,
        onClearFilter: (() -> Void)? = nil
    ) {
        self.filter = filter
        self.tabState = tabState
        self.onClearFilter = onClearFilter
    }
    
    // MARK: Computed Properties
    
    /// One spelling of the projection's key, shared by the fold cache and the narrow key.
    private var currentFoldKey: FoldKey {
        FoldKey(
            content: CollectionFoldKey(games: games),
            running: analysisQueue.runningID,
            completed: analysisQueue.queue.completedCount,
            hasFailures: analysisQueue.queue.hasFailures
        )
    }

    /// Games paired with records, memoized. Zipped — index is the correspondence.
    private var pairedGames: [(game: PGN, record: GameRecord)] {
        let records = foldCache.value(for: currentFoldKey) {
            games.map(\.gameRecord)
        }
        // One argument: a two-parameter closure here is the tuple splat Swift 3 removed — reads right, won't compile.
        return zip(games, records).map { pair in (game: pair.0, record: pair.1) }
    }

    /// Sidebar filter → search → chips → sort, memoized as one unit (D78′): the walk and the sort
    /// re-run only when a `NarrowKey` input moves, not per render.
    private var narrowed: NarrowResult {
        narrowCache.value(
            for: NarrowKey(
                fold: currentFoldKey,
                filter: filter?.signature,
                query: searchText,
                tokens: searchTokens,
                sort: sortOrder.wrappedValue
            )
        ) {
            var result = pairedGames
            if let filter {
                result = result.filter { filter.matches($0.game, record: $0.record) }
            }
            // Guard skips only the walk; an empty query matches everything by contract.
            if !searchText.isEmpty {
                // Folded once per pass, not per row (`SearchMatch.Query`).
                let query = SearchMatch.Query(searchText)
                result = result.filter {
                    query.matches(fields: searchFields(of: $0.game))
                }
            }
            if !searchTokens.isEmpty {
                // `record.hasAnalysis` is `AnalysisGlyph.isAnalyzed`'s own input — still one spelling of "analyzed?".
                result = result.filter {
                    LibrarySearchToken.admit(
                        searchTokens,
                        result: $0.record.result,
                        isAnalyzed: $0.record.hasAnalysis
                    )
                }
            }
            return NarrowResult(
                pairs: result,
                sorted: result.map { $0.game }.sorted(using: sortOrder.wrappedValue)
            )
        }
    }

    /// Sidebar filter → search → chips, narrowing only; every bulk action reads this same narrowed set.
    /// Narrowed but not sorted — the sort is `filteredGames`' last stage.
    private var narrowedPairs: [(game: PGN, record: GameRecord)] { narrowed.pairs }

    /// The narrowed list in display order — what every consumer outside the render pass wants.
    /// Render reads it once; actions re-derive fresh (a re-read of the cache recomputes iff an
    /// input moved, which is the same correctness, cheaper). Sort is unconditional.
    private var filteredGames: [PGN] { narrowed.sorted }
    
    /// A game's searchable strings — every field, always; a query already names its own field.
    private func searchFields(of game: PGN) -> [String] {
        [game.name, game.whiteDisplayName, game.blackDisplayName,
         game.event, game.site, game.result.rawValue,
         game.opening?.code, game.opening?.fullName].compactMap { $0 }
    }
    
    /// "No matches" vs. "no games" for the empty gate.
    private var isNarrowedBySearchOrFilters: Bool {
        !searchText.isEmpty || !searchTokens.isEmpty
    }
    
    private var hasActiveMenuFilters: Bool {
        !searchTokens.isEmpty
    }
    
    /// Nil for empty *and* multiple: the inspector details one thing, never an arbitrary member of a set.
    private func selectedPGN(in games: [PGN]) -> PGN? {
        guard selectedPGNs.count == 1, let id = selectedPGNs.first else { return nil }
        return games.first(where: { $0.id == id })
    }
    
    /// Selection → models in display order. Load-bearing twice: queue order, and D24′ export numbers filenames from it.
    private func gamesInDisplayOrder(_ ids: Set<PGN.ID>) -> [PGN] {
        filteredGames.filter { ids.contains($0.id) }
    }

    /// ⌘A as the system's Edit ▸ Select All, riding the responder chain (search field and tables answer first;
    /// empty list disables the item). Selects the painted list; the icons grid's arrow anchor stays where clicked.
    private func selectAll(_ games: [PGN]) {
        selectedPGNs = Set(games.map(\.id))
    }


    // MARK: Body
    var body: some View {
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
                    Text(Self.deletionMessage(
                        for: [game],
                        lead: "\(game.name) will be permanently deleted."
                    ))
                }
            )
            // Always reports, including "nothing matched" — a silent scan looks like a scan that never ran.
            .alert(
                "Matched \(backfillReport?.stamped ?? 0) Games",
                isPresented: Binding(present: $backfillReport),
                presenting: backfillReport,
                actions: { _ in Button("OK") {} },
                message: { report in Text(Self.backfillMessage(for: report)) }
            )
            .alert(
                "Couldn’t Read That Folder",
                isPresented: Binding(present: $backfillFailure),
                presenting: backfillFailure,
                actions: { _ in Button("OK") {} },
                message: { reason in Text(reason) }
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
                    Text(Self.deletionMessage(
                        for: games,
                        lead: "\(games.count) games will be permanently deleted. This can't be undone."
                    ))
                }
            )
            // Plain ⌫ deliberately does not delete (one slip from a forgotten multi-selection); ⌘⌫ is the only key,
            // resting on the row menu's copy — known only to render, an open question rather than settled.
            .focusedSceneValue(
                \.collectionViewOptionsSubject,
                CollectionViewOptionsSubject(collection: .library, mode: viewMode)
            )
            // Mirrors the focused subject into the global options object — this view is on screen while its window is key;
            // the panel never is. Only non-nil writes land, so focus moving away keeps the last collection.
            .onChange(of: focusedSubject, initial: true) { _, newValue in
                guard let newValue else { return }
                options.activeSubject = newValue
            }
            .onAppear {
                backfillEmptyNames()
                backfillPlayerLinks()
                applyInspectorPolicy(for: viewMode)
            }
        // `.task`: has to await the ECO table — see `backfillClassifications()`.
            .task {
                await backfillClassifications()
            }
            .onChange(of: viewMode) { _, mode in
                applyInspectorPolicy(for: mode)
            }
    }
    
    /// Split from the deletion alerts: one combined modifier chain blew SwiftUI's type-check budget.
    private var coreContent: some View {
        // One walk per render — consumers below read these locals; none re-runs the filter.
        let narrowed = narrowedPairs
        let games = narrowed.map { $0.game }.sorted(using: sortOrder.wrappedValue)
        let unanalyzedCount = narrowed.count { !$0.record.hasAnalysis }
        // Row badges (D72′): membership built once per render off the same records — one spelling of "analyzed?".
        let analyzedIDs = Set(
            narrowed.lazy.filter { $0.record.hasAnalysis }.map { $0.game.id }
        )
        // Hoisted so the nil arm reads as the decision: no games ⇒ Select All disabled by the system.
        let selectAllAction: (() -> Void)? = games.isEmpty
        ? nil
        : { selectAll(games) }
        return VStack(spacing: 0) {
            if let filter {
                filterChipBar(for: filter)
                Divider()
            }
            Group {
                if games.isEmpty {
                    // Two vocabularies: an empty library invites importing; an empty result set names the narrowing.
                    // Identifier stays on the true empty state (D51′).
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
                    modeView(games: games, analyzedIDs: analyzedIDs)
                }
            }
            .accessibilityIdentifier(AccessibilityID.libraryContent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Here because the painted `games` local defines ⌘A (and `body`'s chain is at its type-check budget).
            .onCommand(
                #selector(NSStandardKeyBindingResponding.selectAll(_:)),
                perform: selectAllAction
            )
            // D56′'s threshold. Not `role: .destructive` — opening destroys nothing; the dialog is about volume.
            .alert(
                "Open \(pendingBatchOpen?.count ?? 0) Games?",
                isPresented: Binding(present: $pendingBatchOpen),
                presenting: pendingBatchOpen,
                actions: { games in
                    Button("Open \(games.count) Games") { performOpen(games) }
                    Button("Cancel", role: .cancel) {}
                },
                message: { games in
                    Text("Each opens in its own tab. Games already open will come forward rather than open again, so this may end up fewer than \(games.count).")
                }
            )
        }
        .navigationTitle(filter?.displayName ?? "Library")
        // Counted over `filteredGames`: the subtitle describes what you see; the backlog clause vanishes at zero.
        .navigationSubtitle(
            DestinationSubtitle.library(
                selected: selectedPGNs.count,
                unanalyzed: unanalyzedCount
            ) ?? ""
        )
        .dropDestination(for: URL.self) { urls, _ in
            Self.logger?.info("Drop received: \(urls.count) URL(s)")
            importURLs(urls)
            return true
        }
        .inspector(isPresented: $tabState.libraryInspectorPresented) {
            LibraryInspectorView(
                pgn: selectedPGN(in: games),
                selectionCount: selectedPGNs.count
            )
            .inspectorColumnWidth(min: 335, ideal: 335, max: 400)
        }
        // The one write of the glyph's ambient state — applied once so the four modes cannot disagree.
        .environment(\.analysisRunningGameID, analysisQueue.runningID)
        .toolbar { toolbarContent }
        // Tokens ahead of the text; suggestions exclude chips already applied.
        .searchable(
            text: $searchText,
            tokens: $searchTokens,
            suggestedTokens: .constant(
                LibrarySearchToken.allCases.filter { !searchTokens.contains($0) }
            ),
            placement: .toolbarPrincipal,
            prompt: "Search Games"
        ) { token in
            tokenLabel(token)
        }
        .sheet(isPresented: Binding(present: $importProgress)) {
            if let importProgress {
                ImportStatusView(progress: importProgress) {
                    self.importProgress = nil
                }
                // ⎋ bypasses the disabled footer button; dismissing mid-run would let the rest of the batch import invisibly.
                .interactiveDismissDisabled(!importProgress.isFinished)
            }
        }
    }
    
    /// Clearable filter chip. For a programmatic player filter it is the whole UI — the state's one face and exit.
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
    private func modeView(games: [PGN], analyzedIDs: Set<PGN.ID>) -> some View {
        switch viewMode {
        case .icons:
            LibraryIconsView(
                games: games,
                analyzedIDs: analyzedIDs,
                selectedPGNs: $selectedPGNs,
                onOpen:    openGames,
                onAnalyze: requestAnalysis,
                onExport:  requestExport,
                onDelete:  { pendingDeletion = $0 }
            )
            .accessibilityIdentifier(AccessibilityID.libraryModeIcons)
        case .list:
            LibraryListView(
                games: games,
                analyzedIDs: analyzedIDs,
                selectedPGNs: $selectedPGNs,
                onOpen:       openGames,
                onAnalyzeIDs: { requestAnalysis(ids: $0) },
                onExportIDs:  { requestExport(ids: $0) },
                onDeleteIDs:  { requestDelete(ids: $0) },
                sortOrder:    sortOrder
            )
            .accessibilityIdentifier(AccessibilityID.libraryModeList)
        case .columns:
            LibraryColumnsView(
                games: games,
                analyzedIDs: analyzedIDs,
                selectedPGNs: $selectedPGNs,
                boardStyle: boardStyle,
                onOpen:    openGames,
                onAnalyze: requestAnalysis,
                onExport:  requestExport,
                onDelete:  { pendingDeletion = $0 },
                sortOrder: sortOrder
            )
            .accessibilityIdentifier(AccessibilityID.libraryModeColumns)
        case .gallery:
            LibraryGalleryView(
                games: games,
                analyzedIDs: analyzedIDs,
                selectedPGNs: $selectedPGNs,
                boardStyle: boardStyle,
                onOpen:    openGames,
                onAnalyze: requestAnalysis,
                onExport:  requestExport,
                onDelete:  { pendingDeletion = $0 }
            )
            .accessibilityIdentifier(AccessibilityID.libraryModeGallery)
        }
    }
    
    /// One resolution point for "open these in windows" (D56′). macOS dedups and tabs, which makes the plural
    /// safe; arrives and stays in display order — visible here as tab order.
    private func openGames(_ pgns: [PGN]) {
        guard !pgns.isEmpty else { return }
        if pgns.count > Self.openConfirmationThreshold {
            pendingBatchOpen = pgns
        } else {
            performOpen(pgns)
        }
    }

    /// The unguarded half, reached either directly or from the confirmation.
    private func performOpen(_ pgns: [PGN]) {
        Self.logger?.info("Open requested: \(pgns.count) game(s)")
        for pgn in pgns {
            openWindow(value: pgn.persistentModelID)
        }
    }
    
    /// Single-game entry: enqueue (a batch of one), select, surface the inspector showing progress.
    private func requestAnalysis(_ pgn: PGN) {
        Self.logger?.info("Analyze requested: '\(pgn.name, privacy: .public)'")
        selectedPGNs = [pgn.id]
        // Not in columns mode: its detail pane already shows the game; forcing the inspector would reintroduce overflow.
        if !viewMode.ownsDetailPane {
            tabState.libraryInspectorPresented = true
        }
        analysisQueue.enqueue([pgn], modelContext: modelContext)
    }
    
    /// The two modes with inspector opinions, in one place so `onAppear` and `onChange` cannot disagree:
    /// gallery forces open (it is a picker), columns forces shut. Leaving columns does not restore.
    private func applyInspectorPolicy(for mode: CollectionViewMode) {
        if mode.ownsDetailPane {
            tabState.libraryInspectorPresented = false
        } else if mode == .gallery {
            tabState.libraryInspectorPresented = true
        }
    }

    /// Multi-game entry: enqueues in display order; leaves selection and inspector untouched.
    private func requestAnalysis(ids: Set<PGN.ID>) {
        let ordered = gamesInDisplayOrder(ids)
        guard !ordered.isEmpty else { return }
        if ordered.count == 1 {
            requestAnalysis(ordered[0])
            return
        }
        Self.logger?.info("Batch analyze requested: \(ordered.count) game(s)")
        analysisQueue.enqueue(ordered, modelContext: modelContext)
    }
    
    /// Named groups: `ToolbarContentBuilder` tops out at ten statements.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        filterToolbarItem
        ToolbarSpacer(.fixed)
        // No `.fixed` break: the queue item is conditional; a spacer would gap with nothing on one side most of the time.
        queueToolbarItem
        ToolbarSpacer(.fixed)
        transferToolbarItems
        ToolbarSpacer(.fixed)
        trailingToolbarItems
    }
    
    /// The search-independent half; stays a menu (the discoverable entry point), content side of the break.
    @ToolbarContentBuilder
    private var filterToolbarItem: some ToolbarContent {
        ToolbarItem {
            Menu {
                // Toggles, not a picker: the state stopped being single-valued ("1-0 and 0-1" must be expressible).
                ForEach(LibrarySearchToken.allCases) { token in
                    Toggle(isOn: binding(for: token)) {
                        tokenLabel(token)
                    }
                }
                if hasActiveMenuFilters {
                    Divider()
                    Button("Clear Filters") { searchTokens.removeAll() }
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

    /// One token rendering for chip and menu row, so the two cannot drift. State arrives as a literal —
    /// a facet never consults the queue.
    @ViewBuilder
    private func tokenLabel(_ token: LibrarySearchToken) -> some View {
        switch token {
        case .analyzed:   AnalysisLabel(state: .analyzed, title: token.displayName)
        case .unanalyzed: AnalysisLabel(state: .unanalyzed, title: token.displayName)
        case .result:     Label(token.displayName, systemImage: token.symbol)
        }
    }

    /// Membership as a `Binding<Bool>`; appends so chips sit in the order they were chosen.
    private func binding(for token: LibrarySearchToken) -> Binding<Bool> {
        Binding(
            get: { searchTokens.contains(token) },
            set: { isOn in
                if isOn {
                    if !searchTokens.contains(token) { searchTokens.append(token) }
                } else {
                    searchTokens.removeAll { $0 == token }
                }
            }
        )
    }
    
    /// File doors: in, out, and — only while some game lacks an ordinal — reconcile. No spacer: adjacent
    /// items share a capsule. The third item vanishes at zero rather than sitting disabled (D40′).
    @ToolbarContentBuilder
    private var transferToolbarItems: some ToolbarContent {
        ToolbarItem {
            Button {
                presentOpenPanel()
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .help("Import PGN files")
            .accessibilityIdentifier(AccessibilityID.libraryImportButton)
        }
        // The presence scan reads `games` rather than asking the store, deliberately.
        if games.contains(where: { $0.libraryIndex == nil }) {
            ToolbarItem {
                Button {
                    presentBackfillPanel()
                } label: {
                    Label("Match Folder", systemImage: "number.square")
                }
                .help("Fill in missing library numbers by matching a folder of PGN files")
                .accessibilityIdentifier(AccessibilityID.libraryBackfillButton)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var viewModeToolbarItem: some ToolbarContent {
        ToolbarItem {
            // NOTE: a `.segmented` Picker from `Label(_:systemImage:)` renders icon-only; AX keys segments by
            // SF Symbol name, not per-segment identifier — only the picker container is tagged.
            Picker("View Mode", selection: $viewMode) {
                ForEach(CollectionViewMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(AccessibilityID.libraryViewModePicker)
        }
    }
    
    /// Only the queue status item remains — Analyze, Delete and Export moved to the row menus by request.
    @ToolbarContentBuilder
    private var queueToolbarItem: some ToolbarContent {
        // Visible while a batch runs or failures are unacknowledged — see `queueStatusLabel`.
        if analysisQueue.queue.isActive || analysisQueue.queue.hasFailures {
            ToolbarItem {
                Button {
                    // Window, not popover; `openWindow(id:)` — one queue, singleton scene, nothing to route (no D46′ wrapper).
                    openWindow(id: AnalysisQueueStatusWindowView.sceneID)
                } label: {
                    queueStatusLabel
                }
                .help("Show the analysis queue")
                .accessibilityIdentifier(AccessibilityID.libraryQueueStatus)
            }
        }
    }
    
    /// Pinned tail, shared with Players: inspector toggle trailing-most, view-mode picker beside it; `.fixed` spacer.
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
            // Disabled, not hidden — vanishing on a mode switch reads as a glitch; the guard is producible (D40′).
            .disabled(viewMode.ownsDetailPane)
            .help(viewMode.ownsDetailPane
                  ? "Columns view shows details in its own pane"
                  : "Show or hide the inspector")
            .accessibilityIdentifier(AccessibilityID.libraryInspectorToggle)
        }
    }
    
    /// Gear + count while live; warning + counts after a failed drain, until Clear acknowledges — an error is
    /// never swallowed by the batch ending. A clean drain hides it. Drawn through `AnalyzingGear` with `AnalysisLabel`.
    private var queueStatusLabel: some View {
        HStack(spacing: 6) {
            if analysisQueue.queue.isActive {
                AnalyzingGear()
            } else {
                Image(systemName: "exclamationmark.triangle")
            }
            // `batchPosition`, not `completedCount` — the queue owns the arithmetic; both surfaces read it.
            Text("\(analysisQueue.queue.batchPosition)/\(analysisQueue.queue.totalCount)")
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

    /// D58′ backfill: point at the folder; the content hash decides which row each file is.
    /// Stamps one `Int?` per match — never resolves players, classifies or rehashes.
    private func presentBackfillPanel() {
        let panel = NSOpenPanel()
        panel.title = "Match Folder to Library"
        panel.prompt = "Match"
        panel.message = "Choose the folder your PGN files live in. "
            + "Games already in the Library will take the number their file carries."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        guard panel.runModal() == .OK, let folder = panel.url else { return }

        do {
            backfillReport = try PGNStore(modelContext: modelContext)
                .backfillLibraryIndices(from: folder)
        } catch {
            Self.logger?.error(
                "Library index backfill failed: \(error.localizedDescription, privacy: .public)"
            )
            backfillReport = nil
            backfillFailure = error.localizedDescription
        }
    }
    
    private func importURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        Task { await runImport(urls) }
    }
    
    /// Per-file results, never aborts on one failure; main-actor (ModelContext), yielding so progress animates.
    @MainActor
    private func runImport(_ urls: [URL]) async {
        Self.logger?.info("Import batch starting: \(urls.count) URL(s)")
        let store = PGNStore(modelContext: modelContext)
        importProgress = ImportProgress(total: urls.count)
        
        for url in urls {
            let outcome: ImportResult.Outcome
            do {
                let pgn = try store.importPGN(from: url)
                outcome = .imported(name: pgn.name)
            } catch let error as PGNStore.Error {
                Self.logger?.error("Import failed for \(url.lastPathComponent, privacy: .public)")
                outcome = .failed(error)
            } catch {
                Self.logger?.error("Import failed for \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
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
        Self.logger?.info("Import batch complete: \(imported)/\(urls.count) imported")
    }
    
    /// Confirmation body; players clause appended only when the cascade would take any.
    /// Advisory — `PGNStore.delete(_:)` recomputes at write time.
    private static func deletionMessage(for games: [PGN], lead: String) -> String {
        let stranded = PGNStore.playersOrphaned(byDeleting: games)
        guard !stranded.isEmpty else { return lead }
        let shown = stranded.prefix(5).map(\.name)
        let more = stranded.count > shown.count
        ? " And \(stranded.count - shown.count) more."
        : ""
        let subject = shown.joined(separator: ", ")
        let clause = stranded.count == 1
        ? "\(subject) is in no other game and will be removed from Players."
        : "\(subject) are in no other games and will be removed from Players."
        return lead + " " + clause + more
    }

    /// Leads with what did not happen when nothing did; `unmatched` is a finding, not a fault (three names max).
    private static func backfillMessage(for report: PGNStore.LibraryIndexBackfill) -> String {
        guard report.scanned > 0 else {
            return "That folder has no PGN files in it."
        }
        guard report.stamped > 0 || report.alreadyNumbered > 0 else {
            return "Scanned \(report.scanned) file\(report.scanned == 1 ? "" : "s") and matched "
            + "none of them to games in your Library. If these are your games, "
            + "check that you picked the folder they were imported from."
        }

        var parts: [String] = []
        if report.stamped > 0 {
            parts.append("Numbered \(report.stamped) game\(report.stamped == 1 ? "" : "s").")
        }
        if report.alreadyNumbered > 0 {
            parts.append("\(report.alreadyNumbered) already had a number and were left alone.")
        }
        if !report.unmatched.isEmpty {
            let shown = report.unmatched.prefix(3).joined(separator: ", ")
            let more = report.unmatched.count > 3
            ? " and \(report.unmatched.count - 3) more"
            : ""
            parts.append("\(report.unmatched.count) file\(report.unmatched.count == 1 ? " is" : "s are") "
                         + "not in your Library yet (\(shown)\(more)).")
        }
        if !report.unnumbered.isEmpty {
            parts.append("\(report.unnumbered.count) filename\(report.unnumbered.count == 1 ? " carries" : "s carry") no number.")
        }
        if !report.skipped.isEmpty {
            parts.append("\(report.skipped.count) couldn’t be read.")
        }
        return parts.joined(separator: " ")
    }

    /// Delete for an id set: one game reuses the single-game flow (dirty confirmation); more go to batch confirmation.
    private func requestDelete(ids: Set<PGN.ID>) {
        let games = gamesInDisplayOrder(ids)
        guard !games.isEmpty else { return }
        if games.count == 1 {
            // Through the alert — a single game must confirm like a batch does; the dirty-changes fork is unchanged.
            pendingDeletion = games[0]
        } else {
            pendingBatchDeletion = games
        }
    }
    
    /// One transaction; closes open tabs first. Unsaved changes discarded without prompt — acceptable while
    /// the dirty path is dormant (no editor defers writes yet).
    private func performBatchDelete(_ pgns: [PGN]) {
        for pgn in pgns {
            let id = pgn.persistentModelID
            // Before the store delete — see `performDelete` for the why.
            analysisQueue.gameWasDeleted(id)
            openGames.markClean(id)
            // Close the tab before teardown so it never renders a tombstoned PGN.
            dismissWindow(value: id)
        }
        selectedPGNs.removeAll()
        
        let store = PGNStore(modelContext: modelContext)
        do {
            try store.delete(pgns)
        } catch {
            Self.logger?.error(
                "Failed to batch-delete \(pgns.count) PGNs: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
    
    /// From "Delete Game?": dirty+open routes to a discard confirmation; otherwise deletes immediately.
    /// The dirty arm is unreachable today by design — no editor defers writes (see `OpenGamesRegistry.markDirty`).
    private func delete(_ pgn: PGN) {
        if openGames.isDirty(pgn.persistentModelID) {
            pendingDirtyDeletion = pgn
        } else {
            performDelete(pgn)
        }
    }
    
    /// Deletes and closes any tab showing the game; `dismissWindow(value:)` is a no-op when none is.
    private func performDelete(_ pgn: PGN) {
        let id = pgn.persistentModelID
        selectedPGNs.remove(pgn.id)
        // Before the store delete: `gameWasDeleted` stops the running pass synchronously — the engine never
        // writes into a tombstoned model.
        analysisQueue.gameWasDeleted(id)
        openGames.markClean(id)
        
        // Close the tab before teardown so it never renders a tombstoned PGN.
        dismissWindow(value: id)
        
        let store = PGNStore(modelContext: modelContext)
        do {
            try store.delete(pgn)
        } catch {
            Self.logger?.error("Failed to delete PGN: \(error.localizedDescription, privacy: .public)")
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
            Self.logger?.info(
                "Backfilled \(toFix.count) legacy game name(s): \(healed, privacy: .public)"
            )
        } catch {
            Self.logger?.error("Name backfill save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// Store-owned and idempotent; both collection destinations call it on appear. Behind the
    /// converged stamp since D75′ — the healed steady state skips the scan. This is the Library's error sink.
    private func backfillPlayerLinks() {
        do {
            try PGNStore(modelContext: modelContext).healPlayersIfNeeded()
        } catch {
            Self.logger?.error("Player-link backfill failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// D34′'s eager half: heals pre-M4 rows on appearance so an opening name never costs a depth-18 re-run.
    private func backfillClassifications() async {
        let table = await ECOTable.warmed()
        do {
            try PGNStore(modelContext: modelContext).backfillClassifications(using: table)
        } catch {
            Self.logger?.error("Classification backfill failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: Export (D24′)
    
    /// Single-game entry: a save panel — the user names the file.
    private func requestExport(_ pgn: PGN) {
        Self.logger?.info("Export requested: '\(pgn.name, privacy: .public)'")
        PGNExporter.export([pgn])
    }
    
    /// Multi-game entry; resolves against `filteredGames` — the order numbers the filenames (D24′).
    private func requestExport(ids: Set<PGN.ID>) {
        let ordered = gamesInDisplayOrder(ids)
        guard !ordered.isEmpty else { return }
        Self.logger?.info("Export requested: \(ordered.count) game(s)")
        PGNExporter.export(ordered)
    }
}

// MARK: Presentation Bindings

extension Binding where Value == Bool {
    /// Presentation flag over optional state: true while present; dismissal clears the source.
    /// `BoardDestination`'s offer bindings look identical and are deliberately not folded in — they ignore dismissal.
    /// Waived warning ×2: non-Sendable `Binding` captured in `@Sendable` closures; expires by deletion when
    /// `.alert(item:)` ships (D43′ — the register's one compiler-warning waiver).
    init<T>(present source: Binding<T?>) {
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
