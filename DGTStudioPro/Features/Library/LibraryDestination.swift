// `AppKit` explicitly, though `NSOpenPanel` below has compiled without it:
// `selectAll(_:)` is a member of an AppKit *protocol*, and
// `MemberImportVisibility` is precisely the upcoming feature that stops
// members arriving through a module nobody imported.
import AppKit
import os
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

internal struct LibraryDestination: View {
    
    // MARK: Static Constants
    private static let logger = AppLog.logger(.library)

    /// Above this many, Open asks first (D56′).
    ///
    /// **A judgement call, stated as one** rather than given an invented
    /// rationale. Calibrated against two populations with a wide gap between
    /// them: the sets you mean to open are a rivalry, a round, a morning, all
    /// single digits; the sets that arrive by accident come from ⌘A and are the
    /// whole Library. That one exists matters more than its exact value.
    ///
    /// Open is the only bulk action here that confirms on *count* rather than
    /// consequence. Delete confirms because it destroys; Analyze has a Stop All;
    /// Export writes into one folder you chose. Open has none of those —
    /// windows are not a queue, and closing four hundred tabs has no undo.
    private static let openConfirmationThreshold = 10
    
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

    /// D56′'s speed bump, held between offer and confirmation — the
    /// `pendingBatchDeletion` shape, deliberately, because it is the same
    /// question ("you asked for this to happen to N things, did you mean N?").
    @State private var pendingBatchOpen: [PGN]?
    @State private var selectedPGNs: Set<PGN.ID> = []
    @State private var importProgress: ImportProgress?

    /// D58′'s backfill result, held for its report alert (M12.5). Two pieces of
    /// state rather than one enum because they are not alternatives in the way
    /// that shape implies: a report is the normal outcome including "nothing
    /// matched", while a failure means the folder itself could not be read.
    @State private var backfillReport: PGNStore.LibraryIndexBackfill?
    @State private var backfillFailure: String?

    // `editingMovetext` was here until D59′ — the `.sheet(item:)` subject
    // driving D18′'s editor. Gone with the sheet: the editor is a Get Info tab
    // now, so this destination holds no presentation state for it. Nothing in
    // the app presents a modal over a model any more; the pattern is not
    // deprecated, there is just no live example left to copy.
    @State private var isQueuePopoverPresented = false
    
    // MARK: Search & Filters (2 Aug 2026 — native `.searchable`, restored
    // the same day after a custom toolbar field was tried and reverted: the
    // system field claims the toolbar's trailing edge and that isn't
    // negotiable, but native search behavior won over field placement.)
    @State private var searchText = ""
    /// The non-text facets, as chips inside the search field (3 Aug 2026).
    ///
    /// Replaced a `GameResult?` / `Bool?` pair driven by the toolbar menu, which
    /// was wrong twice over: single-valued, so "decisive games" was
    /// inexpressible; and announced only by a filled glyph, which says *that*
    /// something narrows the list and never *what*. A chip says both and carries
    /// its own remove button.
    ///
    /// The menu stays the discoverable entry point — `suggestedTokens` surface
    /// only while the field is focused — and its glyph tracks `!tokens.isEmpty`.
    @State private var searchTokens: [LibrarySearchToken] = []

    /// The list mode's column sort (5 Aug 2026).
    ///
    /// **Defaults to `#` descending** — the ordinal the folder on disk has kept
    /// since before the app existed (D58′), rather than `importedAt`, which is
    /// only when *this app* first saw a file. Re-importing an old game moves it
    /// to the top under the old default and leaves it in place under this one.
    ///
    /// **One comparator, not two**: `#` twice reproduces the launch order
    /// exactly, where a hidden tiebreaker would make it a state no click can
    /// return to. The cost is that ties are unordered by contract —
    /// `libraryIndex` is documented not unique, and `sorted(using:)` is not
    /// guaranteed stable. Deterministic in practice, and relied on for
    /// *display* only; D10′'s total-tiebreak rule governs the pure folds.
    ///
    /// Un-indexed games sort to the **bottom** — `Optional`'s ordering under a
    /// reversed comparator, and the right answer besides.
    ///
    /// **Owned here rather than in `LibraryListView`**, which is the point of
    /// the change: `filteredGames` applies it as the last narrowing stage, so
    /// D24′'s export numbering, the analysis queue's running order and D56′'s
    /// tab order all see what the reader sees. Left inside the table, the sort
    /// would reorder pixels while those three read the *unsorted* array —
    /// nothing fails, the filenames just stop matching the screen.
    ///
    /// `@State`, not `TabState`, and deliberately not persisted: every launch
    /// opens on `#` descending.
    @State private var sortOrder: [KeyPathComparator<PGN>] = Self.defaultSortOrder

