//
//  PlayersDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import os
import SwiftData
import SwiftUI

/// The Players destination (M-prs.3): the four `CollectionViewMode`s over
/// `PlayerStats.index`, mirroring the Library's seam — same picker, same
/// per-destination `@AppStorage` key, same gallery-auto-opens-inspector
/// behavior — so the two destinations feel like one app.
///
/// All data is computed per body from the `@Query`: records project via
/// `\.gameRecord`, stats and ratings fold pure (D10′). Recomputing
/// beats caching for the same reason `LibraryColumnsView` documents —
/// the inputs (links, results) can change without the row set changing.
///
/// Selection is a `PlayerStats.ID` (the resolved key), `@State` like the
/// Library's — deliberately not on `TabState`: neither destination
/// promises selection survival across sidebar switches.
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
    @AppStorage(StorageKeys.playersViewMode) private var viewMode: CollectionViewMode = .list
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PGN.importedAt, order: .reverse) private var games: [PGN]
    @State private var selectedKey: PlayerStats.ID?

    // MARK: Player Editing (M5 — D37′, D38′, D39′)

    /// The two editors, mutually exclusive by construction — `activeEditor`'s
    /// shape from D18′. One optional rather than two booleans, so "rename and
    /// merge are both open" is unrepresentable rather than merely unlikely.
    @State private var editor: PlayerEditor?

    /// D39′'s refusal, held for the alert. Nil is the normal state; a value
    /// means the last retag was refused whole and nothing was written.
    @State private var refusal: RetagRefusal?

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
    
    // MARK: Body
    internal var body: some View {
        // Fold once per render, then thread down (see the Derived Data note).
        let records = games.map(\.gameRecord)
        let index = PlayerStats.index(of: records)
        let selectedStats = selectedKey.flatMap { key in index.first { $0.key == key } }
        let selectedRating = selectedKey
            .flatMap { Glicko1.histories(from: records)[$0]?.last?.rating }
        
        return coreContent(index: index)
            .navigationTitle("Players")
            .inspector(isPresented: $tabState.playersInspectorPresented) {
                PlayersInspectorView(
                    stats: selectedStats,
                    rating: selectedRating,
                    recentGames: selectedGames,
                    onRename: { beginRename(stats: selectedStats) },
                    onMerge: { beginMerge(stats: selectedStats) },
                    onDelete: { deleteSelectedPlayer(stats: selectedStats) }
                )
                .inspectorColumnWidth(min: 325, ideal: 320, max: 430)
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
            .toolbar { toolbarContent }
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

    /// The orphan-only delete (D38′). The menu item is already disabled for a
    /// linked player, so a `false` here means the two disagreed — which is
    /// worth a log line rather than a silent no-op.
    private func deleteSelectedPlayer(stats: PlayerStats?) {
        guard let stats, let player = resolvedPlayer(for: stats.key) else { return }
        do {
            if try PGNStore(modelContext: modelContext).deleteOrphanedPlayer(player) {
                selectedKey = nil
            } else {
                Self.logger.error(
                    "Delete offered for linked player '\(player.name, privacy: .public)' — the menu's guard and the door's disagreed"
                )
            }
        } catch {
            Self.logger.error("Delete player failed: \(error.localizedDescription, privacy: .public)")
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

    @ViewBuilder
    private func coreContent(index: [PlayerStats]) -> some View {
        Group {
            if index.isEmpty {
                emptyState
            } else {
                switch viewMode {
                case .icons:
                    PlayersIconsView(players: index, selectedKey: $selectedKey,
                                     onShowInLibrary: showInLibrary)
                case .list:
                    PlayersListView(players: index, selectedKey: $selectedKey,
                                    onShowInLibrary: showInLibrary)
                case .columns:
                    PlayersColumnsView(players: index, selectedKey: $selectedKey,
                                       onShowInLibrary: showInLibrary)
                case .gallery:
                    PlayersGalleryView(players: index, selectedKey: $selectedKey,
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
    /// `ToolbarSpacer` marking the break before the inspector toggle. Stacking
    /// `.inspectorToggle` as a second `.toolbar` modifier left the toolbar
    /// undivided and the inspector column tucked below it — see
    /// `InspectorToggleContent`.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
        ToolbarSpacer()
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
}
