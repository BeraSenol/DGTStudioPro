//
//  PlayersColumnsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import SwiftUI

/// The Players columns mode (absorbed Rankings' in D48′): the
/// `LibraryColumnsView` shape, with the grouping dimension following the
/// destination's sort order. Letters group a name list (the contact-list
/// classic; non-letters bucket under "#"), win bands group a ladder — the
/// retired Rankings view's own argument, "a ranked list grouped
/// alphabetically would fight its own sort", now honoured in both
/// directions by one view instead of two files.
internal struct PlayersColumnsView: View {

    // MARK: Group
    private struct PlayerGroup: Identifiable, Hashable {
        let id: String
        let players: [RankedPlayer]
        var count: Int { players.count }

        static func == (lhs: PlayerGroup, rhs: PlayerGroup) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    // MARK: Stored Properties
    let players: [RankedPlayer]
    /// Which grouping vocabulary applies — the destination passes its sort
    /// order, so the left column always speaks the list's own language.
    let grouping: PlayersSortOrder
    @Binding var selectedKey: PlayerStats.ID?
    let onShowInLibrary: (PlayerStats.ID) -> Void

    // MARK: Private Properties
    @State private var selectedGroupID: String?

    // MARK: Computed Properties

    /// The fixed win brackets, descending. Ranges rather than closures, which
    /// is what lets the table be a `Sendable` constant built once instead of
    /// four closures allocated per read — and the boundaries read as data.
    private static let brackets: [(id: String, wins: ClosedRange<Int>)] = [
        ("10+ wins", 10...Int.max),
        ("5–9 wins", 5...9),
        ("1–4 wins", 1...4),
        ("No wins",  0...0),
    ]

    /// Recomputed per body, the `LibraryColumnsView` rationale: cheap at
    /// personal scale, and immune to contents changing under a cache.
    /// `players` arrives in display order, so grouping preserves it inside
    /// each group either way.
    private var groups: [PlayerGroup] {
        switch grouping {
        case .name:
            let buckets = Dictionary(grouping: players) { player -> String in
                guard let first = player.stats.name.first, first.isLetter else { return "#" }
                return String(first).uppercased()
            }
            return buckets
                .map { PlayerGroup(id: $0.key, players: $0.value) }
                .sorted { $0.id < $1.id }
        case .rank:
            return Self.brackets.compactMap { bracket in
                let members = players.filter { bracket.wins.contains($0.stats.wins) }
                guard !members.isEmpty else { return nil }
                return PlayerGroup(id: bracket.id, players: members)
            }
        }
    }

    private func selectedGroup(in groups: [PlayerGroup]) -> PlayerGroup? {
        guard let id = selectedGroupID else { return nil }
        return groups.first { $0.id == id }
    }

    // MARK: Body
    var body: some View {
        // Group once per render, then thread down — as computed properties
        // this was read three times a render (empty check, ForEach,
        // selection).
        let groups = self.groups

        return HSplitView {
            groupList(groups)
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300, maxHeight: .infinity)

            detail(groups)
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Instance Methods

    @ViewBuilder
    private func groupList(_ groups: [PlayerGroup]) -> some View {
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
                        Label(group.id, systemImage: grouping == .rank ? "trophy" : "person")
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

    private func detail(_ groups: [PlayerGroup]) -> some View {
        Group {
            if let group = selectedGroup(in: groups) {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 160, maximum: 200),
                                          spacing: CollectionGridMetrics.spacing)],
                        spacing: CollectionGridMetrics.spacing
                    ) {
                        ForEach(group.players) { player in
                            PlayerCardView(
                                stats: player.stats,
                                isSelected: selectedKey == player.id,
                                onSelect: { selectedKey = player.id },
                                rank: player.rank,
                                onShowInLibrary: { onShowInLibrary(player.id) }
                            )
                        }
                    }
                    .padding(CollectionGridMetrics.inset)
                }
            } else {
                ContentUnavailableView(
                    "Nothing Selected",
                    systemImage: "square.dashed",
                    description: Text(grouping == .rank
                        ? "Select a win band on the left to see its players."
                        : "Select a letter on the left to see its players.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: Previews

#Preview("By Letter") {
    @Previewable @State var selection: PlayerStats.ID?

    PlayersColumnsView(
        players: PreviewFixtures.rankedPlayers(),
        grouping: .name,
        selectedKey: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 820, height: 420)
}

/// All four brackets populated. The small fixture reaches only "1–4 wins"
/// and "No wins", so the 5–9 and 10+ boundaries — and the `compactMap` that
/// drops empty bands — are unwitnessed without this one.
#Preview("By Win Band — All Four") {
    @Previewable @State var selection: PlayerStats.ID?

    PlayersColumnsView(
        players: PreviewFixtures.deepRankedPlayers(),
        grouping: .rank,
        selectedKey: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 820, height: 420)
}

/// Two independent empty states that both have to hold: the group list takes
/// its own "No players" arm rather than rendering an empty `List`, and the
/// detail pane still shows its placeholder.
#Preview("Empty") {
    @Previewable @State var selection: PlayerStats.ID?

    PlayersColumnsView(players: [], grouping: .rank,
                       selectedKey: $selection, onShowInLibrary: { _ in })
        .frame(width: 820, height: 420)
}
