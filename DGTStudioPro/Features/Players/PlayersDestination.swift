// `AppKit` for `selectAll(_:)` - an AppKit protocol member under `MemberImportVisibility` (see Library twin).
import AppKit
import os
import SwiftData
import SwiftUI

/// One ladder row: rank under `PlayerStats.rankingOrder` with the Glicko rating riding
/// along. Every mode view's row currency in both orderings - rank is a fact about the player,
/// not a position in the current sort.
struct RankedPlayer: Identifiable, Hashable {
    let rank: Int
    let stats: PlayerStats
    let rating: Glicko1.Rating?

    var id: PlayerStats.ID { stats.id }
}

/// The Players destination (absorbed Rankings): the four `CollectionViewMode`s over the
/// ranked ladder - one destination that knows everything about a player.
struct PlayersDestination: View {

    // MARK: Static Constants
    private static let logger = AppLog.logger(.players)

    // MARK: Tab State (lives on enclosing `ContentView`)
    @Bindable var tabState: TabState

    /// M-prs.6 hop: hands the resolved player id up to `ContentView`, which owns the sidebar selection.
    let onShowInLibrary: (PersistentIdentifier) -> Void

    // MARK: Private Properties
    // Per-destination since 18 Aug 2026, owned by `CollectionViewOptions`. The `.list` twin with
    // LibraryDestination is retired: the default is stated once, in that type.
    private var viewMode: CollectionViewMode { options.playersViewMode }

    /// What this destination tells the ⌘J panel it is - the Library's twin, see there.
    private var subject: CollectionViewOptionsSubject {
        CollectionViewOptionsSubject(collection: .players, mode: viewMode)
    }

    /// The mirror, gated on this window being key. The Library's twin, see there.
    private func latchSubjectIfKey() {
        guard controlActiveState == .key else { return }
        options.activeSubject = subject
    }

    /// Built by hand rather than projected with `@Bindable` - the picker lives in a computed
    /// `@ToolbarContentBuilder` property, which cannot declare one.
    private var viewModeBinding: Binding<CollectionViewMode> {
        Binding(get: { options.playersViewMode }, set: { options.playersViewMode = $0 })
    }
    /// List-mode column sort. Ascending rank is the default and **is** the ladder - ordering by
    /// the badge reproduces the comparator without restating it. Display only; resets per launch.
    private var sortOrder: Binding<[KeyPathComparator<RankedPlayer>]> {
        Binding(
            get: { options.playersSort.comparators },
            set: { newValue in
                guard let sort = CollectionSort<PlayersSortField>(comparators: newValue) else { return }
                options.playersSort = sort
            }
        )
    }

    /// How the ladder is scored - what rank 1 means, not row order. Persisted, unlike the column sort.
    @AppStorage(StorageKeys.playersRanking) private var ranking: PlayerRanking = .wins

    /// The ladder, stated once (`LibraryDestination.defaultSortOrder`'s twin). Ascending: rank 1 is the top.
    nonisolated static var defaultSortOrder: [KeyPathComparator<RankedPlayer>] {
        [KeyPathComparator(\RankedPlayer.rank)]
    }
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    /// The View Options panel's subject (7 Aug 2026) - see `sortOrder`.
    @Environment(CollectionViewOptions.self) private var options

    /// Is this destination's window the key one? The Library's twin - the full account of why this
    /// is not `@FocusedValue(\.collectionViewOptionsSubject)` any more lives there. Short version:
    /// reading back the key this view publishes made the body depend on its own output, which is
    /// the launch-time `FocusedValue update tried to update multiple times per frame` line.
    @Environment(\.controlActiveState) private var controlActiveState
    @Query(sort: \PGN.importedAt, order: .reverse) private var games: [PGN]

    /// A set (the Library's selection model): rubber-band and ⌘-click work, and every single-player
    /// consumer reads through the count-of-one guard - never "the first of the set".
    @State private var selectedKeys: Set<PlayerStats.ID> = []

    /// The three folds this destination cannot render without - computed from the same `records` in
    /// one pass, so one cache, not three.
    private struct Fold {
        let records: [GameRecord]
        let histories: [String: [Glicko1.Sample]]
        let stats: [PlayerStats]
    }

