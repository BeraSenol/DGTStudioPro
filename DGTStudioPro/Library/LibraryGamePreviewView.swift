//
//  LibraryGamePreviewView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 03/05/2026.
//

import SwiftData
import SwiftUI

internal struct LibraryGamePreviewView: View {

    // MARK: Stored Properties

    /// Optional so the gallery's no-selection state is *this* view with no
    /// game rather than a parallel placeholder struct: the frame, padding,
    /// and header metrics that let the two states swap without the board
    /// jumping are then written once and can't drift. Existing call sites
    /// compile unchanged — a non-optional `PGN` promotes implicitly.
    internal let game: PGN?
    internal let boardStyle: BoardStyle

    // MARK: Body
    internal var body: some View {
        VStack(spacing: 16) {
            header
            board
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Instance Methods

    /// Two lines in both states, and the no-game arm reuses the roster
    /// header's exact typography rather than picking its own — the header's
    /// height is what keeps the board from shifting on selection, so it's
    /// metrics first and copy second.
    @ViewBuilder
    private var header: some View {
        if let game {
            playerHeader(for: game)
        } else {
            VStack(spacing: 6) {
                Text("No Game Selected")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Text("Select a game below")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .tracking(1)
            }
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

            Text(game.result.rawValue)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1)
        }
    }

    /// One `BoardView` for both states — the no-game arm nil-coalesces to
    /// an empty board rather than branching, so the board's construction
    /// can't diverge either. `Position.empty` and not `.starting`: an empty
    /// board reads as "nothing here," a starting position reads as "a game
    /// about to begin," which would be a lie in a Library preview.
    private var board: some View {
        let preview = game.map { LibraryGamePreviewState.compute(from: $0.moves) }
        return BoardView(
            position: preview?.position ?? .empty,
            pieceTracker: preview?.pieceTracker ?? .empty,
            style: boardStyle,
            perspective: .white,
            lastMove: preview?.lastMove,
            checkSquare: preview?.checkSquare,
            selectedSquare: nil
        )
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
