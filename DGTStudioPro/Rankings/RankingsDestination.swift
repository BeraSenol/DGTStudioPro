//
//  RankingsDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import os
import SwiftData
import SwiftUI

/// One ladder row: a player's rank under `PlayerStats.rankingOrder`
/// (D11′ — wins ↓, win rate ↓, key ↑; ranks are dense and distinct
/// because the comparator is total), with the Glicko rating riding along
/// as the secondary stat. File-scoped here because it's presentation
/// composition — the four Rankings mode views consume it; the tested
/// contracts are the comparator and the fold underneath.
internal struct RankedPlayer: Identifiable, Hashable {
    internal let rank: Int
    internal let stats: PlayerStats
    internal let rating: Glicko1.Rating?
    
    internal var id: PlayerStats.ID { stats.id }
}

/// The Rankings destination (M-prs.4): the Players seam, re-sorted — same
/// four modes, same picker, same gallery-auto-inspector, same computed-
/// per-body data (two pure folds per render; the `LibraryColumnsView`
/// cheap-and-uncacheable rationale applies twice over).
internal struct RankingsDestination: View {
    
    // MARK: Static Constants
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "rankings"
    )
    
    // MARK: Tab State (lives on enclosing `ContentView`)
    @Bindable internal var tabState: TabState
    
    /// The M-prs.6 hop: hands the resolved player's identifier up to
    /// `ContentView`, which owns the sidebar selection. The app always
    /// wires it; the initializer's default keeps previews valid.
    internal let onShowInLibrary: (PersistentIdentifier) -> Void
    
    // MARK: Private Properties
    @AppStorage(StorageKeys.rankingsViewMode) private var viewMode: CollectionViewMode = .list
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
    
    // MARK: Computed Properties
    
    private var records: [GameRecord] { games.map(\.gameRecord) }
    
    private var ranked: [RankedPlayer] {
        let latest = Glicko1.histories(from: records)
        return PlayerStats.index(of: records)
            .sorted(by: PlayerStats.rankingOrder)
            .enumerated()
            .map { offset, stats in
                RankedPlayer(
                    rank: offset + 1,
                    stats: stats,
                    rating: latest[stats.key]?.last?.rating
                )
            }
    }
    
    private var selectedRanked: RankedPlayer? {
        guard let selectedKey else { return nil }
        return ranked.first { $0.id == selectedKey }
    }
    
    private var selectedHistory: [Glicko1.Sample] {
        guard let selectedKey else { return [] }
        return Glicko1.histories(from: records)[selectedKey] ?? []
    }
    
    // MARK: Body
    internal var body: some View {
        coreContent
            .navigationTitle("Rankings")
            .toolbar { toolbarContent }
            .inspector(isPresented: $tabState.rankingsInspectorPresented) {
                RankingsInspectorView(
                    ranked: selectedRanked,
                    history: selectedHistory
                )
                .inspectorColumnWidth(min: 260, ideal: 320, max: 400)
            }
            .inspectorToggle(
                isPresented: $tabState.rankingsInspectorPresented,
                identifier: AccessibilityID.rankingsInspectorToggle
            )
            .onAppear {
                // Third backfill call site — Rankings must work on a
                // launch that never visited Library or Players.
                backfillPlayerLinks()
                if viewMode == .gallery { tabState.rankingsInspectorPresented = true }
            }
            .onChange(of: viewMode) { _, mode in
                if mode == .gallery { tabState.rankingsInspectorPresented = true }
            }
    }
    
    // MARK: Instance Methods
    
    /// Resolves the pure stats key to its `Player` row and hops the
    /// sidebar into the programmatic player filter. Store-owned lookup,
    /// never creates (D13′); a miss — impossible for a key the index
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
    private var coreContent: some View {
        Group {
            if ranked.isEmpty {
                emptyState
            } else {
                switch viewMode {
                case .icons:
                    RankingsIconsView(players: ranked, selectedKey: $selectedKey,
                                      onShowInLibrary: showInLibrary)
                case .list:
                    RankingsListView(players: ranked, selectedKey: $selectedKey,
                                     onShowInLibrary: showInLibrary)
                case .columns:
                    RankingsColumnsView(players: ranked, selectedKey: $selectedKey,
                                        onShowInLibrary: showInLibrary)
                case .gallery:
                    RankingsGalleryView(players: ranked, selectedKey: $selectedKey,
                                        onShowInLibrary: showInLibrary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(AccessibilityID.rankingsContent)
    }
    
    private var emptyState: some View {
        ContentUnavailableView(
            "No Rankings",
            systemImage: "list.number",
            description: Text("Players are ranked here as games with named players are imported or archived.")
        )
        .accessibilityIdentifier(AccessibilityID.rankingsEmptyState)
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            // Same segmented-picker caveat as Library/Players: segments
            // are addressed by SF Symbol in UI tests.
            Picker("View Mode", selection: $viewMode) {
                ForEach(CollectionViewMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(AccessibilityID.rankingsViewModePicker)
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
    RankingsDestination(tabState: TabState())
        .modelContainer(for: PGN.self, inMemory: true)
        .frame(width: 800, height: 500)
}
