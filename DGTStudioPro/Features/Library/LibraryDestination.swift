// Explicit: `selectAll(_:)` is an AppKit protocol member; MemberImportVisibility requires the import.
import AppKit
import os
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryDestination: View {
    
    // MARK: Static Constants
    private static let logger = AppLog.logger(.library)

    /// Above this many, Open asks first - the one bulk action that confirms on count, not consequence.
    private static let openConfirmationThreshold = 10
    
    // MARK: Stored Properties
    let filter: LibraryFilter?
    
    /// Clears the active filter; owned by `ContentView` because a filter is a sidebar selection. Nil when unfiltered.
    let onClearFilter: (() -> Void)?

    /// Loads a game into the tab the reader is already in (17 Aug 2026). Optional: previews
    /// and any future host without a Board destination to point at simply don't supply it.
    let onOpenInPlace: ((PGN) -> Void)?
    
    // MARK: Tab State (lives on enclosing `ContentView`)
    @Bindable var tabState: TabState
    
    // MARK: Private Properties
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut
    // Per-destination since 18 Aug 2026, and owned by `CollectionViewOptions` rather than read here:
    // that retires the `.list` twin PlayersDestination carried, and lets the stored value fall back
    // to the retired shared key, which an `@AppStorage` literal default never could.
    private var viewMode: CollectionViewMode { options.libraryViewMode }

    /// What this destination tells the ⌘J panel it is. Constructed once and used twice - published
    /// as the focused value and latched into `options` - so the two can never disagree, which the
    /// old arrangement guaranteed only by routing the second through the first.
    private var subject: CollectionViewOptionsSubject {
        CollectionViewOptionsSubject(collection: .library, mode: viewMode)
    }

    /// The mirror, gated on this window being key. Non-key windows stay silent rather than writing
    /// nil, so a second browser window in the background cannot claim the panel, and focus moving
    /// to the panel itself leaves the last browser's subject standing.
    private func latchSubjectIfKey() {
        guard controlActiveState == .key else { return }
        options.activeSubject = subject
    }

    /// Built by hand rather than projected with `@Bindable`, because the picker lives in a computed
    /// `@ToolbarContentBuilder` property, which cannot declare one.
    private var viewModeBinding: Binding<CollectionViewMode> {
        Binding(get: { options.libraryViewMode }, set: { options.libraryViewMode = $0 })
    }
    @Environment(\.modelContext) private var modelContext

    /// View Options panel subject - read here because this destination owns the sort.
    @Environment(CollectionViewOptions.self) private var options

    /// Is this destination's window the key one? Asked directly, and that is the fix for the
    /// launch-time `FocusedValue update tried to update multiple times per frame` line (18 Aug
    /// 2026). This read used to be `@FocusedValue(\.collectionViewOptionsSubject)` - the very key
    /// this view *publishes* four hundred lines down, so the body depended on its own output:
    /// publish → self-read invalidates → body re-runs → publish, inside one update pass, which is
    /// what the warning names. `nil → value` at first render is the one transition
    /// `CollectionViewOptionsSubject`'s `Equatable` conformance cannot dedupe, which is why the
    /// line appeared at launch and never again.
    ///
    /// `CollectionViewOptionsWindow` had already found this shape and fixed it there - "a pure
    /// reader, no `@FocusedValue` here, and that is the fix" - and the two destinations carrying
    /// the same pair were missed. Shipping macOS API, deliberately not the 2027 SDK's
    /// `\.appearsActive`, which is the tidier spelling and a forward note under D27′.
    @Environment(\.controlActiveState) private var controlActiveState

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(OpenGamesRegistry.self) private var openGames
    /// App-global: the queue window needs an owner a scene can reach.
    @Environment(AnalysisQueueController.self) private var analysisQueue
    @Query(sort: \PGN.importedAt, order: .reverse) private var games: [PGN]
    @State private var pendingDeletion: PGN?
    @State private var pendingDirtyDeletion: PGN?
    @State private var pendingBatchDeletion: [PGN]?

    /// The speed bump, held between offer and confirmation.
    @State private var pendingBatchOpen: [PGN]?
    @State private var selectedPGNs: Set<PGN.ID> = []
    @State private var importProgress: ImportProgress?

    /// The Library's `GameRecord` projection, memoized - rebuilt only when `FoldKey` moves.
    /// (`FoldKey`, `NarrowKey` and `NarrowResult` live in `LibraryFold.swift`.)
    @State private var foldCache = CollectionFoldCache<FoldKey, [GameRecord]>()

    @State private var narrowCache = CollectionFoldCache<NarrowKey, NarrowResult>()

    /// The backfill result for the report alert; failure is separate state - it means the folder itself was unreadable.
    @State private var backfillReport: PGNStore.LibraryIndexBackfill?
    @State private var backfillFailure: String?
    
    // MARK: Search & Filters
    @State private var searchText = ""
    /// Non-text facets as chips inside the search field; the Filter menu stays the discoverable entry point.
    @State private var searchTokens: [LibrarySearchToken] = []

    /// List-mode column sort. Defaults to `#` descending. One comparator, so clicking `#` twice
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
        onClearFilter: (() -> Void)? = nil,
        onOpenInPlace: ((PGN) -> Void)? = nil
    ) {
        self.filter = filter
        self.tabState = tabState
        self.onClearFilter = onClearFilter
        self.onOpenInPlace = onOpenInPlace
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

    /// Games paired with records, memoized. Zipped - index is the correspondence.
    private var pairedGames: [(game: PGN, record: GameRecord)] {
        let records = foldCache.value(for: currentFoldKey) {
            games.map(\.gameRecord)
        }
        // One argument: a two-parameter closure here is the tuple splat Swift 3 removed - reads right, won't compile.
        return zip(games, records).map { pair in (game: pair.0, record: pair.1) }
    }

    /// Sidebar filter → search → chips → sort, memoized as one unit: the walk and the sort
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
                // `record.hasAnalysis` is `AnalysisGlyph.isAnalyzed`'s own input - still one spelling of "analyzed?".
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
    /// Narrowed but not sorted - the sort is `filteredGames`' last stage.
    private var narrowedPairs: [(game: PGN, record: GameRecord)] { narrowed.pairs }

    /// The narrowed list in display order - what every consumer outside the render pass wants.
    /// Render reads it once; actions re-derive fresh (a re-read of the cache recomputes iff an
    /// input moved, which is the same correctness, cheaper). Sort is unconditional.
    private var filteredGames: [PGN] { narrowed.sorted }
    
    /// A game's searchable strings - every field, always; a query already names its own field.
    private func searchFields(of game: PGN) -> [String] {
        [game.name, game.whiteDisplayName, game.blackDisplayName,
         game.event, game.site, game.result.rawValue,
         game.opening?.code, game.opening?.fullName].compactMap { $0 }
    }
    
    /// "No matches" vs. "no games" for the empty gate.
    private var isNarrowedBySearchOrFilters: Bool {
        !searchText.isEmpty || !searchTokens.isEmpty
    }
    
    /// Nil for empty *and* multiple: the inspector details one thing, never an arbitrary member of a set.
    private func selectedPGN(in games: [PGN]) -> PGN? {
        guard selectedPGNs.count == 1, let id = selectedPGNs.first else { return nil }
        return games.first(where: { $0.id == id })
    }
    
    /// Selection → models in display order. Load-bearing twice: queue order, and export numbers
    /// filenames from it. The algebra is `CollectionSelection`'s (M18 Phase 2), pinned there.
    private func gamesInDisplayOrder(_ ids: Set<PGN.ID>) -> [PGN] {
        CollectionSelection.inDisplayOrder(ids, of: filteredGames)
    }

    /// ⌘A as the system's Edit ▸ Select All, riding the responder chain (search field and tables answer first;
    /// empty list disables the item). Selects the painted list; the icons grid's arrow anchor stays where clicked.
    private func selectAll(_ games: [PGN]) {
        selectedPGNs = CollectionSelection.allIDs(of: games)
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
                    Text(LibraryMessages.deletion(
                        for: [game],
                        lead: "\(game.name) will be permanently deleted."
                    ))
                }
            )
            // Always reports, including "nothing matched" - a silent scan looks like a scan that never ran.
            .alert(
                "Matched \(backfillReport?.stamped ?? 0) Games",
                isPresented: Binding(present: $backfillReport),
                presenting: backfillReport,
                actions: { _ in Button("OK") {} },
                message: { report in Text(LibraryMessages.backfill(for: report)) }
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
                    Text(LibraryMessages.deletion(
                        for: games,
                        lead: "\(games.count) games will be permanently deleted. This can't be undone."
                    ))
                }
            )
            // Plain ⌫ deliberately does not delete (one slip from a forgotten multi-selection); ⌘⌫ is the only key,
            // resting on the row menu's copy - known only to render, an open question rather than settled.
            // Published for `CollectionViewOptionsCommands`, which reads it to enable ⌘J - a writer
            // here and a reader in a `Commands` scene is the shape that does not cycle. This view
            // no longer reads it back; see `controlActiveState`.
            .focusedSceneValue(\.collectionViewOptionsSubject, subject)
            // Mirrors this destination's subject into the global options object while its window is
            // key, so the panel - which is never key while a browser is - reads the last browser
            // rather than nothing. Latched from three places rather than one `onChange(initial:)`:
            // the subject changing, the window becoming key, and arrival. Arrival is `onAppear`
            // rather than `initial: true` deliberately - it runs *after* the first render instead
            // of during it, so the `@Observable` write cannot land inside the update pass this
            // whole change exists to keep quiet.
            .onChange(of: subject) { _, _ in latchSubjectIfKey() }
            .onChange(of: controlActiveState) { _, _ in latchSubjectIfKey() }
            .onAppear {
                latchSubjectIfKey()
                backfillEmptyNames()
                // Store-owned and idempotent, behind the converged stamp; both collection
                // destinations call it on appear, under their own console category.
                PGNStore.healPlayers(in: modelContext, logger: Self.logger)
                applyInspectorPolicy(for: viewMode)
            }
        // `.task`: has to await the ECO table - see `backfillClassifications()`.
            .task {
                await backfillClassifications()
            }
            .onChange(of: viewMode) { _, mode in
                applyInspectorPolicy(for: mode)
            }
    }
    
    /// Split from the deletion alerts: one combined modifier chain blew SwiftUI's type-check budget.
    private var coreContent: some View {
        // One walk per render - consumers below read these locals; none re-runs the filter.
        let narrowed = narrowedPairs
        // **`filteredGames`, not a second sort** (21 Aug 2026): `NarrowResult.sorted` already holds
        // exactly `pairs.map(\.game).sorted(using: sortOrder)`, memoized under the same `NarrowKey`.
        // Spelling the expression again here bypassed the memo and paid the O(n log n) - and the ECO
        // comparator's per-comparison rehydration - a second time, every render. The memo's whole
        // reason for existing was that this sort was the last unconditional per-render sort.
        let games = filteredGames
        let unanalyzedCount = narrowed.count { !$0.record.hasAnalysis }
        // Row badges: membership built once per render off the same records - one spelling of "analyzed?".
        let analyzedIDs = Set(
            narrowed.lazy.filter { $0.record.hasAnalysis }.map { $0.game.id }
        )
        // Hoisted so the nil arm reads as the decision: no games ⇒ Select All disabled by the system.
        let selectAllAction: (() -> Void)? = games.isEmpty
        ? nil
        : { selectAll(games) }
        return VStack(spacing: 0) {
            if let filter {
                LibraryFilterChipBar(filter: filter, onClear: onClearFilter)
                Divider()
            }
            Group {
                if games.isEmpty {
                    // Two vocabularies: an empty library invites importing; an empty result set names the narrowing.
                    // Identifier stays on the true empty state.
                    if isNarrowedBySearchOrFilters {
                        ContentUnavailableView(
                            "No Matches",
                            systemImage: "magnifyingglass",
                            description: Text("No games match the current search or filters.")
                        )
                    } else {
                        LibraryEmptyStateView(filter: filter)
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
            // The threshold. Not `role:.destructive` - opening destroys nothing; the dialog is about volume.
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
            // Pinned to the app-wide width (min = ideal = max: sameness beats drag-resize) -
            // `InspectorColumn.width` owns the number and the argument. Retired this strip-tag:
            // the unified spelling supersedes the old 335.
            .inspectorColumnWidth(
                min: InspectorColumn.width,
                ideal: InspectorColumn.width,
                max: InspectorColumn.width
            )
        }
        // The one write of the glyph's ambient state - applied once so the four modes cannot disagree.
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
            LibrarySearchTokenLabel(token: token)
        }
        .sheet(isPresented: Binding(present: $importProgress)) {
            if let importProgress {
                ImportStatusView(
                    progress: importProgress,
                    onDismiss: { self.importProgress = nil },
                    // The flag, not a Task cancel: the loop reads it between files (M16).
                    onCancel: { self.importProgress?.isCancelled = true }
                )
                // ⎋ bypasses the footer buttons; dismissing mid-run would let the rest of the batch import invisibly.
                .interactiveDismissDisabled(!importProgress.isFinished)
            }
        }
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
                // `onOpen` is the menu's new-tab door; `onOpenInPlace` is double-click's.
                onOpen:    openGames,
                onOpenInPlace: openInPlace,
                // The list's batch doors, not the singular ones (17 Aug 2026): the grid
                // resolves Finder's rule itself, so a selected card's menu hands the whole
                // selection here - the singular doors made "select all, analyze" analyze one.
                onAnalyze: { requestAnalysis(ids: Set($0.map(\.id))) },
                onExport:  { requestExport(ids: Set($0.map(\.id))) },
                onDelete:  { requestDelete(ids: Set($0.map(\.id))) }
            )
            .accessibilityIdentifier(AccessibilityID.libraryModeIcons)
        case .list:
            LibraryListView(
                games: games,
                analyzedIDs: analyzedIDs,
                selectedPGNs: $selectedPGNs,
                onOpen:       openGames,
                onOpenInPlace: openInPlace,
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
                onOpenInPlace: openInPlace,
                // The list's doors (23 Aug 2026). The singular trio this mode took fanned the
                // menu's counted verbs into per-game calls - `pendingDeletion` assigned N times
                // kept one, so "Delete 5 Games" deleted the last of the five after confirming.
                onAnalyzeIDs: { requestAnalysis(ids: $0) },
                onExportIDs:  { requestExport(ids: $0) },
                onDeleteIDs:  { requestDelete(ids: $0) },
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
                onOpenInPlace: openInPlace,
                // The icons grid's set doors (23 Aug 2026) - the gallery card's menu now hands
                // the whole ⌘A selection here, where it handed one game before.
                onAnalyze: { requestAnalysis(ids: Set($0.map(\.id))) },
                onExport:  { requestExport(ids: Set($0.map(\.id))) },
                onDelete:  { requestDelete(ids: Set($0.map(\.id))) }
            )
            .accessibilityIdentifier(AccessibilityID.libraryModeGallery)
        }
    }
    
    /// Double-click's door since 17 Aug 2026, by request: load the game into **this** tab
    /// rather than spawning one. `ContentView` owns the two values it takes - the window's
    /// `loadedGameID` and the sidebar selection - so the destination only asks. Nil when the
    /// host has no in-place route (previews), which is why every gesture guards it and falls
    /// back to the new-tab path rather than doing nothing.
    private func openInPlace(_ pgn: PGN) {
        guard let onOpenInPlace else {
            performOpen([pgn])
            return
        }
        Self.logger?.info("Open in place: '\(pgn.name, privacy: .public)'")
        onOpenInPlace(pgn)
    }

    /// One resolution point for "open these in windows". macOS dedups and tabs, which makes the plural
    /// safe; arrives and stays in display order - visible here as tab order. Reached from the
    /// context menu's "Open in New Tab" only - double-click goes to `openInPlace`.
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
    
    /// Applies the mode's own opinion to this destination's flag, in one place so `onAppear` and
    /// `onChange` cannot disagree. The opinion itself is `CollectionViewMode`'s since 18 Aug 2026 -
    /// it was spelled here and again in `PlayersDestination`, identical but for the flag written.
    private func applyInspectorPolicy(for mode: CollectionViewMode) {
        guard let presented = mode.inspectorPresentationOnEntry else { return }
        tabState.libraryInspectorPresented = presented
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
            LibraryFilterMenu(searchTokens: $searchTokens)
        }
    }
    
    /// File doors: in, out, and - only while some game lacks an ordinal - reconcile. No spacer: adjacent
    /// items share a capsule. The third item vanishes at zero rather than sitting disabled.
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
                .help("Fill in missing Library numbers by matching a folder of PGN files")
                .accessibilityIdentifier(AccessibilityID.libraryBackfillButton)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var viewModeToolbarItem: some ToolbarContent {
        ToolbarItem {
            // NOTE: a `.segmented` Picker from `Label(_:systemImage:)` renders icon-only; AX keys segments by
            // SF Symbol name, not per-segment identifier - only the picker container is tagged.
            Picker("View Mode", selection: viewModeBinding) {
                ForEach(CollectionViewMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(AccessibilityID.libraryViewModePicker)
        }
    }
    
    /// Only the queue status item remains - Analyze, Delete and Export moved to the row menus by request.
    @ToolbarContentBuilder
    private var queueToolbarItem: some ToolbarContent {
        // Visible while a batch runs or failures are unacknowledged - see `LibraryQueueStatusLabel`.
        if analysisQueue.queue.isActive || analysisQueue.queue.hasFailures {
            ToolbarItem {
                Button {
                    // Window, not popover; `openWindow(id:)` - one queue, singleton scene, nothing to route (no request wrapper).
                    openWindow(id: AnalysisQueueWindow.sceneID)
                } label: {
                    LibraryQueueStatusLabel(queue: analysisQueue.queue)
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
            // Always enabled (17 Aug 2026, by request - the `.disabled(ownsDetailPane)` guard
            // retired with the Players twin's): entering columns closes the inspector once,
            // and this button is how a reader disagrees.
            .help("Show or hide the inspector")
            .accessibilityIdentifier(AccessibilityID.libraryInspectorToggle)
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

    /// The backfill: point at the folder; the content hash decides which row each file is.
    /// Stamps one `Int?` per match - never resolves players, classifies or rehashes.
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
            // Between files, and only here (M16): the sheet's Cancel sets the flag, the yield
            // below is the window a tap can land in, and the current file always completes -
            // stopped batches report what landed, never a half-imported file.
            if importProgress?.isCancelled == true { break }

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
        if importProgress?.isCancelled == true {
            let reached = importProgress?.completed ?? 0
            Self.logger?.info("Import batch stopped by cancel: \(imported) imported, \(urls.count - reached) not reached")
        } else {
            Self.logger?.info("Import batch complete: \(imported)/\(urls.count) imported")
        }
    }
    
    /// Delete for an id set: one game reuses the single-game flow (dirty confirmation); more go to batch confirmation.
    private func requestDelete(ids: Set<PGN.ID>) {
        let games = gamesInDisplayOrder(ids)
        guard !games.isEmpty else { return }
        if games.count == 1 {
            // Through the alert - a single game must confirm like a batch does; the dirty-changes fork is unchanged.
            pendingDeletion = games[0]
        } else {
            pendingBatchDeletion = games
        }
    }
    
    /// One transaction; closes open tabs first. Unsaved changes discarded without prompt - acceptable while
    /// the dirty path is dormant (no editor defers writes yet).
    private func performBatchDelete(_ pgns: [PGN]) {
        for pgn in pgns {
            let id = pgn.persistentModelID
            // Before the store delete - see `performDelete` for the why.
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
    /// The dirty arm is unreachable today by design - no editor defers writes (see `OpenGamesRegistry.markDirty`).
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
        // Before the store delete: `gameWasDeleted` stops the running pass synchronously - the engine never
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
    
    /// The eager half: heals pre-M4 rows on appearance so an opening name never costs a depth-18 re-run.
    private func backfillClassifications() async {
        let table = await ECOTable.warmed()
        do {
            try PGNStore(modelContext: modelContext).backfillClassifications(using: table)
        } catch {
            Self.logger?.error("Classification backfill failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: Export
    
    /// Single-game entry: a save panel - the user names the file.
    private func requestExport(_ pgn: PGN) {
        Self.logger?.info("Export requested: '\(pgn.name, privacy: .public)'")
        PGNExporter.export([pgn])
    }
    
    /// Multi-game entry; resolves against `filteredGames` - the order numbers the filenames.
    private func requestExport(ids: Set<PGN.ID>) {
        let ordered = gamesInDisplayOrder(ids)
        guard !ordered.isEmpty else { return }
        Self.logger?.info("Export requested: \(ordered.count) game(s)")
        PGNExporter.export(ordered)
    }
}

// MARK: Previews
#Preview("With Games") {
    let container = try! ModelContainer(
        for: PGN.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    for sample in LibraryPreviewFixtures.games(3) { container.mainContext.insert(sample) }
    
    return NavigationSplitView {
        List { Label("Library", systemImage: "books.vertical") }
            .navigationSplitViewColumnWidth(min: 80, ideal: 100, max: 120)
    } detail: {
        LibraryDestination(tabState: TabState())
    }
    .modelContainer(container)
    .environment(OpenGamesRegistry())
    .environment(InspectorSectionCollapse.preview)
    // Both read since 16 Aug; uninjected, the canvas traps - the ContentView preview's find.
    .environment(PreviewFixtures.viewOptions())
    .environment(AnalysisQueueController())
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
    // Both read since 16 Aug; uninjected, the canvas traps - the ContentView preview's find.
    .environment(PreviewFixtures.viewOptions())
    .environment(AnalysisQueueController())
}