    /// Memoized on content only (see `CollectionFoldKey`): nothing folded here reads `evaluations`.
    /// The ranking method is deliberately NOT in the key - re-ranking is cheap; re-folding is not.
    @State private var foldCache = CollectionFoldCache<CollectionFoldKey, Fold>()

    /// The display inputs as one value - the Library's `NarrowKey`, this destination's
    /// vocabulary. A missed input here is stale rows on screen; the suite pins the field list.
    struct DisplayKey: Equatable {
        let content: CollectionFoldKey
        let method: PlayerRanking
        let sort: [KeyPathComparator<RankedPlayer>]
        let query: String
        let tokens: [PlayersSearchToken]
    }

    /// The ladder, its sorted projection, and the searched list - cached as one unit so the
    /// per-render `sorted(using:)` runs only when an input moves.
    struct Display {
        let ranked: [RankedPlayer]
        let displayed: [RankedPlayer]
        let searched: [RankedPlayer]
    }

    @State private var displayCache = CollectionFoldCache<DisplayKey, Display>()

    /// The selected player's games, keyed and cached (21 Aug 2026). A **separate** box rather than
    /// a field on `DisplayKey`: that key's completeness is pinned by its own suite, and widening it
    /// would re-fold the whole ladder every time the selection moved - which is the opposite of
    /// what this needs. Ranking and selection change for different reasons and deserve different
    /// keys.
    @State private var selectedGamesCache =
        CollectionFoldCache<SelectionKey, [PGN]>()

    /// Content plus the selection - the two things the recent-games walk reads.
    struct SelectionKey: Equatable {
        let content: CollectionFoldKey
        let keys: Set<String>
    }

    // MARK: Search (2 Aug 2026)
    @State private var searchText = ""
    /// Rated-ness as chips. Was `.searchScopes`, which only existed while the field was focused -
    /// a filter could keep narrowing invisibly. A chip stays visible with its own remove control.
    @State private var searchTokens: [PlayersSearchToken] = []

    // MARK: Player Editing (rename lives in Get Info)

    // MARK: Initializers

    /// Explicit: the memberwise init's shape shifts with wrapped/private property details, and the
    /// call-site contract shouldn't.
    init(
        tabState: TabState,
        onShowInLibrary: @escaping (PersistentIdentifier) -> Void = { _ in }
    ) {
        self.tabState = tabState
        self.onShowInLibrary = onShowInLibrary
    }

    // MARK: Derived Data
    // `records` / `index` / `histories` fold once in `body` and thread down (`index` used to be
    // re-derived three times a render). `selectedGames` joined them on 21 Aug 2026.

    /// The selected player's games, newest first. Matching goes through the resolved link - never raw
    /// tags. Single-selection only.
    ///
    /// **Memoized and threaded, not computed twice** (21 Aug 2026). The old computed property was
    /// excused from the fold as "it reads one player's games" - but it read one player's games *by
    /// filtering all of them*, faulting two SwiftData relationships per game and then sorting, and
    /// `body` read it twice (the inspector's `recentGames` and the columns mode's). So the whole
    /// Library was walked and sorted twice per render whenever exactly one player was selected.
    /// Now it folds under `SelectionKey` and travels down as a value.
    private func selectedGames(content: CollectionFoldKey) -> [PGN] {
        selectedGamesCache.value(
            for: SelectionKey(content: content, keys: selectedKeys)
        ) {
            guard selectedKeys.count == 1, let selectedKey = selectedKeys.first else { return [] }
            return games
                .filter {
                    $0.whitePlayer?.normalizedName == selectedKey
                    || $0.blackPlayer?.normalizedName == selectedKey
                }
                .sorted { $0.effectiveDate > $1.effectiveDate }
        }
    }

    // MARK: Derived Data

    /// The ranked ladder from an already-computed index and history map. Pure and `static` so it
    /// can't reach for instance state and silently re-derive.
    private static func ranked(
        from stats: [PlayerStats],
        histories: [String: [Glicko1.Sample]],
        by method: PlayerRanking
    ) -> [RankedPlayer] {
        // Pairing here keeps `PlayerRanking` ignorant of how histories are keyed.
        method.ranked(
            stats.map {
                (stats: $0, rating: histories[$0.key]?.last?.rating)
            }
        )
    }

