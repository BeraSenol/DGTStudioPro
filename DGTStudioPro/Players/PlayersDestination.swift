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

    // MARK: Private Properties
    @AppStorage(StorageKeys.playersViewMode) private var viewMode: CollectionViewMode = .list
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PGN.importedAt, order: .reverse) private var games: [PGN]
    @State private var selectedKey: PlayerStats.ID?

    // MARK: Computed Properties

    private var records: [GameRecord] { games.map(\.gameRecord) }
    private var index: [PlayerStats] { PlayerStats.index(of: records) }

    private var selectedStats: PlayerStats? {
        guard let selectedKey else { return nil }
        return index.first { $0.key == selectedKey }
    }

    private var selectedRating: Glicko1.Rating? {
        guard let selectedKey else { return nil }
        return Glicko1.histories(from: records)[selectedKey]?.last?.rating
    }

    /// The selected player's games, newest first by the one effective-date
    /// rule. Matching goes through the resolved link — never raw tags.
    private var selectedGames: [PGN] {
        guard let selectedKey else { return [] }
        return games
            .filter {
                $0.whitePlayer?.normalizedName == selectedKey
                || $0.blackPlayer?.normalizedName == selectedKey
            }
            .sorted { $0.gameRecord.effectiveDate > $1.gameRecord.effectiveDate }
    }

    // MARK: Body
    internal var body: some View {
        coreContent
            .navigationTitle("Players")
            .toolbar { toolbarContent }
            .inspector(isPresented: $tabState.playersInspectorPresented) {
                PlayersInspectorView(
                    stats: selectedStats,
                    rating: selectedRating,
                    recentGames: selectedGames
                )
                .inspectorColumnWidth(min: 260, ideal: 320, max: 400)
            }
            .inspectorToggle(
                isPresented: $tabState.playersInspectorPresented,
                identifier: AccessibilityID.playersInspectorToggle
            )
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

    @ViewBuilder
    private var coreContent: some View {
        Group {
            if index.isEmpty {
                emptyState
            } else {
                switch viewMode {
                case .icons:
                    PlayersIconsView(players: index, selectedKey: $selectedKey)
                case .list:
                    PlayersListView(players: index, selectedKey: $selectedKey)
                case .columns:
                    PlayersColumnsView(players: index, selectedKey: $selectedKey)
                case .gallery:
                    PlayersGalleryView(players: index, selectedKey: $selectedKey)
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
    }

    private func backfillPlayerLinks() {
        do {
            try PGNStore(modelContext: modelContext).backfillPlayerLinks()
        } catch {
            Self.logger.error("Player-link backfill failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Previews

#Preview {
    PlayersDestination(tabState: TabState())
        .modelContainer(for: PGN.self, inMemory: true)
        .frame(width: 800, height: 500)
}
