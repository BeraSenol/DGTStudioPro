// `AppKit` for `selectAll(_:)` alone — see the twin import in
// `LibraryDestination` for why an AppKit *protocol* member needs the module
// named under `MemberImportVisibility`.
import AppKit
import os
import SwiftData
import SwiftUI

/// One ladder row: a player's rank under `PlayerStats.rankingOrder`
/// (D11′ — wins ↓, win rate ↓, key ↑; ranks are dense and distinct
/// because the comparator is total), with the Glicko rating riding along.
/// Moved here from the retired `RankingsDestination` (D48′) — since the
/// merge this is every mode view's row currency, in *both* orderings:
/// rank is a fact about the player, not a position in the current sort,
/// so an alphabetical list still shows #14 beside the name.
internal struct RankedPlayer: Identifiable, Hashable {
    internal let rank: Int
    internal let stats: PlayerStats
    internal let rating: Glicko1.Rating?

    internal var id: PlayerStats.ID { stats.id }
}

// `PlayersSortOrder` lived here until 5 Aug 2026 — D48′'s two orderings as a
// persisted enum behind a toolbar picker — with its `StorageKeys` key and the
// `playersSortPicker` identifier. Gone because the column headers sort now, and
// its two positions were the Rank and Player columns spelled a second way.
//
// Recorded rather than deleted quietly: it reverses part of a numbered
// decision, and the reason is not "columns are nicer" but that two controls
// answering one question is the twin-read-site shape. What D48′ decided still
// stands — rank is the default read, and renders in every ordering because it
// is a fact about the player rather than a position in the current sort.
//
// Genuinely lost: the picker's choice survived a relaunch and the column sort
// does not. Accepted — a sort is the question being asked now, not a standing
// preference, and the default is stated in code below rather than in defaults.

/// The Players destination (M-prs.3; absorbed Rankings in D48′): the four
/// `CollectionViewMode`s over the ranked ladder, in rank order by default
/// with a persisted toggle to alphabetical — one destination that knows
/// everything about a player, rather than two that each knew half.
///
/// All data is computed per body from the `@Query`: records project via
/// `\.gameRecord`, stats and ratings fold pure (D10′). Recomputing
/// beats caching for the same reason `LibraryColumnsView` documents —
/// the inputs (links, results) can change without the row set changing.
///
/// Selection is a `PlayerStats.ID` (the resolved key), `@State` like the
/// Library's — deliberately not on `TabState`: neither destination
/// promises selection survival across sidebar switches. It *does* survive
/// a re-sort, because every ordering speaks the same keys.
internal struct PlayersDestination: View {

    // MARK: Static Constants
    private static let logger = AppLog.logger(.players)

    // MARK: Tab State (lives on enclosing `ContentView`)
    @Bindable internal var tabState: TabState

    /// The M-prs.6 hop: hands the resolved player's identifier up to
    /// `ContentView`, which owns the sidebar selection. The app always
    /// wires it; the initializer's default keeps previews valid.
    internal let onShowInLibrary: (PersistentIdentifier) -> Void

    // MARK: Private Properties
    // Shared with the Library (see `StorageKeys.collectionViewMode`): the
    // last view mode used in either collection destination is what both
    // show. The `.list` default is the documented twin of the Library's.
    @AppStorage(StorageKeys.collectionViewMode) private var viewMode: CollectionViewMode = .list
    /// The list mode's column sort (5 Aug 2026), successor to D48′'s persisted
    /// picker. Ascending rank is the shipped default and **is** the D11′
    /// ladder — `rank` was folded through `PlayerStats.rankingOrder` before any
    /// view saw it, so ordering by the badge number reproduces the comparator
    /// without restating it.
    ///
    /// Owned here rather than in `PlayersListView` for `LibraryDestination`'s
    /// reason: `displayed` applies it, so the search below and everything
    /// downstream see one order. Less load-bearing than the Library's — Players
    /// has no export numbering and no tab order — but the two destinations
    /// stay parallel under the collection-destination parity invariant, and a
    /// reader who learns one has learned the other.
    @State private var sortOrder: [KeyPathComparator<RankedPlayer>] = Self.defaultSortOrder

    /// How the ladder is ordered (D62′) — what rank 1 means, not what order the
    /// rows appear in. Persisted, unlike the column sort one property up; see
    /// `StorageKeys.playersRanking` for why those two differ.
    @AppStorage(StorageKeys.playersRanking) private var ranking: PlayerRanking = .wins

