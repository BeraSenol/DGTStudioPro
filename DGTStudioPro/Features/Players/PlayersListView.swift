import Foundation
import SwiftUI

struct PlayersListView: View {

    let players: [RankedPlayer]
    /// A set (the Library's selection model): `Table` gives ⌘/⇧-click for free.
    @Binding var selectedKeys: Set<PlayerStats.ID>
    let onShowInLibrary: (PlayerStats.ID) -> Void

    /// Header menu state — visibility and order, **not width** (not restorable in code). See
    /// `LibraryListView`'s twin; customization IDs are a persistence contract.
    @AppStorage(StorageKeys.playersColumns)
    private var columnCustomization = TableColumnCustomization<RankedPlayer>()

    /// The Library's twin (see its doc for binding-not-state). Replaced the sort picker —
    /// the picker's two positions were the Rank and Player columns spelled a second way.
    @Binding var sortOrder: [KeyPathComparator<RankedPlayer>]

    var body: some View {
        Table(players,
              selection: $selectedKeys,
              sortOrder: $sortOrder,
              columnCustomization: $columnCustomization) {
            // Rank and Player were pinned visible until the bet came due — unpinned with the Library's
            // White column: a live restriction paid for a suite already deleted. Rank arrives computed
            // through `PlayerStats.rankingOrder`, so sorting by badge number reproduces the ladder.
            TableColumn("Rank", value: \.rank) { player in
                // The rank cell carries the order-pinning identifier (`rankingRow.1.…`), kept per the
                // registry's bet; the Player cell keeps `playerRow`. Medal colours survive via
                // `RankMedal.tableStyle` — same podium colours, `.secondary` below.
                Text("#\(player.rank)")
                    .monospacedDigit()
                    .foregroundStyle(RankMedal.tableStyle(forRank: player.rank))
                    .accessibilityIdentifier(
                        AccessibilityID.rankingRow(player.rank, player.stats.name)
                    )
            }
            .width(52)
            .customizationID("rank")
            // `stats.name` is the display form — what the cell prints. NOT `stats.key`: sorting the
            // folded identity would put "de Firmian" where no reader scanning capitals looks.
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
            // Spelled out rather than W/D/L — initials are only legible next to each other. Customization
            // IDs deliberately do not follow the titles: stored state.
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
            // The underlying `Double`, not the rendered percent: three players printing "66%" would sort
            // arbitrarily while looking like a tie.
            TableColumn("Win %", value: \.stats.winRate) { player in
                Text(player.stats.winRate.formatted(.percent.precision(.fractionLength(0))))
                    .foregroundStyle(.secondary)
            }
            .width(60)
            .customizationID("winRate")
            // `rating?.mean`, so unrated players group at one end; the provisional marker is display only
            // (a provisional 1700 is still a 1700). Special Mates counts motif mates — and can exceed
            // Mates while the two `#` spellings disagree (standing open item, pinned).
            TableColumn("Special Mates", value: \.stats.specialMatesDelivered) { player in
                Text("\(player.stats.specialMatesDelivered)").foregroundStyle(.secondary)
            }
            .width(min: 84, ideal: 96)
            .customizationID("specialMates")
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
        // Single-subject even though the selection is a set: both verbs describe one player.
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
