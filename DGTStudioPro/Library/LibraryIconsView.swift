//
//  LibraryIconsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 29/04/2026.
//

import SwiftUI

import SwiftUI

internal struct LibraryIconsView: View {
    let games: [PGN]
    @Binding var selectedPGNs: Set<PGN.ID>
    let onDelete: (PGN) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)],
                spacing: 16
            ) {
                ForEach(games) { game in
                    LibraryGameCardView(
                        game: game,
                        isSelected: selectedPGNs.contains(game.id),
                        onSelect: { selectedPGNs = [game.id] },
                        onDelete: { onDelete(game) }
                    )
                }
            }
            .padding(16)
        }
    }
}
