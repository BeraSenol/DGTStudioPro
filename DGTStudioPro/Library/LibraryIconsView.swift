//
//  LibraryIconsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 29/04/2026.
//

import SwiftData
import SwiftUI

internal struct LibraryIconsView: View {
    
    // MARK: Stored Properties
    let games: [PGN]
    @Binding var selectedPGNs: Set<PGN.ID>
    let onOpen: (PGN) -> Void
    let onAnalyze: (PGN) -> Void
    let onExport: (PGN) -> Void
    let onDelete: (PGN) -> Void
    
    // MARK: Body
    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: CollectionGridMetrics.columns,
                spacing: CollectionGridMetrics.spacing
            ) {
                ForEach(games) { game in
                    LibraryGameCardView(
                        game: game,
                        isSelected: selectedPGNs.contains(game.id),
                        onSelect:  { selectedPGNs = [game.id] },
                        onOpen:    { onOpen(game) },
                        onAnalyze: { onAnalyze(game) },
                        onExport:  { onExport(game) },
                        onDelete:  { onDelete(game) }
                    )
                }
            }
            .padding(CollectionGridMetrics.inset)
        }
    }
}

// MARK: Previews
private func iconsPreviewGames() -> [PGN] {
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
    
    LibraryIconsView(
        games: iconsPreviewGames(),
        selectedPGNs: $selection,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in }
    )
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PGN.ID> = []
    
    LibraryIconsView(
        games: [],
        selectedPGNs: $selection,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 720, height: 480)
    .modelContainer(for: PGN.self, inMemory: true)
}
