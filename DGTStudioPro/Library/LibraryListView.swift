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
    let onDelete: (PGN) -> Void
    
    var body: some View {
        Table(games, selection: $selectedPGNs) {
            TableColumn("White") { Text($0.white) }
            TableColumn("Black") { Text($0.black) }
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
        .contextMenu(forSelectionType: PGN.ID.self) { ids in
            if let id = ids.first, let game = games.first(where: { $0.id == id }) {
                Button(role: .destructive) {
                    onDelete(game)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
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
        onDelete: { _ in }
    )
    .frame(width: 720, height: 360)
    .modelContainer(for: PGN.self, inMemory: true)
}


