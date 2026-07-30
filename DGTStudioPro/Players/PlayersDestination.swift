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
                    recentGames: selectedGames
                )
                .inspectorColumnWidth(min: 325, ideal: 320, max: 430)
            }
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
