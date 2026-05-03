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

    // TODO: replay `game.moves` to render the final position once the SAN
    // parser lands in Phase 7. Until then, show the starting position.
    private var board: some View {
        BoardView(
            position: .starting,
            pieceTracker: .starting,
            style: boardStyle,
            perspective: .white,
            lastMove: nil,
            checkSquare: nil,
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
