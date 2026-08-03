//
//  PlayersListView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import Foundation
import SwiftUI

internal struct PlayersListView: View {

    let players: [RankedPlayer]
    /// A set since 2 Aug 2026 (the Library's selection model, adopted):
    /// `Table` gives ⌘/⇧-click multi-select for free once the binding
    /// allows it.
    @Binding var selectedKeys: Set<PlayerStats.ID>
    let onShowInLibrary: (PlayerStats.ID) -> Void

    /// The header menu's state — see `LibraryListView`'s twin for why this is
    /// `@AppStorage` where D45′'s collapse state is an owning type, and why
    /// the customization IDs below are a persistence contract rather than
    /// incidental strings.
    @AppStorage(StorageKeys.playersColumns)
    private var columnCustomization = TableColumnCustomization<RankedPlayer>()

    var body: some View {
        Table(players, selection: $selectedKeys, columnCustomization: $columnCustomization) {
            // Rank and Player are both never hideable, and for the same reason
            // with two different costs. Each carries an accessibility
            // identifier no other cell can serve — `rankingRow` pins the
            // computed ladder order, `playerRow` addresses rows for the
            // rename, merge and sweep flows — and a hidden column's element
            // does not exist, so the tests would report the players missing
            // rather than the column.
            //
            // Rank is the one that costs something real: with D48′'s name
            // ordering, a column of ranks in alphabetical order is exactly the
            // thing a reader would want gone, and it is the one column that
            // cannot go. Recorded rather than quietly pinned, because if that
            // want ever bites, the answer is to move `rankingRow` off this
            // cell — a breaking accessibility change that should travel alone.
            TableColumn("Rank") { player in
                // The rank cell carries the order-pinning identifier
                // (`rankingRow.1.Liren Ding`) so the ladder UITest asserts
                // the computed order without geometry queries; the Player
                // cell keeps `playerRow(name)` for the rename/merge flows.
                // Two cells, two currencies — one element can't serve both.
                Group {
                    if RankMedal(rank: player.rank) != nil {
                        RankBadge(rank: player.rank)
                    } else {
                        Text("\(player.rank)").monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier(
                    AccessibilityID.rankingRow(player.rank, player.stats.name)
                )
            }
            .width(52)
            .customizationID("rank")
            .disabledCustomizationBehavior(.visibility)
            TableColumn("Player") { player in
                Text(player.stats.name)
                    .accessibilityIdentifier(AccessibilityID.playerRow(player.stats.name))
            }
            .customizationID("player")
            .disabledCustomizationBehavior(.visibility)
            TableColumn("Games") { player in
                Text("\(player.stats.games)").foregroundStyle(.secondary)
            }
            .width(60)
            .customizationID("games")
            // Spelled out rather than W/D/L. The initials were only ever
            // legible next to each other — read alone in a header menu, or
            // once a neighbour is hidden, "D" says nothing. The customization
            // IDs deliberately do not follow the titles: they are stored
            // state, and a layout saved under the old headers survives this
            // rename untouched, which is the whole reason they were written by
            // hand instead of derived.
            //
            // 60 pt, matching Games: these four are one family of integer
            // counts and equal widths read as a group. 40 was sized for a
            // single character and truncates "Losses".
            TableColumn("Wins") { Text("\($0.stats.wins)") }
                .width(60)
                .customizationID("wins")
            TableColumn("Draws") { Text("\($0.stats.draws)").foregroundStyle(.secondary) }
                .width(60)
                .customizationID("draws")
            TableColumn("Losses") { Text("\($0.stats.losses)").foregroundStyle(.secondary) }
                .width(60)
                .customizationID("losses")
            TableColumn("Win %") { player in
                Text(player.stats.winRate.formatted(.percent.precision(.fractionLength(0))))
                    .foregroundStyle(.secondary)
            }
            .width(60)
            .customizationID("winRate")
            TableColumn("Rating") { player in
                Text(player.rating?.displaySummary ?? "—")
                    .foregroundStyle(.secondary)
            }
            .width(120)
            .customizationID("rating")
            TableColumn("Last Played") { player in
                Text(RosterSummary.displayDate(player.stats.lastPlayed))
                    .foregroundStyle(.secondary)
            }
            .width(100)
            .customizationID("lastPlayed")
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

// MARK: Previews

#Preview("With Players") {
    @Previewable @State var selection: Set<PlayerStats.ID> = []

    PlayersListView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 320)
    // Never `.standard` — see `LibraryListView`'s previews.
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}

#Preview("Selected Row") {
    @Previewable @State var selection: Set<PlayerStats.ID> = [PreviewFixtures.topStats().id]

    PlayersListView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 320)
    // Never `.standard` — see `LibraryListView`'s previews.
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PlayerStats.ID> = []

    PlayersListView(players: [], selectedKeys: $selection, onShowInLibrary: { _ in })
        .frame(width: 720, height: 320)
        // Never `.standard` — see `LibraryListView`'s previews.
        .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}