    /// The launch order, stated **once**.
    ///
    /// The `@State` initializer above and the previews across this file's mode
    /// views would otherwise each repeat it — D25′'s twin-read-site shape. A
    /// preview drifting from the shipped default is its harmless-looking
    /// version: the canvas stops showing what the app opens on, and nothing
    /// fails.
    ///
    /// **Computed rather than stored** (`noGamePlaceholder`'s spelling), and
    /// `nonisolated` because `View` conformance would otherwise infer
    /// `@MainActor` onto it and lock out previews for no reason.
    /// `KeyPathComparator` is `Sendable` by `SortComparator`'s refinement, so
    /// nothing here needs an opt-out.
    internal nonisolated static var defaultSortOrder: [KeyPathComparator<PGN>] {
        [KeyPathComparator(\PGN.libraryIndex, order: .reverse)]
    }
    
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
    
    /// Sidebar filter → search → menu filters → sort, narrowing only, so the
    /// stages compose without caring about each other. Every downstream
    /// consumer (`selectedPGN`, `gamesInDisplayOrder`, and therefore batch
    /// analyze/export/delete) reads the same narrowed list: a hidden game is
    /// out of every bulk action, never silently included.
    ///
    /// **Render reads it once; actions re-derive it fresh.** `coreContent`
    /// folds this a single time per pass and threads the result onward
    /// (`PlayersDestination`'s arrangement, adopted after the walk was found
    /// running three to four times a render). `gamesInDisplayOrder` calls it
    /// directly on purpose — an action fires long after the fold that painted
    /// the screen, and a stale narrowed list is what bulk actions must not act
    /// on.
    private var filteredGames: [PGN] {
        var result = games
        if let filter {
            result = result.filter { filter.matches($0) }
        }
        // The emptiness guard only skips the walk — an empty query matches
        // everything by the matcher's own contract.
        if !searchText.isEmpty {
            // Folded once, matched per game — `SearchMatch.Query`'s reason
            // (4 Aug 2026): the one-shot form re-folded the query for every
            // row of the walk.
            let query = SearchMatch.Query(searchText)
            result = result.filter {
                query.matches(fields: searchFields(of: $0))
            }
        }
        if !searchTokens.isEmpty {
            // `AnalysisGlyph.isAnalyzed`, not a bare `isEmpty` check: the
            // filter and the gear glyphs must answer "analyzed?" the same
            // way, and that type is the one spelling. The token rule itself
            // (OR within a facet, AND across facets) lives on the token, so
            // this stays a projection and never a second opinion.
            result = result.filter {
                LibrarySearchToken.admit(
                    searchTokens,
                    result: $0.result,
                    isAnalyzed: AnalysisGlyph.isAnalyzed($0)
                )
            }
        }
        // Sorting is the LAST stage, and the one that makes "display order" mean
        // what the reader sees. The stages above *remove* rows and compose in
        // any order; this only permutes, and must come last regardless — sorting
        // a set you are about to filter is work thrown away.
        //
        // Unconditional rather than `sortOrder.isEmpty ? result : …`: `#`
        // descending is the default now and nothing in `Table`'s header
        // behaviour empties the array, so that branch's condition cannot be
        // produced — the `.disabled(…)` shape D40′ names.
        //
        // Cost, accepted: the Library sorts every render. Invisible for `#`, an
        // `Int?` compare; not for **ECO**, whose comparator goes through
        // `opening` and rehydrates per comparison. Known-costs census, not
        // optimized ahead of M7.
        return result.sorted(using: sortOrder)
    }
    
    /// The model side of the `LibraryFilter` split: the pure matcher takes
    /// strings, this maps a game into its searchable ones. Every field, always —
    /// the scope picker that once narrowed this set was retired because a query
    /// already names its field ("1-0" is a result, "C60" an opening, a surname a
    /// player), which is also why the result's raw value is included.
    private func searchFields(of game: PGN) -> [String] {
        [game.name, game.whiteDisplayName, game.blackDisplayName,
         game.event, game.site, game.result.rawValue,
         game.opening?.code, game.opening?.fullName].compactMap { $0 }
    }
    
