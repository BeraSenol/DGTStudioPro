//
//  BoardDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/04/2026.
//

import os
import SwiftData
import SwiftUI

/// Board destination. When `loadedGameID` is non-nil, looks up the PGN,
/// builds a `Game`, and renders the board + inspector. When nil, it still
/// shows a board — the live DGT mirror (`connection.physicalBoard`, empty
/// until a board is connected), which is the M1 raw-mirror surface. There
/// is no landing/error card; the board is always on screen.
///
/// The live mirror branch overlays a 50%-opacity ghost rook on
/// `session.castlingGhostSquare` during a mid-castle (king moved, rook not
/// yet). The PGN-replay branch deliberately doesn't — ghost rendering is
/// about the *physical* board vs the live game's state, which is orthogonal
/// to scrubbing a finished PGN.
///
/// `loadedGameID` is bound to the enclosing tab's `WindowGroup` value,
/// so each native tab has its own game (or none). Switching to Library
/// in the sidebar doesn't clear the loaded game — it stays "loaded" in
/// the tab and reappears when the user returns to Board.
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
    @Environment(DGTConnection.self) private var connection
    @Environment(DGTLiveSession.self) private var session
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut

    // MARK: Body

    internal var body: some View {
        Group {
            if let pgn = tabState.boardPGN, let game = tabState.boardGame {
                content(pgn: pgn, game: game)
            } else {
                // No game loaded → still always show a board. It mirrors the
                // physical DGT board live (empty until one is connected),
                // which is also the M1 raw-mirror surface and the surface
                // that carries the castling ghost during live play.
                mirrorBoard
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
                // Enabled even with no game so it serves as the manual
                // orientation toggle for the live mirror (view-only flip,
                // separate from the decoder's coordinate transform).
                .accessibilityIdentifier("board.flipButton")
            }
        }
        .inspectorToggle(
            isPresented: $tabState.boardInspectorPresented,
            identifier: "board.inspectorToggle"
        )
        .dgtConnectionToolbar()
        // Phase 11: publish the active game so GameNavigationCommands' arrow
        // keys can scrub it.
        .focusedSceneValue(\.activeGame, tabState.boardGame)
        .onAppear { loadIfNeeded() }
        .onChange(of: loadedGameID) { _, _ in loadIfNeeded() }
    }

    // MARK: Board Surface

    /// The board itself, shared by the game view and the live mirror. Both
    /// render the same `BoardView` with the same padding, sizing, and
    /// `"board"` accessibility identifier — only the inputs differ. Keeping
    /// this in one place means the identifier and the modifier tail can't
    /// drift between the two branches.
    private func boardSurface(
        position: Position,
        tracker: PieceTracker,
        lastMove: LastMove?,
        checkSquare: Square?,
        ghostSquare: Square?,
        ghostPiece: Piece?
    ) -> some View {
        BoardView(
            position:       position,
            pieceTracker:   tracker,
            style:          boardStyle,
            perspective:    tabState.boardPerspective,
            lastMove:       lastMove,
            checkSquare:    checkSquare,
            selectedSquare: nil,
            ghostSquare:    ghostSquare,
            ghostPiece:     ghostPiece
        )
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("board")
    }

    // MARK: Content

    private func content(pgn: PGN, game: Game) -> some View {
        // PGN-replay path: no ghost. Ghosts only make sense against the
        // live physical board.
        boardSurface(
            position:    game.currentState.position,
            tracker:     game.currentTracker,
            lastMove:    game.lastMove,
            checkSquare: game.checkSquare,
            ghostSquare: nil,
            ghostPiece:  nil
        )
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

    // MARK: Live Mirror

    /// The board shown whenever no game is loaded. Renders the DGT
    /// connection's live `physicalBoard` (empty when nothing is connected),
    /// using an empty `PieceTracker` since the raw mirror has no move history
    /// or piece-identity continuity. The ghost rook is bound to
    /// `DGTLiveSession.castlingGhostSquare/Piece` — non-nil during a
    /// mid-castle, nil otherwise.
    private var mirrorBoard: some View {
        boardSurface(
            position:    connection.physicalBoard,
            tracker:     .empty,
            lastMove:    nil,
            checkSquare: nil,
            ghostSquare: session.castlingGhostSquare,
            ghostPiece:  session.castlingGhostPiece
        )
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
            Self.logger.debug("loadIfNeeded: loadedGameID is nil — clearing")
            tabState.boardPGN = nil
            tabState.boardGame = nil
            tabState.boardLoadError = nil
            return
        }

        if tabState.boardPGN?.persistentModelID == id, tabState.boardGame != nil {
            Self.logger.debug(
                "loadIfNeeded: cache hit for '\(self.tabState.boardPGN?.name ?? "?", privacy: .public)' — no reload"
            )
            return
        }

        Self.logger.debug("loadIfNeeded: resolving id \(String(describing: id), privacy: .public)")

        guard let loadedPGN = modelContext.model(for: id) as? PGN else {
            tabState.boardPGN = nil
            tabState.boardGame = nil
            tabState.boardLoadError = "The game could not be found in the library."
            Self.logger.error(
                "PGN lookup failed for id \(String(describing: id), privacy: .public)"
            )
            return
        }

        do {
            let newGame = try Game(pgn: loadedPGN)
            tabState.boardPGN = loadedPGN
            tabState.boardGame = newGame
            tabState.boardLoadError = nil
            Self.logger.info(
                "Opened game: \(loadedPGN.name, privacy: .public) [\(loadedPGN.moves.count) plies]"
            )
        } catch let error as Game.BuildError {
            tabState.boardPGN = nil
            tabState.boardGame = nil
            if case .invalidMove(let index, let san, let underlying) = error {
                tabState.boardLoadError = "Move \(index + 1) couldn't be parsed."
                Self.logger.error(
                    """
                    Game.init failed for \(loadedPGN.name, privacy: .public): \
                    move \(index + 1) (index \(index)) SAN '\(san, privacy: .public)' \
                    failed with \(String(describing: underlying), privacy: .public). \
                    Prior moves: [\(loadedPGN.moves.prefix(index).joined(separator: " "), privacy: .public)]
                    """
                )
            } else {
                tabState.boardLoadError = "The game's move list couldn't be parsed."
                Self.logger.error(
                    "Game.init failed for \(loadedPGN.name, privacy: .public): \(String(describing: error), privacy: .public)"
                )
            }
        } catch {
            tabState.boardPGN = nil
            tabState.boardGame = nil
            tabState.boardLoadError = "Couldn't open the game: \(error.localizedDescription)"
            Self.logger.error(
                "Game.init failed unexpectedly for \(loadedPGN.name, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

// MARK: - Previews

#Preview {
    BoardDestination(loadedGameID: .constant(nil), tabState: TabState())
        .modelContainer(for: PGN.self, inMemory: true)
        .environment(DGTConnection())
        .environment(DGTLiveSession())
}