    /// The ladder, stated **once** — `LibraryDestination.defaultSortOrder`'s
    /// twin under the collection-destination parity invariant, extracted for
    /// its reason (eight previews across two mode views were each repeating
    /// it) and computed-and-`nonisolated` for its reason.
    ///
    /// Ascending, and that direction is not a style choice: rank 1 is the top
    /// of the ladder, so ascending rank *is* D11′. Reversing this default would
    /// silently open Players on its worst player.
    internal nonisolated static var defaultSortOrder: [KeyPathComparator<RankedPlayer>] {
        [KeyPathComparator(\RankedPlayer.rank)]
    }
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PGN.importedAt, order: .reverse) private var games: [PGN]

    // The `registry` @Query lived here for D40′'s sweep — a second query over
    // `Player` so the toolbar's orphan count stayed reactive while the sweep
    // deleted the rows. Gone with the sweep (D60′): orphans are collected
    // inside the store doors now, so this destination has no reason to know
    // the registry exists. Its rows come from the `games` fold, as they always
    // did.

    /// A set since 2 Aug 2026, adopting the Library's selection model so
    /// the icons grid can rubber-band and the table can ⌘-click. Every
    /// single-player consumer (inspector profile, recent games, rename /
    /// merge) reads through the count-of-one guard, so a plural selection
    /// is a counted state, never "the first of the set wearing one
    /// player's face".
    @State private var selectedKeys: Set<PlayerStats.ID> = []

    // MARK: Search (2 Aug 2026)
    @State private var searchText = ""
    /// Rated-ness, as chips inside the field (3 Aug 2026). Was a
    /// `.searchScopes` bar, which had one flaw the Library's menu shared: it
    /// existed only while the field was focused, so a rating filter left the
    /// screen the moment search was dismissed while still narrowing the list.
    /// A chip stays visible and carries its own remove control.
    @State private var searchTokens: [PlayersSearchToken] = []

    // MARK: Player Editing (M5 — D40′; rename moved to Get Info by M10,
    // merge removed by D52′)

    // `renameRequest`, `RenameRequest` and `RetagRefusal` lived here until
    // M10. The rename door is `GetInfoWindow`'s player form now — the field,
    // the store call, D39′'s refusal alert and its message builder moved there
    // whole, so this destination holds no part of a write it cannot surface.
    //
    // What that closes, and it is the point rather than a side effect: this
    // file's copy had been reachable from nothing since M10 removed the
    // profile pencil, while `PlayersInspectorView` carried an `onRename` seam
    // documented as "a deadline, not a description". A store door with no
    // surface is the D40′ lie one layer down, and the deadline is met by the
    // door existing rather than by the seam being tidied.

    // `sweep` held D40′'s offer between the menu and its confirmation.
    // Removed with both (D60′).

    // MARK: Initializers

    /// Explicit for the same reason `LibraryDestination`'s is: the
    /// memberwise initializer's shape and visibility shift with the
    /// wrapped/private property details, and the call-site contract
    /// shouldn't. (M-prs.6 hit exactly that — the synthesized init
    /// refused the new argument at `ContentView`'s call site.)
    internal init(
        tabState: TabState,
        onShowInLibrary: @escaping (PersistentIdentifier) -> Void = { _ in }
    ) {
        self.tabState = tabState
        self.onShowInLibrary = onShowInLibrary
    }

    // MARK: Derived Data

    // `records` / `index` / `histories` are now folded once in `body` and
    // threaded down, replacing the prior per-computed-property
    // recomputation: `index` was re-derived three times a render — each
    // re-projecting the whole library — plus a fourth `histories` fold for
    // the inspector's rating. `selectedGames` stays a computed property: it
    // reads the selected player's games only, not the shared folds.

    /// The selected player's games, newest first by the one effective-date
    /// rule. Matching goes through the resolved link — never raw tags.
    /// Single-selection only: a plural selection has no "the player".
    private var selectedGames: [PGN] {
        guard selectedKeys.count == 1, let selectedKey = selectedKeys.first else { return [] }
        return games
            .filter {
                $0.whitePlayer?.normalizedName == selectedKey
                || $0.blackPlayer?.normalizedName == selectedKey
            }
            .sorted { $0.effectiveDate > $1.effectiveDate }
    }

    // MARK: Derived Data (D48′)

    /// Builds the ranked ladder from an already-computed projection and
    /// rating-history map — `RankingsDestination.ranked`'s exact shape,
    /// moved with the merge. Pure and `static` so it can't reach for
    /// instance state and silently re-derive: `body` folds once and threads.
    private static func ranked(
        from records: [GameRecord],
        histories: [String: [Glicko1.Sample]],
        by method: PlayerRanking
    ) -> [RankedPlayer] {
        // The ladder itself moved to `PlayerRanking.ranked(_:)` with D62′ —
        // this pairs each player with the rating the *other* fold produced and
        // hands both over. Pairing here rather than inside the method is what
        // keeps `PlayerRanking` free of any knowledge that histories are keyed
        // by `stats.key`, which is this destination's business.
        method.ranked(
            PlayerStats.index(of: records).map {
                (stats: $0, rating: histories[$0.key]?.last?.rating)
            }
        )
    }

    // MARK: Body
    internal var body: some View {
        // Fold once per render, then thread down (see the Derived Data note).
        let records = games.map(\.gameRecord)
        let histories = Glicko1.histories(from: records)
        let ranked = Self.ranked(from: records, histories: histories, by: ranking)
        // Rank is computed under D11′ regardless of display order — the sort
        // only decides sequence, never the number on the badge. That sentence
        // predates the column sort and survives it unchanged, which is the
        // clearest sign the two were separable all along.
        //
        // `ranked` already arrives in ladder order, so the common case sorts an
        // array that is already sorted. Left as an unconditional call rather
        // than special-cased: the Library guards its equivalent because *empty*
        // there means "no sort at all", while here there is always exactly one
        // comparator and the guard would be checking for a state that cannot
        // occur.
        let displayed = ranked.sorted(using: sortOrder)
        // Search narrows the *list only*. `selected` / `history` below read
        // the full ladder, so a player filtered out of view keeps their
        // inspector profile — searching is about finding, not deselecting.
        //
        // **The rating filter no longer waits for a query, and that is the
        // point of the change.** Under the scope bar it had to: the bar only
        // existed during a search, so a text-independent scope would have
        // kept narrowing the list invisibly after the field closed. A token
        // is a chip that stays on screen, so the reason for the gate is gone
        // — filtering with nothing typed is now visible by construction,
        // which is the whole argument for moving off scopes. The gate stays
        // on the *text* half, where an empty query still matches everything
        // by the matcher's own contract and the walk is pure cost.
        // The query folds once out here, not once per row inside the
        // closure — `SearchMatch.Query`'s whole reason (4 Aug 2026). An
        // all-whitespace query now also skips the walk, which the raw
        // `searchText.isEmpty` gate let through; the matcher answered it
        // "everything" either way.
        let query = SearchMatch.Query(searchText)
        let searched = (query.isEmpty && searchTokens.isEmpty)
        ? displayed
        : displayed.filter {
            PlayersSearchToken.admit(searchTokens, rating: $0.rating)
            && (query.isEmpty || query.matches(fields: [$0.stats.name]))
        }
        // One player or none: the profile inputs resolve only for a
        // count-of-one selection; plural renders the counting state.
        let soleKey = selectedKeys.count == 1 ? selectedKeys.first : nil
        let selected = soleKey.flatMap { key in ranked.first { $0.id == key } }
        let history = soleKey.flatMap { histories[$0] } ?? []

        // The store owns the rule, the query owns the rows (D40′).

        // Exactly two selected is the head-to-head question, and the one
        // gesture in this destination that had no payoff — the inspector
        // resolves for a count of one and renders a bare count above that.
        //
        // Ordered off the *displayed* ladder rather than off `selectedKeys`,
        // which is a `Set` and has no order to offer: the pair reads in the
        // order they appear on screen, so the sentence matches the rows the
        // user just clicked. Reading a record backwards is the failure this
        // guards against — 7–3–2 and 2–3–7 are equally believable.
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

        return coreContent(players: searched)
            .navigationTitle("Players")
            .navigationSubtitle(
                DestinationSubtitle.players(
                    selected: selectedKeys.count,
                    headToHead: headToHead
                ) ?? ""
            )
            .inspector(isPresented: $tabState.playersInspectorPresented) {
                PlayersInspectorView(
                    ranked: selected,
                    history: history,
                    recentGames: selectedGames,
                    selectionCount: selectedKeys.count
                )
                .inspectorColumnWidth(min: 310, ideal: 310, max: 400)
            }
            .toolbar { toolbarContent }
            // `.searchScopes` is gone with the scope bar — the same three
            // choices are chips now. `suggestedTokens` drops what is already
            // applied, so the list never offers a chip you are wearing.
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
            .onAppear {
                // Players must work even if Library was never visited this
                // launch — the backfill is store-owned; this is just the
                // second call site (see `PGNStore.backfillPlayerLinks`).
                backfillPlayerLinks()
                applyInspectorPolicy(for: viewMode)
            }
            .onChange(of: viewMode) { _, mode in
                applyInspectorPolicy(for: mode)
            }
    }

    // MARK: Instance Methods

    /// The Library's `applyInspectorPolicy` twin, and deliberately a twin
    /// rather than a shared helper: it reads *this* destination's binding on
    /// `TabState`, and the only way to share it would be to pass that binding
    /// in — a parameter whose sole purpose is to tell a shared function which
    /// destination is calling it. Two four-line copies of a rule that lives
    /// on `CollectionViewMode` is the smaller cost. The rule itself is not
    /// duplicated; only the assignment is.
    ///
    /// Parity is why this exists here at all: Players' columns mode is the
    /// same `HSplitView` shape with the same 160/320 floors (both destinations
    /// came down together in the 3 Aug flat-columns redesign — this said
    /// 220/320 until 4 Aug, a stale number outliving its layout), and its
    /// detail pane repeats the profile the inspector shows. It has not been
    /// seen to overflow — Players' detail is a stat grid where the Library's
    /// has been a monospaced text pane since the board left it — but the
    /// difference is content, not structure, and collection-destination
    /// parity is an invariant.
    private func applyInspectorPolicy(for mode: CollectionViewMode) {
        if mode.ownsDetailPane {
            tabState.playersInspectorPresented = false
        } else if mode == .gallery {
            tabState.playersInspectorPresented = true
        }
    }

    /// Resolves the pure stats key to its `Player` row and hops the
    /// sidebar into the programmatic player filter. Store-owned lookup,
    /// never creates (D9′ — the single creation door; D13′ is the
    /// illegal-move alert sound); a miss — impossible for a key the index
    /// emitted — is a logged no-op.
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

    // MARK: Player Editing (M5)

    // `beginRename` and `rename(key:to:)` lived here until M10 and are
    // `GetInfoWindow.commitRename` now. One behaviour did not survive the
    // move, recorded rather than left to be noticed: `rename` used to follow
    // the rename with `selectedKeys = [newKey]`, because a stats key is
    // derived from the name and the old selection points at a player that no
    // longer exists under it. A separate window cannot reach into this
    // destination's selection, so a rename performed while Players is open
    // now clears the selection instead of following it. Accepted — the row is
    // one click away and under the name you just typed — and it is the price
    // of the door being one surface for three destinations rather than a
    // pencil on this one.
    //
    // `resolvedPlayer(for:)` went with them: `showInLibrary` above carries its
    // own inline lookup and was never a caller.

    /// ⌘A over all four view modes. `LibraryDestination.selectAll(_:)` carries
    /// the full argument — the responder chain, `Table` answering first in list
    /// and columns, nil-on-empty leaving Edit ▸ Select All disabled — and it is
    /// not restated here.
    ///
    /// Two four-line copies rather than one shared helper, `applyInspectorPolicy`'s
    /// call two methods up: sharing this would mean passing in the selection
    /// binding *and* the row currency, which is a parameter list whose only job
    /// is to tell a shared function which destination is calling it.
    ///
    /// `players` is the **searched** ladder, and that is the one place this
    /// destination has to be read rather than copied. Search here narrows the
    /// list only and never deselects — `body` says so, and the profile of a
    /// player scrolled out by a query deliberately survives. ⌘A still means the
    /// rows on screen, because the alternative selects people the reader cannot
    /// see, and this destination has a subtitle that would then name two
    /// strangers as a head-to-head.
    private func selectAll(_ players: [RankedPlayer]) {
        selectedKeys = Set(players.map(\.id))
    }

    @ViewBuilder
    private func coreContent(players: [RankedPlayer]) -> some View {
        // The Library's arrangement, down to the explicit type: nil when there
        // is nobody to select, so the system menu item disables itself.
        let selectAllAction: (() -> Void)? = players.isEmpty
        ? nil
        : { selectAll(players) }
        Group {
            if players.isEmpty {
                // The Library's two-vocabulary gate: a search that matched
                // nobody is not an empty registry. Narrowing requires text
                // (the scope is text-gated above), so the query is the
                // whole test. The identifier stays on the true empty state.
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
                                     onShowInLibrary: showInLibrary)
                case .list:
                    PlayersListView(players: players, selectedKeys: $selectedKeys,
                                    onShowInLibrary: showInLibrary,
                                    sortOrder: $sortOrder)
                case .columns:
                    // Flat list + detail since the Finder-column redesign
                    // (2 Aug 2026): the list follows `players`' display
                    // order, which the list mode's column sort now sets
                    // (5 Aug 2026, replacing the Sort picker this comment
                    // used to name) — so this mode reads the order without
                    // being able to change it. The grouping vocabulary D48′
                    // chose here went with the grid it navigated. The detail
                    // feeds on the same `selectedGames` the inspector receives.
                    PlayersColumnsView(players: players,
                                       selectedKeys: $selectedKeys,
                                       recentGames: selectedGames,
                                       onShowInLibrary: showInLibrary,
                                       sortOrder: $sortOrder)
                case .gallery:
                    PlayersGalleryView(players: players, selectedKeys: $selectedKeys,
                                       onShowInLibrary: showInLibrary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(AccessibilityID.playersContent)
        .onCommand(
            #selector(NSStandardKeyBindingResponding.selectAll(_:)),
            perform: selectAllAction
        )
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Players",
            systemImage: "person.2",
            description: Text("Players appear here as games with named players are imported or archived.")
        )
        .accessibilityIdentifier(AccessibilityID.playersEmptyState)
    }

    /// One stream, the Library's shape: every item in a single builder with
    /// `ToolbarSpacer` marking the break before the trailing pair. Stacking
    /// `.inspectorToggle` as a second `.toolbar` modifier left the toolbar
    /// undivided and the inspector column tucked below it — see
    /// `InspectorToggleContent`.
    ///
    /// The tail is pinned, shared with the Library by arrangement: the
    /// inspector toggle is always the trailing-most item and the view-mode
    /// picker always sits immediately to its left — the same two controls
    /// in the same two places whichever collection destination is showing.
    /// The spacer between them is `.fixed`: adjacent, but the toggle keeps
    /// its own group rather than sharing a pill with content controls (the
    /// `InspectorToggleContent` contract).
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarSpacer(.fixed)
        ToolbarItem {
            // D62′ — what rank 1 means. **Not a sort control**, which is the
            // one thing a reader could mistake it for: this changes the number
            // on the badge, and the column sort changes the sequence rows
            // appear in. Both can be active and they answer different
            // questions.
            //
            // A menu picker rather than a segmented control, on D48′'s own
            // reasoning for the picker that used to stand here: two segmented
            // controls side by side read as one broken one, and the view-mode
            // picker two items along is already segmented.
            //
            // The label carries the *current* method rather than a static word,
            // because a menu titled "Ranking" tells you a menu exists and this
            // tells you what the ladder is currently measuring — which is the
            // thing you would otherwise have to open it to find out.
            Picker("Ranking", selection: $ranking) {
                ForEach(PlayerRanking.allCases) { method in
                    Text(method.displayName).tag(method)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 6)
            .help("Ranked by \(ranking.shortName) — changes what rank 1 means, not the row order")
            .accessibilityIdentifier(AccessibilityID.playersRankingPicker)
        }
        // D48′'s sort picker stood here until 5 Aug 2026 — gone rather than
        // disabled, since the column headers sort now and its two positions
        // were the Rank and Player columns under another name. The toolbar
        // keeps only what the columns cannot reach.
        //
        // Honest cost: the other three view modes have no headers, so they can
        // no longer *change* the order. They still **obey** it — `displayed`
        // sorts before `coreContent` fans out, so a sort made in list mode
        // survives a switch to gallery. A read/write split rather than a loss
        // of function, accepted at one reader; if changing it from those modes
        // ever bites, the answer is a control they own, not this one restored.
        // D40′'s Maintenance menu stood here until 5 Aug 2026, holding one
        // item — Delete Unused Players… — disabled when there were none.
        //
        // Removed with the manual sweep (D60′), and the reason is D40′'s own:
        // orphans are collected inside the store doors now, so the enabling
        // condition can never be produced and the item would sit permanently
        // greyed. "A disabled affordance whose guard can never be true is a lie
        // with a green build" is that decision's sentence, and it is what
        // retired its own surface.
        //
        // This is also why `toolbarContent` stopped taking an argument: the
        // orphan list was the only thing ever passed in.
        ToolbarSpacer(.fixed)
        ToolbarItem {
            // Same macOS segmented-picker caveat as the Library's: the
            // identifier tags the container — macOS exposes the segments
            // as their SF Symbol names, never as children of it. (The
            // suite that addressed them that way is gone — D51′.)
            Picker("View Mode", selection: $viewMode) {
                ForEach(CollectionViewMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(AccessibilityID.playersViewModePicker)
        }
        ToolbarSpacer(.fixed)
        InspectorToggleContent(
            isPresented: $tabState.playersInspectorPresented,
            identifier: AccessibilityID.playersInspectorToggle,
            isDisabled: viewMode.ownsDetailPane,
            disabledReason: "Columns view shows details in its own pane"
        )
    }

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
}

// MARK: Previews

#Preview {
    PlayersDestination(tabState: TabState())
        .modelContainer(for: PGN.self, inMemory: true)
        .frame(width: 800, height: 500)
        .environment(InspectorSectionCollapse.preview)
}
