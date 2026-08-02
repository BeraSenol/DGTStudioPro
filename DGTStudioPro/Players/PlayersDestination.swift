//
//  PlayersDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

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

    @State private var selectedKey: PlayerStats.ID?

    // MARK: Player Editing (M5 — D37′, D38′, D39′)

    /// The two editors, mutually exclusive by construction — `activeEditor`'s
    /// shape from D18′. One optional rather than two booleans, so "rename and
    /// merge are both open" is unrepresentable rather than merely unlikely.
    @State private var editor: PlayerEditor?

    /// D39′'s refusal, held for the alert. Nil is the normal state; a value
    /// means the last retag was refused whole and nothing was written.
    @State private var refusal: RetagRefusal?

    /// D40′'s sweep, held between offer and confirmation — the same optional-
    /// array shape as the Library's `pendingBatchDeletion`. It is a *snapshot*
    /// of rows, which is why the store door re-checks each one before deleting:
    /// a player listed here can pick up a link before the alert is answered.
    @State private var sweep: [Player]?

    /// Which sheet is up, and for whom. Carries the stats key rather than a
    /// `Player`: the destination's currency is the pure key everywhere else
    /// (D10′), and resolving to a row at action time is the same bridge
    /// `showInLibrary` already uses.
    private enum PlayerEditor: Identifiable {
        case rename(key: String, tag: String, gameCount: Int)
        case merge(key: String, name: String, gameCount: Int)

        var id: String {
            switch self {
            case .rename(let key, _, _): return "rename:\(key)"
            case .merge(let key, _, _):  return "merge:\(key)"
            }
        }
    }

    /// A refused retag, rendered as an alert.
    ///
    /// Holds the store's `Sendable` collision payload — identifiers and names,
    /// never models — so the alert can name the games without resolving
    /// anything. `Identifiable` off the first collision's game identifier: a
    /// refusal is always about at least one pair.
    private struct RetagRefusal: Identifiable {
        let collisions: [PGNStore.HashCollision]
        var id: PersistentIdentifier { collisions[0].gameID }
    }
    
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
    private var selectedGames: [PGN] {
        guard let selectedKey else { return [] }
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
        let selected = selectedKey.flatMap { key in ranked.first { $0.id == key } }
        let history = selectedKey.flatMap { histories[$0] } ?? []

        // The store owns the rule, the query owns the rows (D40′).
        let orphans = registry.filter(PGNStore.isOrphaned)

        return coreContent(players: displayed)
            .navigationTitle("Players")
            .inspector(isPresented: $tabState.playersInspectorPresented) {
                PlayersInspectorView(
                    ranked: selected,
                    history: history,
                    recentGames: selectedGames,
                    onRename: { beginRename(stats: selected?.stats) },
                    onMerge: { beginMerge(stats: selected?.stats) }
                )
                .inspectorColumnWidth(min: 320, ideal: 325, max: 430)
            }
            .sheet(item: $editor) { editor in
                switch editor {
                case .rename(let key, let tag, let count):
                    RenamePlayerSheet(currentTag: tag, gameCount: count) { newTag in
                        rename(key: key, to: newTag)
                    }
                case .merge(let key, let name, let count):
                    MergePlayerSheet(
                        losingName: name,
                        losingKey: key,
                        gameCount: count
                    ) { survivorID in
                        merge(key: key, into: survivorID)
                    }
                }
            }
            .alert(
                "Can’t Rename",
                isPresented: Binding(present: $refusal),
                presenting: refusal,
                actions: { _ in Button("OK", role: .cancel) {} },
                message: { refusal in Text(Self.refusalMessage(refusal.collisions)) }
            )
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
            .onAppear {
                // Players must work even if Library was never visited this
                // launch — the backfill is store-owned; this is just the
                // second call site (see `PGNStore.backfillPlayerLinks`).
                backfillPlayerLinks()
                if viewMode == .gallery { tabState.playersInspectorPresented = true }
            }
            .onChange(of: viewMode) { _, mode in
                if mode == .gallery { tabState.playersInspectorPresented = true }
            }
    }
    
    // MARK: Instance Methods
    
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

    /// Opens the rename sheet seeded with the player's stored **tag** form —
    /// `tagName ?? name`, the seat picker's fallback (D29′) for a pre-schema
    /// row. Seeding with `name` instead would put a display form in a field
    /// that stores a tag, and the first Save would write "Bera Şenol" into
    /// every affected game's `[White]`.
    private func beginRename(stats: PlayerStats?) {
        guard let stats, let player = resolvedPlayer(for: stats.key) else { return }
        editor = .rename(
            key: stats.key,
            tag: player.tagName ?? player.name,
            gameCount: player.whiteGames.count + player.blackGames.count
        )
    }

    private func beginMerge(stats: PlayerStats?) {
        guard let stats, let player = resolvedPlayer(for: stats.key) else { return }
        editor = .merge(
            key: stats.key,
            name: player.name,
            gameCount: player.whiteGames.count + player.blackGames.count
        )
    }

    /// D37′. Every consequence — the rewrite across linked games, the
    /// re-resolve, the rehash, D39′'s refusal — belongs to the store door;
    /// this is transport plus the two failure sinks, which are deliberately
    /// different: a refusal is a *value* the user must see, a save failure is
    /// a logged error, exactly the split `applyMovetextEdit` draws.
    private func rename(key: String, to newTag: String) {
        guard let player = resolvedPlayer(for: key) else { return }
        do {
            try PGNStore(modelContext: modelContext).retag(player, to: newTag)
            // The stats key is derived from the name, so the old selection now
            // points at a player that no longer exists under that key.
            selectedKey = Player.normalizedKey(for: PlayerName.displayForm(of: newTag))
        } catch let rejection as PGNStore.RetagRejection {
            present(rejection)
        } catch {
            Self.logger.error("Rename failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// D38′. Merge is the same door, so it inherits the same refusal.
    private func merge(key: String, into survivorID: PersistentIdentifier) {
        // The cast is paired with an `isDeleted` check, per the standing
        // id→model rule: the sheet's picker was built from a `@Query` snapshot,
        // and a row deleted between presentation and Merge resolves to a
        // tombstone that would otherwise be merged *into*.
        guard let loser = resolvedPlayer(for: key),
              let survivor = modelContext.model(for: survivorID) as? Player,
              !survivor.isDeleted else { return }
        do {
            try PGNStore(modelContext: modelContext).merge(loser, into: survivor)
            selectedKey = survivor.normalizedName
        } catch let rejection as PGNStore.RetagRejection {
            present(rejection)
        } catch {
            Self.logger.error("Merge failed: \(error.localizedDescription, privacy: .public)")
        }
    }

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

    /// The key→row bridge, `showInLibrary`'s route: store-owned, never
    /// creates (D9′). A miss is impossible for a key the stats index emitted,
    /// so it logs and the caller no-ops.
    private func resolvedPlayer(for key: PlayerStats.ID) -> Player? {
        do {
            guard let player = try PGNStore(modelContext: modelContext)
                .player(withNormalizedKey: key) else {
                Self.logger.error("No Player row for key '\(key, privacy: .public)'")
                return nil
            }
            return player
        } catch {
            Self.logger.error("Player lookup failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// `.emptyTag` never reaches here — both sheets disable their primary
    /// button for it — so the alert is D39′'s collision case only. A future
    /// third rejection arrives as a compile error in this switch rather than
    /// as a silently swallowed refusal.
    private func present(_ rejection: PGNStore.RetagRejection) {
        switch rejection {
        case .wouldCollide(let collisions):
            refusal = RetagRefusal(collisions: collisions)
        case .emptyTag:
            Self.logger.error("Retag refused for an empty tag — the sheet's guard let one through")
        }
    }

    /// Names the games, because "this would create a duplicate" is
    /// unactionable otherwise. Caps the list: a merge of two large
    /// double-imported sets could collide dozens of times, and an alert is
    /// not a report.
    private static func refusalMessage(_ collisions: [PGNStore.HashCollision]) -> String {
        let shown = collisions.prefix(3).map { "“\($0.gameName)” and “\($0.existingName)”" }
        let lead = "This would make these games identical: " + shown.joined(separator: "; ") + "."
        let more = collisions.count > shown.count
            ? " And \(collisions.count - shown.count) more."
            : ""
        return lead + more + " Delete or edit one of each pair first — nothing has been changed."
    }

    /// Singular and plural spelled out rather than an interpolated "s": the
    /// count reaching 1 is the common case here, not the edge one.
    private var sweepTitle: String {
        let count = sweep?.count ?? 0
        return count == 1 ? "Delete 1 Unused Player?" : "Delete \(count) Unused Players?"
    }

    /// Names them, because this alert is the **only** place an orphaned player
    /// is ever rendered (D40′): they appear in no view mode, so a bare count
    /// would ask the user to approve deleting things they have never seen.
    /// Capped like the refusal's list, for the same reason.
    private static func sweepMessage(_ players: [Player]) -> String {
        let shown = players.prefix(5).map(\.name)
        let more = players.count > shown.count ? " And \(players.count - shown.count) more." : ""
        return "These players are in no games: " + shown.joined(separator: ", ") + "."
             + more
             + " Removing them changes no game and no export; they return by name if a game of theirs is ever imported again."
    }

    @ViewBuilder
    private func coreContent(players: [RankedPlayer]) -> some View {
        Group {
            if players.isEmpty {
                emptyState
            } else {
                switch viewMode {
                case .icons:
                    PlayersIconsView(players: players, selectedKey: $selectedKey,
                                     onShowInLibrary: showInLibrary)
                case .list:
                    PlayersListView(players: players, selectedKey: $selectedKey,
                                    onShowInLibrary: showInLibrary)
                case .columns:
                    // Flat list + detail since the Finder-column redesign
                    // (2 Aug 2026): the list follows `players`' display
                    // order, so the Sort picker drives it directly and the
                    // grouping vocabulary D48′ chose here went with the
                    // grid it navigated. The detail feeds on the same
                    // `selectedGames` the inspector receives.
                    PlayersColumnsView(players: players,
                                       selectedKey: $selectedKey,
                                       recentGames: selectedGames,
                                       onShowInLibrary: showInLibrary)
                case .gallery:
                    PlayersGalleryView(players: players, selectedKey: $selectedKey,
                                       onShowInLibrary: showInLibrary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(AccessibilityID.playersContent)
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
            // identifier tags the container; UI tests address segments by
            // SF Symbol name. See DGTStudioProUITests.
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
            identifier: AccessibilityID.playersInspectorToggle
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
