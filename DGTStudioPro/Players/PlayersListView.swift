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
    ///
    /// Including the correction recorded there on 5 Aug 2026: this stores
    /// visibility and order, **not width**. Column widths are not restorable in
    /// SwiftUI at all — no way to observe a resize, no way to set one from
    /// code — so a resized column has never survived a relaunch.
    @AppStorage(StorageKeys.playersColumns)
    private var columnCustomization = TableColumnCustomization<RankedPlayer>()

    /// Click once to sort ascending, twice to reverse — the Library's twin, and
    /// see its doc for why this is a binding rather than local state.
    ///
    /// **This is what replaced the D48′ sort picker**, and the substitution is
    /// exact rather than approximate: the picker's two positions were "by rank"
    /// and "by name", which are now the Rank and Player columns. What it gains
    /// is the other seven columns, which the picker could never have offered
    /// without becoming a menu of nine. What it costs is persistence — the
    /// picker's choice survived a relaunch and this does not — and the default
    /// is therefore stated in code (`.rank`, ascending) instead of in
    /// `UserDefaults`, which is strictly better: there is now exactly one place
    /// that says what order Players opens in.
    @Binding var sortOrder: [KeyPathComparator<RankedPlayer>]

    var body: some View {
        Table(players,
              selection: $selectedKeys,
              sortOrder: $sortOrder,
              columnCustomization: $columnCustomization) {
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
            // Ascending rank IS the D11′ ladder, and that equivalence is what
            // let the picker go: `rank` was assigned by folding
            // `PlayerStats.rankingOrder` before this view ever saw the row, so
            // sorting by the badge number reproduces wins-then-win-rate-then-key
            // exactly, without this table needing to know that comparator
            // exists. Pinned by `defaultSortReproducesTheLadder`, because the
            // equivalence is the contract and it is not visible from here.
            TableColumn("Rank", value: \.rank) { player in
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
            // `stats.name` is the display form (D23′), which is what the cell
            // prints — the Library's White column makes the same call for the
            // same reason. Note this is NOT `stats.key`: the key is the folded,
            // lowercased identity and sorting by it would put "de Firmian"
            // somewhere a reader scanning capitals would not look.
            TableColumn("Player", value: \.stats.name) { player in
                Text(player.stats.name)
                    .accessibilityIdentifier(AccessibilityID.playerRow(player.stats.name))
            }
            .customizationID("player")
            TableColumn("Games", value: \.stats.games) { player in
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
            // These four ascend on the first click like every other column, so
            // one click on Wins shows the *fewest* wins first. That reads
            // backwards for a scoreboard and is kept anyway: uniformity is the
            // feature — a table where some headers start descending because
            // someone judged them "achievement-like" is a table you have to
            // learn. Finder and Mail both do it this way, and the second click
            // is right there.
            TableColumn("Wins", value: \.stats.wins) { Text("\($0.stats.wins)") }
                .width(60)
                .customizationID("wins")
            TableColumn("Draws", value: \.stats.draws) {
                Text("\($0.stats.draws)").foregroundStyle(.secondary)
            }
            .width(60)
            .customizationID("draws")
            TableColumn("Losses", value: \.stats.losses) {
                Text("\($0.stats.losses)").foregroundStyle(.secondary)
            }
            .width(60)
            .customizationID("losses")
            // The underlying `Double`, not the rendered percent string: the cell
            // rounds to whole percent, so three players at 66.4%, 66.5% and
            // 66.6% all print "66%" and sorting the text would order them
            // arbitrarily while looking like a tie. Sorting the value keeps the
            // order true and lets the display stay rounded.
            TableColumn("Win %", value: \.stats.winRate) { player in
                Text(player.stats.winRate.formatted(.percent.precision(.fractionLength(0))))
                    .foregroundStyle(.secondary)
            }
            .width(60)
            .customizationID("winRate")
            // `rating?.mean`, so unrated players sort together at one end rather
            // than by the em dash's position in a string sort. The provisional
            // marker is display only and deliberately not part of the key: a
            // provisional 1700 is still a 1700, and D11′ already treats the
            // deviation as a separate fact rather than a discount on the mean.
            TableColumn("Rating", sortUsing: KeyPathComparator(\RankedPlayer.rating?.mean)) { player in
                Text(player.rating?.displaySummary ?? RosterSummary.displayUnknown)
                    .foregroundStyle(.secondary)
            }
            .width(120)
            .customizationID("rating")
            TableColumn("Last Played", value: \.stats.lastPlayed) { player in
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
    @Previewable @State var sort = PlayersDestination.defaultSortOrder

    PlayersListView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        onShowInLibrary: { _ in },
        sortOrder: $sort
    )
    .frame(width: 720, height: 320)
    // Never `.standard` — see `LibraryListView`'s previews.
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}

#Preview("Selected Row") {
    @Previewable @State var selection: Set<PlayerStats.ID> = [PreviewFixtures.topStats().id]
    @Previewable @State var sort = PlayersDestination.defaultSortOrder

    PlayersListView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        onShowInLibrary: { _ in },
        sortOrder: $sort
    )
    .frame(width: 720, height: 320)
    // Never `.standard` — see `LibraryListView`'s previews.
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PlayerStats.ID> = []
    @Previewable @State var sort = PlayersDestination.defaultSortOrder

    PlayersListView(
        players: [],
        selectedKeys: $selection,
        onShowInLibrary: { _ in },
        sortOrder: $sort
    )
        .frame(width: 720, height: 320)
        // Never `.standard` — see `LibraryListView`'s previews.
        .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}
