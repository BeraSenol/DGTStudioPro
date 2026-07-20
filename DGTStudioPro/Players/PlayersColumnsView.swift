//
//  PlayersColumnsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import SwiftUI

/// The Players columns mode: the `LibraryColumnsView` shape with one POC
/// grouping dimension — initial letter (D12′-adjacent scope call: the
/// Library earns three dimensions from its richer metadata; a name list
/// earns the contact-list classic). Non-letters bucket under "#".
internal struct PlayersColumnsView: View {
    
    // MARK: Group
    private struct PlayerGroup: Identifiable, Hashable {
        let id: String            // the letter
        let players: [PlayerStats]
        var count: Int { players.count }
    }
    
    // MARK: Stored Properties
    let players: [PlayerStats]
    @Binding var selectedKey: PlayerStats.ID?
    
    // MARK: Private Properties
    @State private var selectedGroupID: String?
    
    // MARK: Computed Properties
    
    /// Recomputed per body, the `LibraryColumnsView` rationale: cheap at
    /// personal scale, and immune to contents changing under a cache.
    private var groups: [PlayerGroup] {
        let buckets = Dictionary(grouping: players) { player -> String in
            guard let first = player.name.first, first.isLetter else { return "#" }
            return String(first).uppercased()
        }
        return buckets
            .map { PlayerGroup(id: $0.key, players: $0.value) }
            .sorted { $0.id < $1.id }
    }
    
    private var selectedGroup: PlayerGroup? {
        guard let id = selectedGroupID else { return nil }
        return groups.first { $0.id == id }
    }
    
    // MARK: Body
    var body: some View {
        HSplitView {
            groupList
                .frame(minWidth: 160, idealWidth: 200, maxWidth: 280, maxHeight: .infinity)
            
            detail
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: Instance Methods
    
    @ViewBuilder
    private var groupList: some View {
        if groups.isEmpty {
            VStack {
                Spacer()
                Text("No players")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            List(selection: $selectedGroupID) {
                ForEach(groups) { group in
                    HStack {
                        Label(group.id, systemImage: "person")
                            .lineLimit(1)
                        Spacer()
                        Text("\(group.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    .tag(group.id)
                }
            }
            .listStyle(.sidebar)
        }
    }
    
    @ViewBuilder
    private var detail: some View {
        Group {
            if let group = selectedGroup {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(group.players) { player in
                            PlayerCardView(
                                stats: player,
                                isSelected: selectedKey == player.key,
                                onSelect: { selectedKey = player.key }
                            )
                        }
                    }
                    .padding(16)
                }
            } else {
                ContentUnavailableView(
                    "No Letter Selected",
                    systemImage: "square.dashed",
                    description: Text("Select a letter on the left to see its players.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
