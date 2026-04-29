//
//  LibraryIconsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 29/04/2026.
//

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
                    card(for: game)
                }
            }
            .padding(16)
        }
    }
    
    private func card(for game: PGN) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                resultChip(game.result)
                Spacer()
                Text(game.displayDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(game.name)
                .font(.callout)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 4)
            Text(game.event)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(12)
        .libraryGameCard(
            isSelected: selectedPGNs.contains(game.id),
            onSelect: { selectedPGNs = [game.id] },
            onDelete: { onDelete(game) }
        )
    }
}

internal func resultChip(_ result: GameResult) -> some View {
    Text(result.rawValue)
        .font(.caption.monospaced())
        .tracking(1)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.tertiary)
        .foregroundStyle(.secondary)
        .clipShape(Capsule())
}
