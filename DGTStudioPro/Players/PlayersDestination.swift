//
//  PlayersDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

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

/// The merged destination's two orderings (D48′). Raw values are the stored
/// form (an `@AppStorage` key), so they are spelled out — the
/// `InspectorSection` rule: a rename that reads as a refactor must not
/// silently reset the user's choice.
internal enum PlayersSortOrder: String, CaseIterable, Identifiable, Sendable {
    case rank = "rank"
    case name = "name"

    internal var id: String { rawValue }

    internal var displayName: String {
        switch self {
        case .rank: "By Rank"
        case .name: "By Name"
        }
    }
}

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
/// a sort toggle, because both orderings speak the same keys.
internal struct PlayersDestination: View {

    // MARK: Static Constants
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "players"
    )

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
    @AppStorage(StorageKeys.playersSortOrder) private var sortOrder: PlayersSortOrder = .rank
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PGN.importedAt, order: .reverse) private var games: [PGN]

    /// The player registry, for the orphan sweep only (D40′) — the rows the
    /// index cannot show. A second `@Query` rather than a fetch inside `body`
    /// because the sweep deletes `Player` rows and nothing else: driven off
    /// `games` alone, the toolbar's count would still name the rows it had just
    /// removed. `MergePlayerSheet` queries the same way for the same reason.
    @Query(sort: \Player.name) private var registry: [Player]

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

    /// D40′'s sweep, held between offer and confirmation — the same optional-
    /// array shape as the Library's `pendingBatchDeletion`. It is a *snapshot*
    /// of rows, which is why the store door re-checks each one before deleting:
    /// a player listed here can pick up a link before the alert is answered.
    @State private var sweep: [Player]?

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
        histories: [String: [Glicko1.Sample]]
    ) -> [RankedPlayer] {
        PlayerStats.index(of: records)
            .sorted(by: PlayerStats.rankingOrder)
            .enumerated()
            .map { offset, stats in
                RankedPlayer(
                    rank: offset + 1,
                    stats: stats,
                    rating: histories[stats.key]?.last?.rating
                )
            }
    }

    // MARK: Body
    internal var body: some View {
        // Fold once per render, then thread down (see the Derived Data note).
        let records = games.map(\.gameRecord)
        let histories = Glicko1.histories(from: records)
        let ranked = Self.ranked(from: records, histories: histories)
        // Rank is computed under D11′ regardless of display order — the sort
        // only decides sequence, never the number on the badge.
        let displayed = sortOrder == .rank
        ? ranked
        : ranked.sorted { $0.stats.name < $1.stats.name }
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
        let orphans = registry.filter(PGNStore.isOrphaned)

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
            .alert(
                sweepTitle,
                isPresented: Binding(present: $sweep),
                presenting: sweep,
                actions: { players in
                    Button("Delete", role: .destructive) { performSweep(players) }
                    Button("Cancel", role: .cancel) {}
                },
                message: { players in Text(Self.sweepMessage(players)) }
            )
            .toolbar { toolbarContent(orphans: orphans) }
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
                Self.logger.error("Show in Library: no Player row for key '\(key, privacy: .public)'")
                return
            }
            onShowInLibrary(player.persistentModelID)
        } catch {
            Self.logger.error("Show in Library lookup failed: \(error.localizedDescription, privacy: .public)")
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

    // `merge(key:into:)` and `beginMerge` lived here from M5 until D52′
    // (4 Aug 2026). The id→model tombstone lesson their picker carried is
    // not lost — the standing invariant records it, and the sweep below is
    // its remaining exemplar in this file.

    /// Deletes the confirmed snapshot. The door skips any row that gained a
    /// link since the alert was raised, so this reports what actually went
    /// rather than what was offered.
    private func performSweep(_ players: [Player]) {
        do {
            let deleted = try PGNStore(modelContext: modelContext)
                .deleteOrphanedPlayers(players)
            Self.logger.info("Swept \(deleted) unused player row(s)")
        } catch {
            Self.logger.error("Sweep failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // `present(_:)` and `refusalMessage(_:)` moved to `GetInfoWindow` with the
    // rename they served (M10). Both are unchanged there, including the
    // exhaustive switch whose point is that a future third `RetagRejection`
    // case arrives as a compile error rather than a swallowed refusal.

    /// Singular and plural spelled out rather than an interpolated "s": the
    /// count reaching 1 is the common case here, not the edge one.
    private var sweepTitle: String {
        let count = sweep?.count ?? 0
        return count == 1 ? "Delete 1 Unused Player?" : "Delete \(count) Unused Players?"
    }

    /// Names them, because an orphan appears in no *view mode* — the three
    /// collection destinations fold `GameRecord`s, whose sides are resolved
    /// links — so a bare count would ask the user to approve deleting rows the
    /// list they are standing in cannot show. Capped like the refusal's list,
    /// for the same reason.
    ///
    /// **Correction.** This comment used to claim the alert was the *only*
    /// place an orphaned player is ever rendered, and D40′ says so too. It is
    /// false. Counted rather than asserted — and recounted when D52′ removed
    /// `MergePlayerSheet`'s query: **three** `@Query`s stand over the registry
    /// — this destination's, `NewLiveGameSheet`'s, and `ContentView`'s. One
    /// *renders* an unfiltered list, so an orphan has always been offered in
    /// the New Game seat menu. `ContentView`'s is an id → model hop that shows
    /// nothing, and this destination's is filtered to orphans by definition.
    ///
    /// The claim that survives is the narrower one the invariants list already
    /// makes — orphans are unreachable through *selection*. Worth keeping the
    /// correction visible rather than silently rewriting the sentence: "the
    /// only place X happens" is a claim about a set, and this one was never
    /// counted.
    ///
    /// The seat-menu pollution is also most of the practical argument for the
    /// deletion cascade in `PGNStore.delete(_ pgns:)`, which is what stops new
    /// orphans reaching either picker.
    private static func sweepMessage(_ players: [Player]) -> String {
        let shown = players.prefix(5).map(\.name)
        let more = players.count > shown.count ? " And \(players.count - shown.count) more." : ""
        return "These players are in no games: " + shown.joined(separator: ", ") + "."
        + more
        + " Removing them changes no game and no export; they return by name if a game of theirs is ever imported again."
    }

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
                                    onShowInLibrary: showInLibrary)
                case .columns:
                    // Flat list + detail since the Finder-column redesign
                    // (2 Aug 2026): the list follows `players`' display
                    // order, so the Sort picker drives it directly and the
                    // grouping vocabulary D48′ chose here went with the
                    // grid it navigated. The detail feeds on the same
                    // `selectedGames` the inspector receives.
                    PlayersColumnsView(players: players,
                                       selectedKeys: $selectedKeys,
                                       recentGames: selectedGames,
                                       onShowInLibrary: showInLibrary)
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
    private func toolbarContent(orphans: [Player]) -> some ToolbarContent {
        ToolbarItem {
            // D48′'s one new control: rank order is the default read, name
            // order is for finding someone. A menu picker rather than a
            // second segmented pair — two segmented controls side by side
            // read as one broken one.
            Picker("Sort", selection: $sortOrder) {
                ForEach(PlayersSortOrder.allCases) { order in
                    Text(order.displayName).tag(order)
                }
            }
            .pickerStyle(.menu)
            .help("Order players by rank or by name")
            .accessibilityIdentifier(AccessibilityID.playersSortPicker)
        }
        ToolbarItem {
            // D40′'s surface, and the only affordance in the app that can reach
            // an orphaned player. Before the spacer: it acts on content, so it
            // belongs on the content side of the break.
            //
            // A menu rather than a bare button because the item opens a
            // confirmation rather than acting, and because registry maintenance
            // is a family with room to grow. Disabled rather than hidden, so
            // "are there any?" is answerable without the control appearing and
            // vanishing under the pointer.
            Menu {
                Button("Delete Unused Players…") { sweep = orphans }
                    .disabled(orphans.isEmpty)
                    .accessibilityIdentifier(AccessibilityID.playersSweepOrphansItem)
            } label: {
                Label("Maintenance", systemImage: "ellipsis.circle")
            }
            .help(orphans.isEmpty
                  ? "No unused players"
                  : "\(orphans.count) unused player row(s) can be removed")
            .accessibilityIdentifier(AccessibilityID.playersMaintenanceMenu)
        }
        ToolbarSpacer()
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
            Self.logger.error("Player-link backfill failed: \(error.localizedDescription, privacy: .public)")
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