    /// Whether the empty gate should read as "no matches" rather than
    /// "no games".
    private var isNarrowedBySearchOrFilters: Bool {
        !searchText.isEmpty || !searchTokens.isEmpty
    }
    
    private var hasActiveMenuFilters: Bool {
        !searchTokens.isEmpty
    }
    
    /// The single selected game, nil for empty *and* multiple — the columns
    /// detail's rule (2 Aug 2026): the inspector details one thing, and
    /// with a rubber-band or ⌘-click selection "the first of the set" is an
    /// arbitrary game wearing a specific game's face. The inspector gets
    /// the count instead and names it.
    private func selectedPGN(in games: [PGN]) -> PGN? {
        guard selectedPGNs.count == 1, let id = selectedPGNs.first else { return nil }
        return games.first(where: { $0.id == id })
    }
    
    /// Resolves a selection to models in **display order**. A `Set` carries
    /// none, and the order is load-bearing twice: the queue crunches
    /// top-to-bottom as shown, and D24′'s export *numbers the filenames* from
    /// it. Three callers had this line copied.
    private func gamesInDisplayOrder(_ ids: Set<PGN.ID>) -> [PGN] {
        filteredGames.filter { ids.contains($0.id) }
    }

    /// ⌘A over all four view modes, as the system's own Edit ▸ Select All
    /// rather than a shortcut of this destination's invention.
    ///
    /// `.onCommand` puts the action in the responder chain, which both enables
    /// the menu item and gives it its shortcut. Three things fall out of that
    /// rather than being designed: ⌘A inside the search field still selects
    /// *text*, because the field answers first; list and columns are `Table`s,
    /// so `NSTableView` answers and this never fires — producing the identical
    /// set, since the table was built from the same narrowed array; and icons
    /// and gallery have no such responder, so for them this is the whole
    /// feature.
    ///
    /// **Selects what the render painted, not what `filteredGames` would answer
    /// at action time** — the opposite of `gamesInDisplayOrder` above, for the
    /// opposite reason. That re-derives because a destructive action against a
    /// stale list is the failure to prevent; this one *is* the visible state, so
    /// "select all" must mean the rows on screen. The narrowing is unchanged
    /// either way: a hidden game stays out of every bulk action.
    ///
    /// Nil on an empty list rather than a closure assigning an empty set, so the
    /// system disables Edit ▸ Select All — both arms producible, the D40′ check
    /// run at minting.
    ///
    /// Not reached, named so it isn't read as an oversight: the icons grid's
    /// `anchorID` is `@State` a destination cannot touch, so after ⌘A the next
    /// arrow steps from the last card *clicked*.
    private func selectAll(_ games: [PGN]) {
        selectedPGNs = Set(games.map(\.id))
    }

