import SwiftData
import SwiftUI

struct LibraryGamePreviewView: View {
    
    // MARK: Stored Properties
    
    /// Optional so the no-selection state is *this* view with no game - the two states swap without
    /// the board moving.
    let game: PGN?
    let boardStyle: BoardStyle
    
    @State private var preview: LibraryGamePreviewState?
    
    // MARK: Body
    var body: some View {
        VStack(spacing: 16) {
            header
            board
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: Instance Methods
    
    /// Two lines in both states, and the no-game arm reuses the roster
    /// header's exact typography rather than picking its own - the header's
    /// height is what keeps the board from shifting on selection, so it's
    /// metrics first and copy second.
    @ViewBuilder
    private var header: some View {
        if let game {
            playerHeader(for: game)
        } else {
            Text("No Game Selected")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .foregroundStyle(.tertiary)
        }
    }
    
    private func playerHeader(for game: PGN) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                Text(game.whiteDisplayName)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineLimit(1)
                Text("vs")
                    .foregroundStyle(.secondary)
                    .fontWeight(.light)
                Text(game.blackDisplayName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
            }
            .font(.system(size: 22, weight: .semibold, design: .rounded))
        }
    }
    
    /// The gap between bar and board - this host's own, per `EvaluationBarView`'s standing
    /// decision that the bar states its width and each caller states its gap.
    private static let evaluationBarGap: CGFloat = 10

    private var board: some View {
        // The bar joins the gallery preview (17 Aug 2026, by request) in the Board
        // destination's arrangement: bar column at the far leading edge, an invisible column
        // of identical width trailing, board centred between them. The flanks are reserved
        // **whether or not this game has a bar** - unlike the Board, where the whole branch is
        // conditional - so the board keeps one size as the reader steps through analyzed and
        // unanalyzed games in the filmstrip. A board that resized per selection would be the
        // gallery's own version of the fabricated-bar bug: motion that means nothing.
        GeometryReader { geometry in
            let flank = EvaluationBarView.width + Self.evaluationBarGap
            let side = max(0, min(
                geometry.size.width - 2 * flank,
                geometry.size.height
            ))

            HStack(spacing: 0) {
                Group {
                    // The bar exists iff the game has a scored ply (`hasScoredPly`, not
                    // `!evaluations.isEmpty` - an all-nil array is non-empty and drew a
                    // fabricated 50/50 bar on the Board once).
                    if let game, game.hasScoredPly {
                        EvaluationBarView(
                            // The last *scored* ply, not the last element: a scored game can
                            // end on unscored plies, and `.last` would fold those to an even
                            // bar. This preview shows the final position, so the final score
                            // is the honest reading.
                            reading: EvaluationBarReading(
                                game.evaluations.compactMap { $0 }.last
                            ),
                            perspective: .white,
                            style: boardStyle
                        )
                        .frame(height: side)
                    }
                }
                .frame(width: flank, alignment: .leading)

                BoardView(
                    position: preview?.position ?? .empty,
                    pieces: preview.map {
                        PieceIdentity.resolved(position: $0.position, tracker: $0.pieceTracker)
                    } ?? [],
                    style: boardStyle,
                    perspective: .white,
                    lastMove: preview?.lastMove,
                    checkSquare: preview?.checkSquare
                )
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity)

                // The invisible twin - `Color.clear`, not `Spacer()`: a spacer's width is
                // negotiated, and this must match the bar column to the point.
                Color.clear
                    .frame(width: flank)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // The walk hops off the main actor (`parseSAN` generates every legal move per ply). The
        // cancellation check is load-bearing - `Task.detached` is not auto-cancelled by `.task`'s exit.
        .task(id: game?.moves) {
            guard let moves = game?.moves else {
                preview = nil
                return
            }
            let computed = await Task.detached(priority: .userInitiated) {
                LibraryGamePreviewState.compute(from: moves)
            }.value
            guard !Task.isCancelled else { return }
            preview = computed
        }
    }
}

// MARK: Previews
#Preview("White Wins") {
    LibraryGamePreviewView(
        game: PGN(
            event: "World Championship",
            site: "Dubai",
            white: "Carlsen, Magnus",
            black: "Nepomniachtchi, Ian",
            result: .whiteWins
        ),
        boardStyle: .walnut
    )
    .frame(width: 500, height: 600)
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Draw") {
    LibraryGamePreviewView(
        game: PGN(
            event: "Tata Steel Masters",
            site: "Wijk aan Zee",
            white: "Giri, Anish",
            black: "Caruana, Fabiano",
            result: .draw
        ),
        boardStyle: .rosewood
    )
    .frame(width: 500, height: 600)
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Scholar's Mate") {
    LibraryGamePreviewView(
        game: PGN(
            event: "Quick Game",
            site: "Lichess",
            white: "Beginner",
            black: "Novice",
            moves: ["e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#"],
            result: .whiteWins
        ),
        boardStyle: .walnut
    )
    .frame(width: 500, height: 600)
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("No Selection") {
    LibraryGamePreviewView(game: nil, boardStyle: .walnut)
        .frame(width: 500, height: 600)
}
