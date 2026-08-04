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
            // Rank and Player were both pinned visible until 5 Aug 2026, each
            // carrying an identifier no other cell can serve — `rankingRow`
            // pins the computed ladder order, `playerRow` addresses rows for
            // the rename and sweep flows — on the reasoning that a hidden
            // column's element does not exist, so a suite would report the
            // players missing rather than the column.
            //
            // **Unpinned with the Library's White column, under the
            // collection-destination parity invariant and for its reason**: the
            // suite those identifiers served was deleted by D51′, so what
            // remained was a live restriction paid for a consumer that does not
            // exist. Keeping the identifiers costs nothing and is the
            // registry's stated bet; pinning a column is a different trade, and
            // D51′ already ruled on that class.
            //
            // **This entry predicted its own ending, which is why it is worth
            // keeping rather than replacing.** It said: "Rank is the one that
            // costs something real — with D48′'s name ordering, a column of
            // ranks in alphabetical order is exactly the thing a reader would
            // want gone, and it is the one column that cannot go. Recorded
            // rather than quietly pinned, because if that want ever bites…"
            // The want bit, from the Library side first. What the note got
            // wrong was only the remedy: it expected to move `rankingRow` to
            // another cell, and the actual answer was that no cell is a
            // guaranteed address once any column can be hidden — so the pin
            // goes and the identifier stays where it is.
            TableColumn("Rank") { player in
                // The rank cell carries the order-pinning identifier
                // (`rankingRow.1.Liren Ding`) — minted so the ladder UITest
                // could assert the computed order without geometry queries,
                // kept per the registry's bet (D51′). The Player cell keeps
                // `playerRow(name)` from the rename/merge flows. Two cells,
                // two currencies — one element can't serve both.
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
            TableColumn("Player") { player in
                Text(player.stats.name)
                    .accessibilityIdentifier(AccessibilityID.playerRow(player.stats.name))
            }
            .customizationID("player")
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
                Text(player.rating?.displaySummary ?? RosterSummary.displayUnknown)
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
        // Single-subject even though the selection type is a set: both verbs
        // describe one player, so this reads the first key rather than
        // pretending a multi-selection means something here. The menu's own
        // shape lives in `PlayerActionsMenu`.
        .contextMenu(forSelectionType: PlayerStats.ID.self) { keys in
            if let key = keys.first {
                PlayerActionsMenu(key: key, onShowInLibrary: onShowInLibrary)
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