    // MARK: Body
    var body: some View {
        // Fold once per *change*, then thread down (was three unconditional folds per render).
        let contentKey = CollectionFoldKey(games: games)
        let fold = foldCache.value(for: contentKey) {
            let records = games.map(\.gameRecord)
            return Fold(
                records: records,
                histories: Glicko1.histories(from: records),
                stats: PlayerStats.index(of: records)
            )
        }
        let records = fold.records
        let histories = fold.histories
        // Rank, sort and search re-run only when a `DisplayKey` input moves. Rank is still
        // computed under the ranking method regardless of display order - the sort decides
        // sequence, never the number on the badge. Search narrows the *list only* - `selected` /
        // `history` read the full ladder, so a player filtered out keeps their inspector profile.
        let display = displayCache.value(
            for: DisplayKey(
                content: contentKey,
                method: ranking,
                sort: sortOrder.wrappedValue,
                query: searchText,
                tokens: searchTokens
            )
        ) {
            let ranked = Self.ranked(from: fold.stats, histories: histories, by: ranking)
            let displayed = ranked.sorted(using: sortOrder.wrappedValue)
            let query = SearchMatch.Query(searchText)
            let searched = (query.isEmpty && searchTokens.isEmpty)
            ? displayed
            : displayed.filter {
                PlayersSearchToken.admit(searchTokens, rating: $0.rating)
                && (query.isEmpty || query.matches(fields: [$0.stats.name]))
            }
            return Display(ranked: ranked, displayed: displayed, searched: searched)
        }
        let ranked = display.ranked
        let displayed = display.displayed
        let searched = display.searched
        // One player or none: profile inputs resolve only for a count-of-one selection.
        let soleKey = selectedKeys.count == 1 ? selectedKeys.first : nil
        let selected = soleKey.flatMap { key in ranked.first { $0.id == key } }
        let history = soleKey.flatMap { histories[$0] } ?? []

        // The store owns the rule, the query owns the rows.
        // Exactly two selected is the head-to-head question. Ordered off the *displayed* ladder -
        // `selectedKeys` is a `Set` with no order, and the sentence must match the rows on screen.
        let pair = selectedKeys.count == 2
        ? displayed.filter { selectedKeys.contains($0.id) }
        : []
        let headToHead: (first: String, second: String, record: (Int, Int, Int))? = {
            guard pair.count == 2,
                  let record = PlayerStats.headToHead(
                    pair[0].stats.key, pair[1].stats.key, in: records
                  )
            else { return nil }
            return (pair[0].stats.name, pair[1].stats.name,
                    (record.wins, record.draws, record.losses))
        }()

        // One walk per render, threaded to both consumers - it was read twice.
        let recentGames = selectedGames(content: contentKey)

        return coreContent(
            players: searched,
            history: history,
            records: records,
            recentGames: recentGames
        )
            .navigationTitle("Players")
            .navigationSubtitle(
                DestinationSubtitle.players(
                    selected: selectedKeys.count,
                    headToHead: headToHead
                ) ?? ""
            )
            // Closed BY DEFAULT in the self-detailing modes, not disabled (17 Aug 2026 - the
            // day's second revision: first auto-hidden in gallery, then re-enabled everywhere
            // by request): entering columns or gallery closes it once (the `onChange` on the
            // content), and the toggle stays live for a reader who wants both surfaces.
            .inspector(isPresented: $tabState.playersInspectorPresented) {
                PlayersInspectorView(
                    ranked: selected,
                    history: history,
                    recentGames: recentGames,
                    selectionCount: selectedKeys.count
                )
                // Pinned to the app-wide width - `InspectorColumn.width` owns the number and
                // the argument. Retired this strip-tag: the unified spelling supersedes the 365.
                .inspectorColumnWidth(
                    min: InspectorColumn.width,
                    ideal: InspectorColumn.width,
                    max: InspectorColumn.width
                )
            }
            .toolbar { toolbarContent }
            // Scope bar gone - same choices as chips; suggestions drop what is already applied.
            .searchable(
                text: $searchText,
                tokens: $searchTokens,
                suggestedTokens: .constant(
                    PlayersSearchToken.allCases.filter { !searchTokens.contains($0) }
                ),
                placement: .toolbarPrincipal,
                prompt: "Search Players"
            ) { token in
                Label(token.displayName, systemImage: token.symbol)
            }
            // The Library's twin - see there for why the subject carries the mode too, and why
            // this view publishes the key without reading it back.
            .focusedSceneValue(\.collectionViewOptionsSubject, subject)
            .onChange(of: subject) { _, _ in latchSubjectIfKey() }
            .onChange(of: controlActiveState) { _, _ in latchSubjectIfKey() }
            .onAppear {
                latchSubjectIfKey()
                // Players must work even if Library was never visited this launch - store-owned, second call site.
                PGNStore.healPlayers(in: modelContext, logger: Self.logger)
                applyInspectorPolicy(for: viewMode)
            }
            .onChange(of: viewMode) { _, mode in
                applyInspectorPolicy(for: mode)
            }
    }

