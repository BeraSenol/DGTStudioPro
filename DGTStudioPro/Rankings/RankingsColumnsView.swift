//
//  RankingsColumnsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import SwiftUI

/// The Rankings columns mode: the one POC grouping dimension here is the
/// win band (the ladder's own vocabulary), the Players analogue of the
/// initial letter. Bands are fixed brackets, descending — a ranked list
/// grouped alphabetically would fight its own sort.
internal struct RankingsColumnsView: View {
    
    // MARK: Band
    private struct WinBand: Identifiable, Hashable {
        let id: String
        let players: [RankedPlayer]
        var count: Int { players.count }
        
        static func == (lhs: WinBand, rhs: WinBand) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }
    
    // MARK: Stored Properties
    let players: [RankedPlayer]
    @Binding var selectedKey: PlayerStats.ID?
    let onShowInLibrary: (PlayerStats.ID) -> Void
    
    // MARK: Private Properties
    @State private var selectedBandID: String?
    
    // MARK: Computed Properties
    
    private var bands: [WinBand] {
        // `players` arrives ladder-ordered, so grouping preserves rank
        // order inside each band, and iterating fixed brackets keeps the
        // band list itself descending.
        let brackets: [(id: String, contains: (Int) -> Bool)] = [
            ("10+ wins", { $0 >= 10 }),
            ("5–9 wins", { (5...9).contains($0) }),
            ("1–4 wins", { (1...4).contains($0) }),
            ("No wins",  { $0 == 0 }),
        ]
        return brackets.compactMap { bracket in
            let members = players.filter { bracket.contains($0.stats.wins) }
            guard !members.isEmpty else { return nil }
            return WinBand(id: bracket.id, players: members)
        }
    }
    
    private var selectedBand: WinBand? {
        guard let id = selectedBandID else { return nil }
        return bands.first { $0.id == id }
    }
    
    // MARK: Body
    var body: some View {
        HSplitView {
            bandList
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300, maxHeight: .infinity)
            
            detail
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: Instance Methods
    
    @ViewBuilder
    private var bandList: some View {
        if bands.isEmpty {
            VStack {
                Spacer()
                Text("No players")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            List(selection: $selectedBandID) {
                ForEach(bands) { band in
                    HStack {
                        Label(band.id, systemImage: "trophy")
                            .lineLimit(1)
                        Spacer()
                        Text("\(band.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    .tag(band.id)
                }
            }
            .listStyle(.sidebar)
        }
    }
    
    @ViewBuilder
    private var detail: some View {
        Group {
            if let band = selectedBand {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(band.players) { player in
                            PlayerCardView(
                                stats: player.stats,
                                isSelected: selectedKey == player.id,
                                onSelect: { selectedKey = player.id },
                                rank: player.rank,
                                onShowInLibrary: { onShowInLibrary(player.id) }
                            )
                        }
                    }
                    .padding(16)
                }
            } else {
                ContentUnavailableView(
                    "No Band Selected",
                    systemImage: "square.dashed",
                    description: Text("Select a win band on the left to see its players.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