    // `applyEditedMovetext` lived here for one day (D54′, 4 Aug) and moved to
    // `GetInfoWindow.applyMovetext` on 5 Aug with the editor it served. It had
    // moved here from `BoardDestination` the day before that, which makes this
    // the *second* relocation of one door in two days — worth a line, because
    // the door never changed and its three homes each looked right at the time:
    // the Board had the cached `Game`, the Library had the bytes, Get Info has
    // the window that edits everything else about a game. Only the last one is
    // an argument about where a *reader* would look for it.


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
                    Text(Self.deletionMessage(
                        for: [game],
                        lead: "\(game.name) will be permanently deleted."
                    ))
                }
            )
            // M12.5. Always reports, including "nothing matched" — a scan that
            // finishes silently is indistinguishable from a scan that did not
            // run, and this one is invoked rarely enough that the reader has no
            // other way to tell. The `deleteOrphanedPlayers` argument: the
            // dialog is doing the showing as well as the telling.
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
            // `.onDeleteCommand` stood here until 5 Aug 2026: **plain ⌫ no
            // longer deletes.** Asymmetry of cost — ⌫ sits one keystroke from
            // where your hands already are with a row focused, and its failure
            // mode is a multi-selection you forgot you had. ⌘⌫ is Finder's key
            // for the verb and no slipped finger reaches it.
            //
            // The shortcut moved to the toolbar's Delete button, not here: a
            // `keyboardShortcut` on an always-present, already-`disabled`-guarded
            // control is live whenever this destination shows, where the context
            // menu's copy of ⌘⌫ is only known to *render*. Removing this line
            // without a home that certain would have retired the gesture rather
            // than narrowed it.
            .onAppear {
                backfillEmptyNames()
                backfillPlayerLinks()
                applyInspectorPolicy(for: viewMode)
            }
        // `.task`, not a fourth line in `onAppear`: this one has to await
        // the ECO table, and awaiting it is the entire point — see
        // `backfillClassifications()`.
            .task {
                await backfillClassifications()
            }
            .onChange(of: viewMode) { _, mode in
                applyInspectorPolicy(for: mode)
            }
    }
    
    /// The library content plus its inspector, toolbar, drop target, and
    /// import sheet — split out from the deletion alerts so neither modifier
    /// chain trips SwiftUI's per-expression type-check budget. (Adding the
    /// third alert pushed the single combined chain over that limit, which the
    /// compiler reports as an "unable to type-check in reasonable time" error
    /// pinned to an arbitrary modifier.)
    private var coreContent: some View {
        // One walk per render — see `filteredGames`'s doc. Every render-time
        // consumer below reads this local; none re-runs the filter.
        let games = filteredGames
        // Typed explicitly rather than left to a ternary's inference, and
        // hoisted out of the modifier so the nil arm reads as the decision it
        // is: no games means no Edit ▸ Select All, disabled by the system.
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
                    // Two vocabularies for one gate: an empty *library*
                    // invites importing; an empty *result set* names the
                    // narrowing that caused it. The identifier stays on the
                    // true empty state — placed for the seeded UI runs,
                    // kept per the registry's bet (D51′).
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
                    modeView(games: games)
                }
            }
            .accessibilityIdentifier(AccessibilityID.libraryContent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // On the content group rather than in `body`: the local `games` is
            // the painted list this gesture is defined against (see
            // `selectAll(_:)`), and `body`'s chain cannot see it. It also keeps
            // the modifier off the chain whose type-check budget the third
            // alert already blew. (This said "rather than beside
            // `.onDeleteCommand`" until that modifier was removed on 5 Aug
            // 2026 — the placement argument never depended on it.)
            .onCommand(
                #selector(NSStandardKeyBindingResponding.selectAll(_:)),
                perform: selectAllAction
            )
            // D56′'s threshold, and it lands here rather than beside the three
            // deletion alerts in `body` for the reason those three are already
            // split out: that chain is the one whose type-check budget the
            // third alert blew, and a fourth is exactly the straw the comment
            // there warns about. This group carries four short modifiers.
            //
            // Not `role: .destructive` — opening destroys nothing. The dialog
            // is about *volume*, which is why the message counts tabs rather
            // than warning about consequences it does not have.
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
        // Counted over `filteredGames`, not the whole Library: the subtitle
        // describes what you are looking at, so a smart tag that hides the
        // backlog should quiet the line rather than keep reporting it. The
        // backlog clause disappears at zero by construction — a fully
        // analysed view shows a bare title, which is the point.
        .navigationSubtitle(
            DestinationSubtitle.library(
                selected: selectedPGNs.count,
                unanalyzed: games.count(where: { !AnalysisGlyph.isAnalyzed($0) })
            ) ?? ""
        )
        .dropDestination(for: URL.self) { urls, _ in
            Self.logger?.info("Drop received: \(urls.count) URL(s)")
            importURLs(urls)
            return true
        }
        .inspector(isPresented: $tabState.libraryInspectorPresented) {
            // `onEditMoves:` was a fourth argument here until 5 Aug 2026,
            // passed only when a single game was selected so the pencil would
            // not render over an empty or multi selection. Both the argument
            // and the pencil went with the movetext door, which is Get Info's
            // Move Text tab now. (Written above the call rather than inside the
            // argument list, where it read as a commented-out parameter and
            // matched every grep for the symbol it was announcing the death of.)
            LibraryInspectorView(
                pgn: selectedPGN(in: games),
                selectionCount: selectedPGNs.count,
                queue: tabState.analysisQueue
            )
            .inspectorColumnWidth(min: 335, ideal: 335, max: 400)
        }
        .toolbar { toolbarContent }
        // Tokens ahead of the text, inside the field. `suggestedTokens` is
        // every facet minus the ones already applied — offering a chip you
        // are already wearing is how a suggestion list stops being read.
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
        // D18′'s editor was presented here — the destination owning the modal
        // (D15′) while the inspector only requested it. Gone 5 Aug 2026 with
        // the pencil: the editor is a *tab* in Get Info now, so there is no
        // modal for a destination to own and no request for an inspector to
        // make. The store write went with it, to the window that hosts the
        // editor, which keeps "the surface that edits owns the door" true
        // through the move.
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
    private func modeView(games: [PGN]) -> some View {
        switch viewMode {
        case .icons:
            LibraryIconsView(
                games: games,
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
                selectedPGNs: $selectedPGNs,
                onOpen:       openGames,
                onAnalyzeIDs: { requestAnalysis(ids: $0) },
                onExportIDs:  { requestExport(ids: $0) },
                onDeleteIDs:  { requestDelete(ids: $0) },
                sortOrder:    $sortOrder
            )
            .accessibilityIdentifier(AccessibilityID.libraryModeList)
        case .columns:
            LibraryColumnsView(
                games: games,
                selectedPGNs: $selectedPGNs,
                boardStyle: boardStyle,
                onOpen:    openGames,
                onAnalyze: requestAnalysis,
                onExport:  requestExport,
                onDelete:  { pendingDeletion = $0 },
                sortOrder: $sortOrder
            )
            .accessibilityIdentifier(AccessibilityID.libraryModeColumns)
        case .gallery:
            LibraryGalleryView(
                games: games,
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
    
    /// Single resolution point for "open these games in their own windows"
    /// (D56′ — it took one `PGN` until then). Threaded into every Library view
    /// as the `onOpen` callback so the views stay window-system-unaware. macOS
    /// handles dedup, tabbing (with "Prefer Tabs: Always"), and restoration —
    /// which is what makes the plural safe to offer at all: re-opening a game
    /// that already has a tab *focuses* it rather than making a second, so a
    /// set containing already-open games opens fewer windows than its count.
    ///
    /// Arrives in display order and stays in it, because here that order is
    /// visible as **tab order** — the same reason `gamesInDisplayOrder` exists
    /// for export's filenames. Every host resolves through its own `games`
    /// array before calling, so no re-derivation is needed or wanted.
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
    
    /// Single-game entry (card context menus, the gallery, the one-row
    /// list case). Analysis is a batch of one since M-batch — see
    /// `AnalysisQueueController`, decision 1 — so this enqueues, then
    /// keeps the pre-queue affordance: select the game and surface the
    /// inspector, which shows this game's progress, its skip control,
    /// and the graph filling in. The one-shot `pendingAnalysisID` relay
    /// this used to set is gone with the per-inspector driver it fed.
    private func requestAnalysis(_ pgn: PGN) {
        Self.logger?.info("Analyze requested: '\(pgn.name, privacy: .public)'")
        selectedPGNs = [pgn.id]
        // Not in columns mode: its detail pane already shows the game being
        // analyzed, and forcing the inspector open here would reintroduce the
        // overflow the mode's own policy exists to prevent — from a code path
        // nobody would think to check.
        if !viewMode.ownsDetailPane {
            tabState.libraryInspectorPresented = true
        }
        tabState.analysisQueue.enqueue([pgn], modelContext: modelContext)
    }
    
    /// The two modes with an opinion about the inspector, in one place so
    /// `onAppear` and `onChange` cannot answer differently.
    ///
    /// Gallery forces it **open** — the gallery is a picker and the inspector
    /// is where the picked game is read. Columns forces it **shut**, because
    /// columns renders its own detail pane (`CollectionViewMode.ownsDetailPane`,
    /// which carries the full reason). The other two modes are left alone:
    /// list and icons have no detail surface of their own, so whatever the
    /// user last chose is still what they want.
    ///
    /// Leaving columns does not restore it. Remembering would need a
    /// "was open before columns" flag, which is state that exists only to
    /// undo a state change — and the toggle is one click away.
    private func applyInspectorPolicy(for mode: CollectionViewMode) {
        if mode.ownsDetailPane {
            tabState.libraryInspectorPresented = false
        } else if mode == .gallery {
            tabState.libraryInspectorPresented = true
        }
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
        Self.logger?.info("Batch analyze requested: \(ordered.count) game(s)")
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
    /// the `searchTokens` declaration for why this stays a menu even now
    /// that the chips are in the field. Content side of the break, the
    /// Maintenance-menu argument:
    /// it acts on what the list shows.
    @ToolbarContentBuilder
    private var filterToolbarItem: some ToolbarContent {
        ToolbarItem {
            Menu {
                // Toggles rather than pickers, because the underlying state
                // stopped being single-valued: a `Picker` over an optional
                // can't express "1-0 and 0-1 both selected", which is the
                // whole reason the filters became tokens. Checkmarks are the
                // menu's own multi-select idiom, and they stay in sync with
                // the chips because both read `searchTokens`.
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

    /// One token, rendered — used by both the chip inside the search field
    /// and the row in the Filter menu, so the two cannot drift.
    ///
    /// The analysis pair carries the same tinted badge it wears everywhere
    /// else in the Library, through `AnalysisGlyph`'s one colour source: a
    /// green checkmark next to "Analyzed" in the menu, a red one on the chip,
    /// and the identical treatment on the toolbar button that acts on them.
    /// Result tokens take no tint — a checkered flag has no state to signal,
    /// and colouring it would imply one.
    @ViewBuilder
    private func tokenLabel(_ token: LibrarySearchToken) -> some View {
        switch token {
        case .analyzed:   AnalysisLabel(analyzed: true, title: token.displayName)
        case .unanalyzed: AnalysisLabel(analyzed: false, title: token.displayName)
        case .result:     Label(token.displayName, systemImage: token.symbol)
        }
    }

    /// One token's membership, as a `Binding<Bool>` for the menu's toggles.
    ///
    /// Appends rather than inserting at a fixed index, so the chips sit in
    /// the order they were added — which is the order the user chose them in,
    /// and the only order they can predict. Sorting them by facet would make
    /// a chip appear somewhere other than where the click happened.
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
    
    // `filterLabel(for:)` lived here until 3 Aug 2026. Its copy moved to
    // `LibrarySearchToken.displayName` when the filters became chips — the
    // same strings, now owned by the thing that renders them in two places
    // (the chip and the menu row) instead of by the one menu that used to.
    // The convention it carried survives with it: pair the word with PGN's
    // own vocabulary, because the raw value is the app's one rendering of a
    // result and a label that hides it makes the reader translate.
    
    /// The Library's file doors: in, out, and — only when it has work —
    /// reconcile.
    ///
    /// **This doc claimed something the code does not do, corrected 6 Aug 2026
    /// (M12.5).** It read "one toolbar cell… A single `ToolbarItem` (not two
    /// split by a `ToolbarSpacer`)… the explicit `Divider` marks the direction
    /// change inside it." There are **two** `ToolbarItem`s here and there is no
    /// `Divider` anywhere in this group. What survives is the part that was
    /// load-bearing and is still true: no `ToolbarSpacer` separates them, which
    /// is what makes adjacent items share a capsule, and identifiers, helps and
    /// disabled state stay on the individual buttons so per-button affordances
    /// are unaffected by the grouping. Code is truth; the arrangement changed
    /// under a doc that kept describing the old one.
    ///
    /// The third item is **present only while some game lacks an ordinal**,
    /// which is the `queueStatusLabel` shape three groups down rather than a
    /// new idea. A backfill retires itself: run it once against the folder and
    /// every row is numbered, at which point the affordance has nothing to do
    /// and D40′ says it should not be on screen greyed out. Conditional
    /// presence also keeps a rare one-off out of a toolbar the forward notes
    /// already call crowded.
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
        // The scan reads `games` rather than asking the store, deliberately:
        // this is a `@Query`, so the item appears and disappears reactively as
        // rows are imported and stamped, where a `hasUnnumberedGames()` fetch
        // per body pass would cost more and still need invalidating by hand.
        // O(n) over an `Int?` per render, which joins the known-costs census
        // well below the `GameRecord`-per-row folds already on it.
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
            // NOTE: On macOS a `.segmented` Picker built from
            // `Label(_:systemImage:)` renders icon-only, and AX exposes
            // each segment as a radioButton keyed by its SF Symbol name
            // (e.g. "square.grid.2x2"), NOT by any per-segment
            // accessibilityIdentifier — the identifier below only tags
            // the picker container. (The suite that addressed segments
            // that way is gone — D51′; the platform behavior isn't.)
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
                // Computed once and threaded into both the symbol and the
                // tint: two independent evaluations of the same fold is how
                // a green badge ends up on an xmark.
                let allAnalyzed = {
                    let games = gamesInDisplayOrder(selectedPGNs)
                    return !games.isEmpty && games.allSatisfy(AnalysisGlyph.isAnalyzed)
                }()
                AnalysisLabel(analyzed: allAnalyzed)
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
            // The app's one live spelling of delete-by-keyboard since plain ⌫
            // was retired (5 Aug 2026 — see the note where `.onDeleteCommand`
            // used to sit). Finder's Move to Trash key, on a control that is
            // always present and already guarded, so the shortcut inherits the
            // guard: an empty selection disables the button, and a disabled
            // button's key equivalent does nothing rather than raising an
            // alert about zero games.
            .keyboardShortcut(.delete, modifiers: .command)
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
            // Disabled, not hidden. A control that vanishes on a mode switch
            // reads as a glitch; a dimmed one reads as "not here" — and the
            // `.help` below says why rather than leaving it to be guessed.
            // Its guard is producible: `ownsDetailPane` is true for exactly
            // one of four modes the user picks from, which is the check D40′
            // taught this project to run before shipping a `.disabled(…)`.
            .disabled(viewMode.ownsDetailPane)
            .help(viewMode.ownsDetailPane
                  ? "Columns view shows details in its own pane"
                  : "Show or hide the inspector")
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

    /// D58′'s backfill (M12.5): point at the folder the PGNs live in and let
    /// the content hash decide which row each file is.
    ///
    /// Directory mode, `PGNExporter.exportBatch`'s panel shape — the same
    /// gesture pointed the other way, and a fresh panel selection carries its
    /// own sandbox grant for the session, so no bookmark is involved.
    ///
    /// Synchronous, unlike `importURLs`: this reads and parses files but writes
    /// one `Int?` per match and never resolves players, classifies or rehashes,
    /// so it is a fraction of an import's work per file and has no progress to
    /// report. If a folder ever gets large enough for that to be wrong, the
    /// import pipeline's `ImportProgress` is the shape to copy.
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
    
    /// Imports a batch, recording a per-file result and never aborting on
    /// a failure — a bad file in the middle no longer drops the files
    /// after it. Runs on the main actor (PGNStore touches the
    /// `ModelContext`), yielding between files so the progress bar in the
    /// status sheet animates as work proceeds.
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
    
    /// The confirmation's body: the lead sentence, plus a clause naming any
    /// players the deletion would take with it.
    ///
    /// **Appended only when there are any**, so the ordinary delete reads as it
    /// did before the cascade. A line saying "and no players will be removed"
    /// on every deletion is the `.DS_Store` shape — text that is always there
    /// stops being read, and the one time it matters scrolls past with the rest.
    ///
    /// Named rather than counted (D40′'s reason, weakened but still standing:
    /// the effect lands in a destination the user isn't looking at, and a seat
    /// menu quietly losing a name reads as a bug six months later). Capped at
    /// five, matching the sweep, because it is the same list.
    ///
    /// Advisory, not authoritative — `PGNStore.delete(_:)` recomputes at write
    /// time. A snapshot held across a confirmation is stale by construction, so
    /// the message asks and the door decides.
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

    /// The backfill report in the reader's terms (M12.5).
    ///
    /// **Leads with what did not happen when nothing did**, because the two
    /// outcomes a reader will actually hit are "it filled everything in" and
    /// "it found none of my games", and the second is the one that needs
    /// explaining rather than a bare zero. The commonest cause is pointing at
    /// the wrong folder, so the message says so instead of listing filenames
    /// that would all be wrong together.
    ///
    /// `unmatched` is deliberately phrased as a **finding, not a fault**: a
    /// file the Library does not hold is a game you have not imported, which is
    /// worth knowing and is not an error. Capped at three names on the
    /// `sweepMessage` precedent — this is the only place these filenames are
    /// ever shown, and a bare count would ask the reader to trust a number
    /// about files they have never seen.
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

    /// Routes a delete request for the current selection — the toolbar button
    /// and, through its `keyboardShortcut`, ⌘⌫. (Plain ⌫ reached here until
    /// 5 Aug 2026; see the note where `.onDeleteCommand` used to sit.)
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
            Self.logger?.error(
                "Failed to batch-delete \(pgns.count) PGNs: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
    
    /// Entry point from the "Delete Game?" confirmation. Routes to a
    /// second discard confirmation if the game is open with unsaved
    /// changes; otherwise deletes and closes immediately.
    ///
    /// **The first arm is unreachable today, by design rather than by
    /// accident** (recorded 6 Aug 2026, M12.3). Nothing calls
    /// `OpenGamesRegistry.markDirty`: every edit surface in the app —
    /// `applyEdit`, `applyMovetextEdit`, Get Info's per-field commits — writes
    /// through the store when the reader acts, so no tab ever holds
    /// uncommitted state and `isDirty` is permanently `false`.
    ///
    /// Named here because a `disabled`-shaped branch whose condition can never
    /// be true is the D40′ shape, and the defence D40′ prescribes is to say so
    /// at the site rather than to discover it at the next sweep. This one is
    /// kept rather than deleted: the registry is suited, the branch is three
    /// lines, and an editor that defers its write — inline annotations, a live
    /// movetext buffer — turns it on by calling `markDirty` and nothing else.
    /// If that editor never arrives, this arm and the registry go together.
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
    
    /// M-prs.1 sibling of `backfillEmptyNames()`: the logic is store-owned and
    /// idempotent, so both collection destinations call it from their own
    /// `onAppear` (Players does the same). This is only the
    /// Library's call site and its error sink.
    private func backfillPlayerLinks() {
        do {
            let store = PGNStore(modelContext: modelContext)
            try store.backfillPlayerLinks()
            // D29′ — after links, which it reads (see the store doc).
            try store.backfillPlayerTagNames()
        } catch {
            Self.logger?.error("Player-link backfill failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// D34′'s eager half: an opening name costs a dictionary probe, so the
    /// Library heals pre-M4 rows on appearance rather than making the user
    /// re-run a depth-18 analysis to learn one.
    ///
    /// Its own method with its own error sink, deliberately not a third line
    /// inside `backfillPlayerLinks()` — that sink logs "Player-link backfill
    /// failed", which a classification failure would turn into a lie. Unique
    /// to the Library between the two collection destinations: Players
    /// reads neither field (see the store doc).
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
            Self.logger?.error("Classification backfill failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: Export (D24′)
    
    /// Single-game entry (a card's context menu). One game means a save
    /// panel: the user names the file.
    private func requestExport(_ pgn: PGN) {
        Self.logger?.info("Export requested: '\(pgn.name, privacy: .public)'")
        PGNExporter.export([pgn])
    }
    
    /// Multi-game entry (the list's contextual selection). Resolves the set
    /// against `filteredGames` for the same reason `requestAnalysis(ids:)`
    /// does — a `Set` carries no order, and here the order is *visible*: it
    /// numbers the filenames. Leaves selection and inspector untouched.
    private func requestExport(ids: Set<PGN.ID>) {
        let ordered = gamesInDisplayOrder(ids)
        guard !ordered.isEmpty else { return }
        Self.logger?.info("Export requested: \(ordered.count) game(s)")
        PGNExporter.export(ordered)
    }
}

// MARK: Presentation Bindings

extension Binding where Value == Bool {
    /// A presentation flag over optional state: `true` while a value is
    /// present, and a dismissal clears the source.
    ///
    /// `BoardDestination`'s offer bindings look identical and are deliberately
    /// **not** folded in: they ignore dismissal (`set: { _ in }` — D#3 is a
    /// fork, not a suggestion). Same shape, different contract.
    ///
    /// **Waived, sunset by deletion (D43′).** These two captures are the app
    /// target's only strict-concurrency residue — `Binding` is not `Sendable`
    /// while `init(get:set:)` demands `@Sendable` closures. `T: Sendable`
    /// would fix it and lock out the `@Model` callers, which are most of
    /// them; the opt-outs this codebase has none of are spelled around on
    /// purpose, so the sweep's own prohibition grep stays clean. It stays a
    /// *warning* under mode 6, which reads as framework friction rather than
    /// a defect here. The 2027 SDK's item-based `alert` /
    /// `confirmationDialog` retire every call site and this helper with them.
    ///
    /// No caller count here on purpose — it has been wrong four times now
    /// (five, six, seven, and "currently eight", which was **nine** when it was
    /// written and is eleven today). The fourth was found on 6 Aug 2026 by
    /// running the command in the next sentence, which is the entire argument:
    /// a number written beside the instruction not to write numbers still went
    /// stale, and it went stale *silently*, because nothing about a wrong count
    /// fails. The count lives in the command, D42′'s rule:
    /// `grep -rn 'Binding(present:' DGTStudioPro/`.
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
