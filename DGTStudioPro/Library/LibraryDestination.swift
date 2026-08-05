//
//  LibraryDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

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
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "library"
    )

    /// Above this many, Open asks first (D56′).
    ///
    /// **A judgement call, not a derived number, and stated as one** — the
    /// honest alternative to inventing a rationale for 10. What it is calibrated
    /// against: the sets you actually mean to open are a rivalry, a round, a
    /// morning's games, and those are single digits; the sets that arrive by
    /// accident come from ⌘A or a smart tag and are the whole Library. There is
    /// a wide empty gap between those two populations and the threshold sits in
    /// it, which is why the exact value matters less than that one exists.
    ///
    /// Open is the only bulk action in this destination that confirms on
    /// *count* rather than on consequence. Delete confirms because it destroys;
    /// Analyze does not because the queue has a Stop All and a visible progress
    /// item; Export does not because it writes into one folder you chose. Open
    /// has neither property — windows are not a queue, there is no Stop All for
    /// them, and closing four hundred tabs is manual work with no undo.
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

    // `editingMovetext` was here until 5 Aug 2026 — the `.sheet(item:)` subject
    // that drove D18′'s editor, held as an item-sheet over the model rather
    // than a `Bool` because a selection can change underneath a modal.
    // Removed with the sheet: the editor is a *tab* in Get Info now, so there
    // is no presentation state for this destination to hold.
    //
    // Its doc called this "M10's other half" and noted it was the app's last
    // item-sheet-over-a-model, `BoardDestination.activeEditor` having gone with
    // D57′ the day before. That count is now zero, which is worth keeping: the
    // pattern is not deprecated, there is simply nothing left presenting a
    // modal over a model, and a future one has both precedents in the history
    // rather than a live example to copy.
    @State private var isQueuePopoverPresented = false
    
    // MARK: Search & Filters (2 Aug 2026 — native `.searchable`, restored
    // the same day after a custom toolbar field was tried and reverted: the
    // system field claims the toolbar's trailing edge and that isn't
    // negotiable, but native search behavior won over field placement.)
    @State private var searchText = ""
    /// The non-text facets, as chips inside the search field (3 Aug 2026).
    ///
    /// Was a `GameResult?` / `Bool?` pair driven by the toolbar menu alone.
    /// Two things were wrong with that and only one was visible: the filters
    /// were single-valued, so "decisive games" could not be expressed at all;
    /// and an active filter was announced only by a filled toolbar glyph,
    /// which says *that* something is narrowing the list and never *what*.
    /// A chip says both and carries its own remove button.
    ///
    /// The toolbar menu stays as the way to add one — `suggestedTokens` only
    /// surface while the field is focused, so the menu remains the discoverable
    /// entry point, and its filled/unfilled glyph now tracks `!tokens.isEmpty`.
    @State private var searchTokens: [LibrarySearchToken] = []

    /// The list mode's column sort (5 Aug 2026).
    ///
    /// **Defaults to `#` descending — highest ordinal first** (by request,
    /// 5 Aug 2026). The Library opens on the most recently filed games, which
    /// is what `importedAt` descending was reaching for and never quite said:
    /// import time is when *this app* first saw a file, while the ordinal is
    /// the number the folder on disk has been keeping since before the app
    /// existed (D58′). Re-importing an old game moves it to the top under the
    /// old default and leaves it in place under this one, which is the
    /// difference that matters.
    ///
    /// **One comparator, not two, and that is deliberate.** A hidden
    /// tiebreaker would make the launch order a state no click can return to —
    /// as it stands, `#` twice reproduces the default exactly, so the opening
    /// view is a position on the ladder of orderings rather than a private
    /// one. The cost is that ties are unordered by contract: `libraryIndex` is
    /// documented **not unique** at its declaration (two folders, two
    /// numbering runs), and `sorted(using:)` is not guaranteed stable. In
    /// practice it is deterministic — same array, same comparator, same result
    /// — and the array arrives in the `@Query`'s `importedAt` order, so ties
    /// fall out newest-first. Relied on for *display*, never for anything that
    /// must be reproducible; D10′'s total-tiebreak rule governs the pure
    /// folds, and this is not one.
    ///
    /// Un-indexed games (anything imported before D58′) sort to the **bottom**,
    /// which is `Optional`'s ordering under a reversed comparator and is also
    /// the right answer: a column of numbers should not open on the rows that
    /// have none.
    ///
    /// **Owned here rather than in `LibraryListView`, which is the whole point
    /// of the change.** `filteredGames` applies it as the last narrowing
    /// stage, so every downstream consumer — the subtitle census, the
    /// inspector's resolution, and above all `gamesInDisplayOrder` — sees the
    /// order the reader is looking at. Left inside the table, a sort would
    /// reorder pixels while D24′ numbered exported files, the analysis queue
    /// picked its running order, and D56′ opened tabs, all three from the
    /// *unsorted* array. Nothing would fail; the filenames would simply stop
    /// matching the screen, which is the kind of disagreement this project has
    /// twice recorded as invisible until someone opens two things at once.
    ///
    /// `@State` and not `TabState`: a sort is not a fact about the window it
    /// was made in, and it deliberately does not survive a relaunch either —
    /// see the binding's doc in `LibraryListView` for that argument. Since the
    /// default is now a real ordering rather than "unsorted", not persisting
    /// means every launch opens on `#` descending, which is the point.
    @State private var sortOrder: [KeyPathComparator<PGN>] = Self.defaultSortOrder

    /// The launch order, stated **once**.
    ///
    /// Extracted the moment it was written, because the first spelling put it
    /// in the `@State` initializer above and the seven previews across this
    /// file's two mode views each repeated it — eight statements of one
    /// default, which is exactly the twin-read-site shape D25′ names and the
    /// eval bar's 20-vs-16 already cost this project a month of quiet
    /// disagreement. A preview drifting from the shipped default is the
    /// harmless-looking version of that: the canvas stops showing what the app
    /// opens on, and nothing fails.
    ///
    /// **Computed rather than stored**, the `SevenTagRosterSection.noGamePlaceholder`
    /// spelling — and `nonisolated` because `View` conformance would otherwise
    /// infer `@MainActor` onto it (the lesson `BoardPieceLayer` records at its
    /// own statics), which would stop previews and any future nonisolated
    /// caller from reaching it for no reason. `KeyPathComparator` is `Sendable`
    /// by `SortComparator`'s own refinement, so nothing here needs an opt-out.
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
    
    /// Sidebar filter → search → menu filters, in that order — narrowing
    /// only, so the stages compose without caring about each other. Every
    /// downstream consumer (`selectedPGN`, `gamesInDisplayOrder`, and
    /// therefore batch analyze/export/delete) reads the same narrowed list,
    /// which is exactly how the tag filter already behaved: a hidden game
    /// is out of every bulk action, never silently included.
    ///
    /// **Render reads it once; actions re-derive it fresh.** `coreContent`
    /// folds this a single time per pass and threads the result to the empty
    /// gate, the subtitle census, the mode view, and the inspector's
    /// resolution — `PlayersDestination`'s fold-once arrangement, arriving
    /// here 4 Aug 2026 after the walk was found running three to four times
    /// a render, each one a full tag-match + search pass over every game.
    /// `gamesInDisplayOrder` still calls it directly on purpose: an action
    /// fires long after the fold that painted the screen, and a stale
    /// narrowed list is exactly what bulk actions must not act on.
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
        // Sorting is the LAST stage, after every narrowing, and it is the stage
        // that makes "display order" mean what the reader sees. Note the
        // asymmetry with the stages above, which is deliberate: those *remove*
        // rows and compose in any order; this one only permutes. It has to come
        // last regardless, because sorting a set you are about to filter is
        // work thrown away.
        //
        // **Unconditional since the default became a real ordering** (5 Aug
        // 2026). This read `sortOrder.isEmpty ? result : …` while empty meant
        // "unsorted" and was the common case. `#` descending is the default
        // now, nothing in `Table`'s header behaviour ever empties the array,
        // and a branch whose condition cannot be produced is the `.disabled(…)`
        // shape D40′ names — so it goes rather than sitting here reading as a
        // considered fast path. `PlayersDestination` made the same call one
        // file over, for the same reason, an hour earlier.
        //
        // The honest cost of removing it: this fold runs once per render, so
        // the Library now sorts every render instead of only when sorted. For
        // `#` that is an `Int?` compare and invisible. For **ECO** it is not —
        // that comparator goes through `opening`, which rehydrates — so a
        // reader sitting on the ECO column pays a rehydrate per comparison per
        // render. On the known-costs census, not optimized ahead of M7.
        return result.sorted(using: sortOrder)
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
    /// `.onCommand` puts the action in the responder chain, which is what both
    /// enables the menu item and gives it its shortcut — the mechanism
    /// `.onDeleteCommand` used here until ⌫ was retired on 5 Aug 2026, and the
    /// reason ⌘A inside the
    /// search field still selects *text*: the field is first responder and
    /// answers first. List and columns are `Table`s, so `NSTableView` answers
    /// there too and this never fires; the set it produces is identical,
    /// because the table was built from the same narrowed array. Icons and
    /// gallery have no such responder, and for them this is the whole
    /// implementation.
    ///
    /// **Selects what the render painted, deliberately not what `filteredGames`
    /// would answer at action time** — the opposite of `gamesInDisplayOrder`'s
    /// rule directly above, for the opposite reason. That one re-derives
    /// because a destructive action firing against a stale list is the failure
    /// to prevent; this one *is* the visible state, so "select all" has to mean
    /// the rows on screen or it means something the user cannot check. The
    /// narrowing itself is unchanged either way: a game hidden by a smart tag,
    /// a query or a chip is not selected, so it stays out of every bulk action
    /// exactly as it always has.
    ///
    /// Nil on an empty list rather than a closure assigning an empty set: a nil
    /// action leaves Edit ▸ Select All disabled, and both arms of that guard
    /// are producible — the check D40′ taught this project to run *at minting*
    /// rather than at the next sweep.
    ///
    /// Not reached, and named so it isn't read as an oversight: the icons
    /// grid's `anchorID`, which is `@State` a destination cannot touch. After a
    /// ⌘A the next arrow steps from the last card clicked, or from the first
    /// card if none — Finder anchors at the last click too, so the divergence
    /// is only that ours has no anchor to inherit from a keyboard gesture.
    ///
    /// Takes the list rather than reading the property, and is a method rather
    /// than a closure factory, for one reason each: the parameter is what makes
    /// "the painted list" a fact about the call site instead of a promise; and
    /// a `@MainActor` type returning an escaping `() -> Void` is a shape this
    /// codebase has never needed, where `Button { delete(game) }` — a literal
    /// formed in place, calling a member — is the shape on every page of it.
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
            // `.onDeleteCommand { requestDeleteSelection() }` stood here until
            // 5 Aug 2026, by request: **plain ⌫ no longer deletes.**
            //
            // The reason is asymmetry of cost. ⌫ is one keystroke from where
            // your hands already are while a table row is focused, and its
            // whole failure mode is a multi-selection you forgot you had — the
            // gesture that used to be safest to hit by accident was the one
            // that raised a confirmation over forty games. ⌘⌫ is Finder's key
            // for the same verb and cannot be reached by a slipped finger.
            //
            // The shortcut moved to the toolbar's Delete button rather than
            // being spelled here, and that placement is deliberate rather than
            // convenient: a `keyboardShortcut` on a real, always-present,
            // already-`disabled`-guarded control is live whenever this
            // destination is showing, which the context menu's copy of ⌘⌫ is
            // only known to *render*. Removing this line without giving the key
            // a home that certain would have deleted the gesture rather than
            // narrowed it.
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
            Self.logger.info("Drop received: \(urls.count) URL(s)")
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
            .inspectorColumnWidth(min: 310, ideal: 310, max: 400)
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
        Self.logger.info("Open requested: \(pgns.count) game(s)")
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
        Self.logger.info("Analyze requested: '\(pgn.name, privacy: .public)'")
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
    
    /// The Library's two file doors, in and out — one toolbar cell, with a
    /// vertical divider between them. A single `ToolbarItem` (not two split
    /// by a `ToolbarSpacer`) so the pair shares one capsule: they are the
    /// two directions of the same job, and the explicit `Divider` marks the
    /// direction change inside it. Identifiers, helps and the disabled
    /// state stay on the individual buttons, so identifier lookups and the
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
    
    /// The confirmation's body: the lead sentence, plus a clause naming any
    /// players the deletion would take with it.
    ///
    /// **Appended only when there are any**, so the ordinary delete — which is
    /// nearly all of them — reads exactly as it did before the cascade landed.
    /// A line that says "and no players will be removed" on every deletion is
    /// the `.DS_Store` shape: text that is always there is text that stops
    /// being read, and the one time it matters would scroll past with the
    /// rest.
    ///
    /// Named rather than counted, D40′'s reason narrowed: the sweep names its
    /// rows because they are strangers the user has never seen. These are the
    /// opponent of the game on screen, so the argument is weaker — but the
    /// *effect* still lands in a destination the user isn't looking at, and
    /// the New Game seat menu quietly losing a name is exactly the kind of
    /// thing that reads as a bug six months later. Capped at five, matching
    /// the sweep, because it is the same list.
    ///
    /// Advisory, not authoritative: `PGNStore.delete(_:)` recomputes this at
    /// write time. A snapshot held across a confirmation is stale by
    /// construction — the lesson `deleteOrphanedPlayers` already carries — so
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
