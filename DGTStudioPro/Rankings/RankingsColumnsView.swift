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
    
    /// The fixed brackets, descending. Ranges rather than closures, which is
    /// what lets the table be a `Sendable` constant built once instead of
    /// four closures allocated per read — and the boundaries read as data.
    private static let brackets: [(id: String, wins: ClosedRange<Int>)] = [
        ("10+ wins", 10...Int.max),
        ("5–9 wins", 5...9),
        ("1–4 wins", 1...4),
        ("No wins",  0...0),
    ]
    
    private var bands: [WinBand] {
        // `players` arrives ladder-ordered, so grouping preserves rank
        // order inside each band, and iterating fixed brackets keeps the
        // band list itself descending.
        Self.brackets.compactMap { bracket in
            let members = players.filter { bracket.wins.contains($0.stats.wins) }
            guard !members.isEmpty else { return nil }
            return WinBand(id: bracket.id, players: members)
        }
    }
    
    private func selectedBand(in bands: [WinBand]) -> WinBand? {
        guard let id = selectedBandID else { return nil }
        return bands.first { $0.id == id }
    }
    
    // MARK: Body
    var body: some View {
        // Group once per render, then thread down — the move
        // `RankingsDestination.ranked(from:histories:)` documents one level
        // up. As a computed property `bands` was read three times a render:
        // the empty check, the `ForEach`, and `selectedBand`.
        let bands = self.bands
        
        return HSplitView {
            bandList(bands)
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300, maxHeight: .infinity)
            
            detail(bands)
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: Instance Methods
    
    @ViewBuilder
    private func bandList(_ bands: [WinBand]) -> some View {
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
    
    private func detail(_ bands: [WinBand]) -> some View {
        Group {
            if let band = selectedBand(in: bands) {
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

// MARK: Previews

/// Opens with no band selected, and can't do otherwise — `selectedBandID` is
/// private `@State`, so a preview has no way to preselect. That is worth
/// seeing rather than working around: it is exactly how the mode presents on
/// every fresh visit, band list on the left and placeholder on the right.
#Preview("Bands") {
    @Previewable @State var selection: PlayerStats.ID?
    
    RankingsColumnsView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKey: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 820, height: 420)
}

/// All four brackets populated. The small fixture reaches only "1–4 wins"
/// and "No wins", so the 5–9 and 10+ boundaries — and the `compactMap` that
/// drops empty bands — are unwitnessed without this one.
#Preview("All Four Bands") {
    @Previewable @State var selection: PlayerStats.ID?
    
    RankingsColumnsView(
        players: PreviewFixtures.deepRankedPlayers(),
        selectedKey: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 820, height: 420)
}

/// Two independent empty states that both have to hold: the band list takes
/// its own "No players" arm rather than rendering an empty `List`, and the
/// detail pane still shows its placeholder.
#Preview("Empty") {
    @Previewable @State var selection: PlayerStats.ID?
    
    RankingsColumnsView(players: [], selectedKey: $selection, onShowInLibrary: { _ in })
        .frame(width: 820, height: 420)
}
