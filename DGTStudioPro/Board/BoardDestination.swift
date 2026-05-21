//
//  BoardDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/04/2026.
//

import os
import SwiftData
import SwiftUI

/// Board destination. When `loadedGameID` is non-nil, looks up the
/// PGN, builds a `Game`, and renders the board + inspector. When nil,
/// shows the "Open a Game" landing card.
///
/// `loadedGameID` is bound to the enclosing tab's `WindowGroup` value,
/// so each native tab has its own game (or none). Switching to Library
/// in the sidebar doesn't clear the loaded game — it stays "loaded" in
/// the tab and reappears when the user returns to Board, the same way
/// Safari tabs preserve their loaded URL across navigation.
///
/// Per-tab state (resolved PGN/Game, perspective, inspector visibility)
/// lives on the enclosing `ContentView`'s `TabState`, NOT on this view.
/// This destination is recreated by SwiftUI every time the sidebar
/// switches to and from `.board`; storing live state on `@State` here
/// would lose scrub position, perspective, and inspector toggle on every
/// destination round-trip.
internal struct BoardDestination: View {

    // MARK: Static Constants

    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "boardload"
    )

    // MARK: Bound State

    @Binding internal var loadedGameID: PersistentIdentifier?

    // MARK: Tab State (lives on enclosing `ContentView`)

    @Bindable internal var tabState: TabState

    // MARK: Environment

    @Environment(\.modelContext) private var modelContext
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut

    // MARK: Body

    internal var body: some View {
        Group {
            if let pgn = tabState.boardPGN, let game = tabState.boardGame {
                content(pgn: pgn, game: game)
            } else if let loadError = tabState.boardLoadError {
                errorState(message: loadError)
            } else if loadedGameID == nil {
                landingState
            } else {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(tabState.boardPGN?.name ?? "Board")
        .toolbar {
            ToolbarItem {
                Button {
                    tabState.boardPerspective = tabState.boardPerspective.opponent
                } label: {
                    Label("Flip Board", systemImage: "arrow.up.arrow.down")
                }
                .disabled(tabState.boardGame == nil)
            }
        }
        .inspectorToggle(isPresented: $tabState.boardInspectorPresented)
        .onAppear { loadIfNeeded() }
        .onChange(of: loadedGameID) { _, _ in loadIfNeeded() }
    }

    // MARK: Content

    private func content(pgn: PGN, game: Game) -> some View {
        BoardView(
            position:       game.currentState.position,
            pieceTracker:   game.currentTracker,
            style:          boardStyle,
            perspective:    tabState.boardPerspective,
            lastMove:       game.lastMove,
            checkSquare:    game.checkSquare,
            selectedSquare: nil
        )
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .inspector(isPresented: $tabState.boardInspectorPresented) {
            BoardInspectorView(
                pgn:              pgn,
                evaluations:      pgn.evaluations.map {
                    $0?.whiteWinProbability ?? 0.5
                },
                moves:            pgn.moves,
                currentMoveIndex: game.currentPly > 0
                ? game.currentPly - 1
                : nil,
                style:            boardStyle,
                onMoveTapped:     { index in
                    game.jump(to: index + 1)
                }
            )
            .inspectorColumnWidth(min: 260, ideal: 320, max: 400)
        }
    }

    // MARK: Landing / Error

    private var landingState: some View {
        ContentUnavailableView {
            Label("Open a Game", systemImage: "checkerboard.rectangle")
        } description: {
            Text("Pick a game from your Library to view it. Each opened game appears in its own tab.")
        }
    }

    private func errorState(message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't Open Game", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        }
    }

    // MARK: Loading

    /// Resolves the bound `loadedGameID` to a concrete PGN + Game and
    /// caches the result on `tabState`. No-op when the cached PGN
    /// already matches the ID — important because this is called from
    /// both `onAppear` (every time the Board destination re-enters the
    /// view tree on a sidebar switch) and `onChange(of: loadedGameID)`,
    /// and we don't want to rebuild the `Game` (and lose scrub position)
    /// when the ID hasn't actually changed.
    private func loadIfNeeded() {
        guard let id = loadedGameID else {
            tabState.boardPGN = nil
            tabState.boardGame = nil
            tabState.boardLoadError = nil
            return
        }

        if tabState.boardPGN?.persistentModelID == id, tabState.boardGame != nil {
            return
        }

        guard let loadedPGN = modelContext.model(for: id) as? PGN else {
            tabState.boardPGN = nil
            tabState.boardGame = nil
            tabState.boardLoadError = "The game could not be found in the library."
            return
        }

        do {
            let newGame = try Game(pgn: loadedPGN)
            tabState.boardPGN = loadedPGN
            tabState.boardGame = newGame
            tabState.boardLoadError = nil
        } catch let error as Game.BuildError {
            tabState.boardPGN = nil
            tabState.boardGame = nil
            if case .invalidMove(let index, _, _) = error {
                tabState.boardLoadError = "Move \(index + 1) couldn't be parsed."
            } else {
                tabState.boardLoadError = "The game's move list couldn't be parsed."
            }
        } catch {
            tabState.boardPGN = nil
            tabState.boardGame = nil
            tabState.boardLoadError = "Couldn't open the game: \(error.localizedDescription)"
        }
    }
}

// MARK: - Previews

#Preview {
    BoardDestination(loadedGameID: .constant(nil), tabState: TabState())
        .modelContainer(for: PGN.self, inMemory: true)
}
