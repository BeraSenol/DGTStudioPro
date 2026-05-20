//
//  BoardDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/04/2026.
//

import SwiftUI
import SwiftData

/// Destination that renders the user's active game (the active tab) on
/// the board, with a tab strip above and the game inspector to the side.
///
/// Per Phase 9's document-model design: this view doesn't *own* the
/// active game — it reads it from `AppState` and reacts. Opening a game
/// from the Library inserts a tab and flips `sidebarSelection` to
/// `.board`, which lands the user here; switching tabs swaps which
/// game's `Game` drives the body. No game open → empty state.
internal struct BoardDestination: View {

    // MARK: Environment

    @Environment(AppState.self) private var appState
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut

    // MARK: Private Properties

    @State private var perspective: PieceColor = .white
    @State private var isInspectorPresented: Bool = true

    // MARK: Body

    internal var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            if !appState.tabs.isEmpty {
                TabBarView(
                    tabs:        appState.tabs,
                    activeTabID: appState.activeTabID,
                    onActivate:  { appState.activate(id: $0) },
                    onClose:     { appState.closeTab(id: $0) }
                )
                Divider()
            }

            content
        }
        .inspector(isPresented: $isInspectorPresented) {
            inspectorContent
                .inspectorColumnWidth(min: 260, ideal: 320, max: 400)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    perspective = perspective.opponent
                } label: {
                    Label("Flip Board", systemImage: "arrow.up.arrow.down")
                }
                .disabled(appState.activeTab == nil)
            }
        }
        .inspectorToggle(isPresented: $isInspectorPresented)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if let tab = appState.activeTab {
            BoardView(
                position:       tab.game.currentState.position,
                pieceTracker:   tab.game.currentTracker,
                style:          boardStyle,
                perspective:    perspective,
                lastMove:       tab.game.lastMove,
                checkSquare:    tab.game.checkSquare,
                selectedSquare: nil
            )
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            emptyState
        }
    }

    @ViewBuilder
    private var inspectorContent: some View {
        if let tab = appState.activeTab {
            BoardInspectorView(
                pgn:              tab.pgn,
                evaluations:      tab.pgn.evaluations.map {
                    $0?.whiteWinProbability ?? 0.5
                },
                moves:            tab.pgn.moves,
                currentMoveIndex: tab.game.currentPly > 0
                ? tab.game.currentPly - 1
                : nil,
                style:            boardStyle,
                onMoveTapped:     { index in
                    // Move-history index `i` corresponds to ply `i + 1`
                    // (the position reached *after* that move was played).
                    tab.game.jump(to: index + 1)
                }
            )
        } else {
            BoardInspectorView(
                pgn:              nil,
                evaluations:      [],
                moves:             [],
                currentMoveIndex: nil,
                style:            boardStyle,
                onMoveTapped:     nil
            )
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Game Open", systemImage: "checkerboard.rectangle")
        } description: {
            Text("Open a game from your library to view it here.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("With Active Tab") {
    let container = try! ModelContainer(
        for: PGN.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let pgn = PGN(
        event: "World Championship",
        site: "Dubai",
        round: 7,
        white: "Carlsen",
        black: "Nepomniachtchi",
        moves: ["e4", "e5", "Nf3", "Nc6", "Bb5"],
        result: .ongoing
    )
    container.mainContext.insert(pgn)

    let appState = AppState()
    _ = appState.openTab(pgn: pgn)

    return NavigationSplitView {
        List { Label("Board", systemImage: "checkerboard.rectangle") }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    } detail: {
        BoardDestination()
    }
    .environment(appState)
    .modelContainer(container)
}

#Preview("Empty") {
    NavigationSplitView {
        List { Label("Board", systemImage: "checkerboard.rectangle") }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    } detail: {
        BoardDestination()
    }
    .environment(AppState())
    .modelContainer(for: PGN.self, inMemory: true)
}
