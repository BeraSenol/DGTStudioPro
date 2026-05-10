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
    internal let game: PGN
    internal let boardStyle: BoardStyle

    // MARK: Body
    internal var body: some View {
        VStack(spacing: 16) {
            playerHeader
            board
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Instance Methods
    private var playerHeader: some View {
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
        }
    }

    private var board: some View {
        let preview = LibraryGamePreviewState.compute(from: game.moves)
        return BoardView(
            position: preview.position,
            pieceTracker: preview.pieceTracker,
            style: boardStyle,
            perspective: .white,
            lastMove: preview.lastMove,
            checkSquare: preview.checkSquare,
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
