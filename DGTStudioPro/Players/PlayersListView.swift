//
//  PlayersListView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import SwiftUI

internal struct PlayersListView: View {
    
    let players: [PlayerStats]
    @Binding var selectedKey: PlayerStats.ID?
    let onShowInLibrary: (PlayerStats.ID) -> Void

    var body: some View {
        Table(players, selection: $selectedKey) {
            TableColumn("Player") { player in
                Text(player.name)
                    .accessibilityIdentifier(AccessibilityID.playerRow(player.name))
            }
            TableColumn("Games") { player in
                Text("\(player.games)").foregroundStyle(.secondary)
            }
            .width(60)
            TableColumn("W") { Text("\($0.wins)") }.width(40)
            TableColumn("D") { Text("\($0.draws)").foregroundStyle(.secondary) }.width(40)
            TableColumn("L") { Text("\($0.losses)").foregroundStyle(.secondary) }.width(40)
            TableColumn("Win %") { player in
                Text(player.winRate.formatted(.percent.precision(.fractionLength(0))))
                    .foregroundStyle(.secondary)
            }
            .width(60)
            TableColumn("Last Played") { player in
                Text(player.lastPlayed.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
                    .foregroundStyle(.secondary)
            }
            .width(100)
        }
        .contextMenu(forSelectionType: PlayerStats.ID.self) { keys in
            if let key = keys.first {
                Button {
                    onShowInLibrary(key)
                } label: {
                    Label("Show in Library", systemImage: "books.vertical")
                }
                .accessibilityIdentifier(AccessibilityID.contextShowInLibrary)
            }
        }
        .accessibilityIdentifier(AccessibilityID.playersTable)
    }
}