    // MARK: Instance Methods

    /// Applies the mode's own opinion to this destination's flag. This doc used to argue the twin
    /// was deliberate - "sharing would mean a parameter whose only job is to say who's calling" -
    /// and that argument was right about a shared *function*, which is why the 18 Aug 2026 pass
    /// moved the **policy** onto `CollectionViewMode` instead. Nothing is passed; what remains here
    /// is the one line that is genuinely this destination's: which flag it writes.
    private func applyInspectorPolicy(for mode: CollectionViewMode) {
        guard let presented = mode.inspectorPresentationOnEntry else { return }
        tabState.playersInspectorPresented = presented
    }

    /// Resolves the stats key to its `Player` row and hops the sidebar into the player filter.
    /// Store-owned lookup, never creates; a miss is a logged no-op.
    private func showInLibrary(key: PlayerStats.ID) {
        do {
            guard let player = try PGNStore(modelContext: modelContext)
                .player(withNormalizedKey: key) else {
                Self.logger?.error("Show in Library: no Player row for key '\(key, privacy: .public)'")
                return
            }
            onShowInLibrary(player.persistentModelID)
        } catch {
            Self.logger?.error("Show in Library lookup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// ⌘A over all four modes - `LibraryDestination.selectAll(_:)` carries the full argument.
    /// Selects the rows on screen; a profile scrolled out by a query deliberately survives.
    private func selectAll(_ players: [RankedPlayer]) {
        selectedKeys = Set(players.map(\.id))
    }

    /// The sole selection's rating history, threaded for the gallery's trend chart; the other three
    /// modes have the inspector for this. `records` rides along for the gallery's opponents and form
    /// panels - both are per-selection folds, so the array travels rather than an answer.
    @ViewBuilder
    private func coreContent(
        players: [RankedPlayer],
        history: [Glicko1.Sample],
        records: [GameRecord],
        recentGames: [PGN]
    ) -> some View {
        // Nil when there is nobody to select, so the system menu item disables itself.
        let selectAllAction: (() -> Void)? = players.isEmpty
        ? nil
        : { selectAll(players) }
        Group {
            if players.isEmpty {
                // Two-vocabulary gate: a search that matched nobody is not an empty registry.
                // The identifier stays on the true empty state.
                if searchText.isEmpty {
                    emptyState
                } else {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "magnifyingglass",
                        description: Text("No players match the current search.")
                    )
                }
            } else {
                switch viewMode {
                case .icons:
                    PlayersIconsView(players: players, selectedKeys: $selectedKeys,
                                     onShowInLibrary: showInLibrary,
                                     onOpenInfo: { openPlayerInfo($0, in: players) })
                case .list:
                    PlayersListView(players: players, selectedKeys: $selectedKeys,
                                    onShowInLibrary: showInLibrary,
                                    sortOrder: sortOrder,
                                    onOpenInfo: { openPlayerInfo($0, in: players) })
                case .columns:
                    // Flat list + detail (Finder-columns redesign); the list follows `players`' display order.
                    PlayersColumnsView(players: players,
                                       selectedKeys: $selectedKeys,
                                       recentGames: recentGames,
                                       onShowInLibrary: showInLibrary,
                                       sortOrder: sortOrder)
                case .gallery:
                    PlayersGalleryView(players: players, selectedKeys: $selectedKeys,
                                       history: history,
                                       records: records,
                                       onShowInLibrary: showInLibrary,
                                       onOpenInfo: { openPlayerInfo($0, in: players) })
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(AccessibilityID.playersContent)
        // Entering a self-detailing mode closes the inspector once; the toggle reopens it -
        // closed-by-default, never disabled (17 Aug 2026, by request).
        .onChange(of: viewMode) { _, mode in
            if mode.ownsDetailPane || mode == .gallery {
                tabState.playersInspectorPresented = false
            }
        }
        .onCommand(
            #selector(NSStandardKeyBindingResponding.selectAll(_:)),
            perform: selectAllAction
        )
    }

    /// Double-click's door (17 Aug 2026, by request) - **the same window the menus' Get Info opens
    /// since 18 Aug 2026**, when the Matchup window merged into it. The click lands on the Info tab
    /// (Bera's order), so the profile it used to open directly is one tab along. Two doors, one
    /// window: `openWindow(value:)` dedupes on the request, so double-clicking a player whose info
    /// window is already open focuses it rather than opening a second view of one player.
    ///
    /// Columns mode deliberately has no double-click: its detail pane is already the profile, and a
    /// second door from the same click would race the selection.
    ///
    /// The lookup survives the request's shrinking: `GetInfoRequest.player` carries only the key
    /// (the window re-titles itself from the fetched row), but a double-click on a row that is no
    /// longer in `players` should open nothing at all, and this guard is what says so.
    private func openPlayerInfo(_ key: PlayerStats.ID, in players: [RankedPlayer]) {
        guard let player = players.first(where: { $0.id == key }) else { return }
        openWindow(value: GetInfoRequest.player(key: player.stats.key))
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Players",
            systemImage: "person.2",
            description: Text("Players appear here as games with named players are imported or archived.")
        )
        .accessibilityIdentifier(AccessibilityID.playersEmptyState)
    }

    /// One stream, the Library's shape: every item in a single builder, `ToolbarSpacer` marking the
    /// break. Stacking a second `.toolbar` modifier left the toolbar undivided and the inspector
    /// column tucked below it.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarSpacer(.fixed)
        ToolbarItem {
            // What rank 1 means. **Not a sort control**: this changes the badge; the column sort
            // changes the row sequence. Both can be active.
            Picker("Ranking", selection: $ranking) {
                ForEach(PlayerRanking.allCases) { method in
                    Text(method.displayName).tag(method)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 6)
            .help("Ranked by \(ranking.shortName). Changes what rank 1 means, not the row order")
            .accessibilityIdentifier(AccessibilityID.playersRankingPicker)
        }
        // The sort picker is gone - the column headers sort now; the toolbar keeps only what the
        // columns cannot reach.
        ToolbarSpacer(.fixed)
        ToolbarItem {
            // macOS segmented-picker caveat (see Library): the identifier tags the container; segments
            // expose as SF Symbol names.
            Picker("View Mode", selection: viewModeBinding) {
                ForEach(CollectionViewMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(AccessibilityID.playersViewModePicker)
        }
        ToolbarSpacer(.fixed)
        // Always enabled (17 Aug 2026, by request - `isDisabled` retired): the self-detailing
        // modes close the inspector on entry instead, and the toggle is how a reader disagrees.
        InspectorToggleContent(
            isPresented: $tabState.playersInspectorPresented,
            identifier: AccessibilityID.playersInspectorToggle
        )
    }
}

// MARK: Previews

#Preview {
    PlayersDestination(tabState: TabState())
        .modelContainer(for: PGN.self, inMemory: true)
        .frame(width: 800, height: 500)
        .environment(InspectorSectionCollapse.preview)
        // Read since 16 Aug (the View Options pass); uninjected, the canvas traps - the
        // ContentView preview's find, applied here in the same sweep.
        .environment(PreviewFixtures.viewOptions())
}
