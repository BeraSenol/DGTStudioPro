//
//  LibraryListView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 29/04/2026.
//

import SwiftData
import SwiftUI

internal struct LibraryListView: View {
    let games: [PGN]
    @Binding var selectedPGNs: Set<PGN.ID>
    let onOpen: (PGN) -> Void
    let onDelete: (PGN) -> Void

    var body: some View {
        Table(games, selection: $selectedPGNs) {
            TableColumn("White") { game in
                Text(game.whiteDisplayName)
                    .accessibilityIdentifier("gameRow.\(game.name)")
            }
            TableColumn("Black") { Text($0.blackDisplayName) }
            TableColumn("Result") { game in
                Text(game.result.rawValue).foregroundStyle(.secondary)
            }
            .width(60)
            TableColumn("Event") { Text($0.event).lineLimit(1) }
            TableColumn("Date") { game in
                Text(game.displayDate).foregroundStyle(.secondary)
            }
            .width(100)
            TableColumn("Round") { game in
                Text(game.displayRound).foregroundStyle(.secondary)
            }
            .width(60)
        }
        .accessibilityIdentifier("library.gamesTable")
        .contextMenu(forSelectionType: PGN.ID.self) { ids in
            if let id = ids.first, let game = games.first(where: { $0.id == id }) {
                Button {
                    onOpen(game)
                } label: {
                    Label("Open in Board", systemImage: "checkerboard.rectangle")
                }
                Divider()
                Button(role: .destructive) {
                    onDelete(game)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } primaryAction: { ids in
            // Fires on row double-click *and* on Return when a row is
            // focused — both routes converge here so we don't need a
            // separate `.onSubmit` or key-press handler.
            if let id = ids.first, let game = games.first(where: { $0.id == id }) {
                onOpen(game)
            }
        }
    }
}

// MARK: Previews
private func listPreviewGames() -> [PGN] {
    [
        PGN(event: "World Championship", site: "Dubai", round: 11,
            white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian", result: .whiteWins),
        PGN(event: "Tata Steel Masters", site: "Wijk aan Zee", round: 7,
            white: "Giri, Anish", black: "Caruana, Fabiano", result: .draw),
        PGN(event: "Norway Chess", site: "Stavanger", round: 3,
            white: "Firouzja, Alireza", black: "Ding, Liren", result: .blackWins),
        PGN(event: "Candidates Tournament", site: "Madrid", round: 14,
            white: "Nepomniachtchi, Ian", black: "Ding, Liren", result: .ongoing)
    ]
}

#Preview("With Games") {
    @Previewable @State var selection: Set<PGN.ID> = []

    LibraryListView(
        games: listPreviewGames(),
        selectedPGNs: $selection,
        onOpen: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 720, height: 360)
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PGN.ID> = []

    LibraryListView(
        games: [],
        selectedPGNs: $selection,
        onOpen: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 720, height: 360)
    .modelContainer(for: PGN.self, inMemory: true)
}
