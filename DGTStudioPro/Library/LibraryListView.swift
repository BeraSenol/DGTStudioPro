//
//  LibraryListView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 29/04/2026.
//

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
