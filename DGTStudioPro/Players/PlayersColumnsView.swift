//
//  PlayersColumnsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import SwiftData
import SwiftUI

/// The Finder-column shape (2 Aug 2026 redesign, with `LibraryColumnsView`):
/// a flat list of players in the first column, the selected player's detail
/// filling the rest. The list follows `players`' own display order, which
/// since 5 Aug 2026 is set by the **list mode's column sort** (it replaced the
/// toolbar Sort picker this comment used to name). Rows arrive already
/// sequenced whatever that order is, and the rank badge stays honest in all of
/// them because rank is computed under D11′ regardless of display order.
///
/// The one header this mode has sorts by name, sharing the destination's
/// comparator with list mode — so a sort made in either survives the switch to
/// the other. What it cannot do is *display* an ordering it did not set: sort
/// by Rating over in list mode, come back, and this header shows no direction
/// while the rows are in rating order. A one-column table has nowhere to put
/// eight other columns' state, and inventing somewhere would be a second
/// spelling of a sort this destination already has one of.
///
/// Replaces the grouped browser (letter / win-band buckets): the groups were
/// a navigation aid for a card grid, and the grid is gone. The win-band
/// table and the "a ranked list grouped alphabetically would fight its own
/// sort" argument went with it — that argument was about which grouping
/// vocabulary to use, and a flat list uses none.
///
/// The detail pane is the gallery's identity block plus what the extra room
/// buys: the shared `PlayerStatsGrid`, the Show in Library hop, and the
/// player's recent games — the same `recentGames` input the inspector
/// receives, so the two surfaces can't disagree about what "recent" means.
internal struct PlayersColumnsView: View {

    // MARK: Stored Properties
    let players: [RankedPlayer]
    /// A set since 2 Aug 2026 (the shared selection model); the list
    /// multi-selects, and the detail pane counts a plural selection the
    /// way `LibraryColumnsView`'s does.
    @Binding var selectedKeys: Set<PlayerStats.ID>
    /// The selected player's games, newest first — the destination's
    /// `selectedGames`, threaded exactly as `PlayersInspectorView` gets it.
    let recentGames: [PGN]
    let onShowInLibrary: (PlayerStats.ID) -> Void

    /// Shared with list mode through `PlayersDestination` — the Library twin's
    /// arrangement and its reason (5 Aug 2026).
    @Binding var sortOrder: [KeyPathComparator<RankedPlayer>]

    @Environment(\.openWindow) private var openWindow

    // MARK: Computed Properties

    /// Single or nothing — the detail pane details one thing (the
    /// `LibraryColumnsView` rule).
    private var selectedPlayer: RankedPlayer? {
        guard selectedKeys.count == 1, let key = selectedKeys.first else { return nil }
        return players.first { $0.id == key }
    }

    // MARK: Body
    var body: some View {
        HSplitView {
            // Matched to the Library's, per collection-destination parity —
            // see its twin for why the floor came down with the row.
            // See `LibraryColumnsView`'s twin for why the priority is the
            // floor's enforcement rather than decoration.
            playerList
                .frame(minWidth: 160, idealWidth: 200, maxWidth: 300, maxHeight: .infinity)
                .layoutPriority(1)

            detail
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Instance Methods

    /// Two independent empty states that both have to hold, as before the
    /// redesign: the list takes its own "No players" arm rather than
    /// rendering an empty `List` — unreachable in production, where the
    /// destination gates on `players.isEmpty`, but previews build this view
    /// directly — and the detail pane shows its placeholder.
    @ViewBuilder
    private var playerList: some View {
        if players.isEmpty {
            VStack {
                Spacer()
                Text("No players")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            // A one-column `Table`, the Library's twin — see
            // `LibraryColumnsView.gameList` for the full reasoning, including
            // the accepted header cost (shipping SwiftUI on macOS cannot
            // suppress one) and why no `columnCustomization` binding appears
            // here (`PlayersListView` persists its layout under
            // `StorageKeys.playersColumns`; sharing that key would let hiding
            // a column there empty this view).
            // Sortable since 5 Aug 2026, on `LibraryColumnsView`'s reasoning
            // and sharing the destination's comparator with list mode — see
            // the Library twin for the accepted-cost-becomes-feature argument
            // and for why this header cannot display an ordering it did not set.
            Table(players, selection: $selectedKeys, sortOrder: $sortOrder) {
                TableColumn("Player", value: \.stats.name) { player in
                    row(for: player)
                }
                // 160 floor, all three — the Library twin's reasoning applies
                // verbatim: the enclosing frame's floor governs the pane, this
                // governs the column, and `Table` would otherwise let the
                // column be dragged narrower than the pane it sits in. The
                // min-only spelling was tried there and did not hold the floor
                // (4 Aug, observed), which is why `ideal` and `max` are not
                // decoration here either.
                .width(min: 160, ideal: 200, max: .infinity)
            }
            .tableStyle(.inset)
            // Selection-typed, `PlayersListView`'s shape. The menu itself
            // stays single-subject (`PlayerActionsMenu`): both its verbs
            // describe one player, so this reads the first key rather than
            // pretending a multi-selection means something here.
            .contextMenu(forSelectionType: PlayerStats.ID.self) { keys in
                if let key = keys.first {
                    PlayerActionsMenu(key: key, onShowInLibrary: onShowInLibrary)
                }
            }
        }
    }

    /// **Finder's row: one icon, one name, one line** (3 Aug 2026) — the
    /// Library's twin, and the reasoning is at `LibraryColumnsView.row(for:)`.
    ///
    /// Three things left: the 28pt monogram, the game count, and the rank
    /// badge. All three are on the profile in the next column, and the
    /// monogram in particular was doing the opposite of Finder's job — a
    /// per-player coloured disc makes every row look different, where a list
    /// you scan wants every row to look the same so the *names* are what
    /// varies.
    ///
    /// The rank badge is the one worth naming, because losing it is a real
    /// cost rather than pure cleanup: in rank order the list is a ladder, and
    /// the number said where each rung sat. It goes because the position in
    /// the list already says that when sorted by rank, and says something
    /// actively misleading when sorted by name — a "#3" scattered mid-list
    /// reads as a sort that has gone wrong. The table view is where ranks
    /// belong; it has a column for them.
    private func row(for player: RankedPlayer) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "person")
                .foregroundStyle(.tint)
                .imageScale(.medium)
            Text(player.stats.name)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 1)
        // The menu moved to the `Table` as a selection-typed one — see the
        // list above. A per-row `.contextMenu` inside a `Table` cell would
        // shadow it.
    }

    @ViewBuilder
    private var detail: some View {
        if let player = selectedPlayer {
            playerDetail(player)
        } else if selectedKeys.count > 1 {
            // The multi-selection vocabulary every counting surface shares
            // (the Library columns pane, both inspectors' multi states).
            ContentUnavailableView(
                "\(selectedKeys.count) Players Selected",
                systemImage: "person.2.fill",
                description: Text("Select a single player to see their profile.")
            )
        } else {
            ContentUnavailableView(
                "No Player Selected",
                systemImage: "person.crop.circle.dashed",
                description: Text("Select a player in the list to see their profile and recent games.")
            )
        }
    }

    /// A scrolling profile, unlike the Library's fixed facts block: nothing
    /// here fights for aspect ratio the way a board does, and the recent
    /// games list is the part that grows.
    private func playerDetail(_ player: RankedPlayer) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                PlayerMonogram(name: player.stats.name, diameter: 96)

                // The gallery's identity row, kept in both hosts: the rank
                // is the destination's default sort and earns the medal
                // styling beside the name.
                HStack(spacing: 8) {
                    Text("#\(player.rank)")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(RankMedal.style(forRank: player.rank))
                    Text(player.stats.name)
                        .font(.title2.weight(.semibold))
                }

                PlayerStatsGrid(stats: player.stats, rating: player.rating)

                Button {
                    onShowInLibrary(player.id)
                } label: {
                    Label("Show in Library", systemImage: "books.vertical")
                }
                .help("Filter the Library to this player's games")

                Divider()
                    .frame(maxWidth: 420)

                recentGamesBlock
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    /// The inspector's recent-games rules, restated for this host: capped at
    /// ten with an "and N more…" tail, rows open the game via the same
    /// `openWindow(value:)` route (macOS dedups and tabs the windows). Two
    /// hosts' two decisions that agree today — the row is private on each
    /// side deliberately, the `OpeningSection` em-dash precedent, because
    /// one lives in a `List` section and one in a plain stack and a shared
    /// view would have to be generic over that difference.
    private var recentGamesBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Games")
                .font(.headline)

            if recentGames.isEmpty {
                Text("No games")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentGames.prefix(10)) { game in
                    gameRow(for: game)
                }
                if recentGames.count > 10 {
                    Text("and \(recentGames.count - 10) more…")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
    }

    private func gameRow(for game: PGN) -> some View {
        Button {
            openWindow(value: game.persistentModelID)
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.name)
                        .lineLimit(1)
                    Text(game.displayDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(game.result.rawValue)
                    .font(.callout.weight(.semibold).monospaced())
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Previews

#Preview("Selected") {
    @Previewable @State var selection: Set<PlayerStats.ID> = [PreviewFixtures.topStats().id]
    @Previewable @State var sort = PlayersDestination.defaultSortOrder

    PlayersColumnsView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        recentGames: [
            PGN(event: "Test Open", site: "Memory", round: 1,
                white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian", result: .whiteWins),
            PGN(event: "Test Open", site: "Memory", round: 2,
                white: "Nepomniachtchi, Ian", black: "Carlsen, Magnus", result: .draw)
        ],
        onShowInLibrary: { _ in },
        sortOrder: $sort
    )
    .frame(width: 860, height: 520)
    .modelContainer(for: PGN.self, inMemory: true)
}

/// The no-games branch of the detail — a selected player whose recent list
/// is empty renders "No games", not a collapsed void.
#Preview("Selected — No Games") {
    @Previewable @State var selection: Set<PlayerStats.ID> = [PreviewFixtures.topStats().id]
    @Previewable @State var sort = PlayersDestination.defaultSortOrder

    PlayersColumnsView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        recentGames: [],
        onShowInLibrary: { _ in },
        sortOrder: $sort
    )
    .frame(width: 860, height: 520)
    .modelContainer(for: PGN.self, inMemory: true)
}

/// The counting branch — a plural selection in the list, the state the
/// single-select columns could never render.
#Preview("Multi-Selection") {
    @Previewable @State var selection: Set<PlayerStats.ID> = Set(
        PreviewFixtures.rankedPlayers().prefix(2).map(\.id)
    )
    @Previewable @State var sort = PlayersDestination.defaultSortOrder

    PlayersColumnsView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        recentGames: [],
        onShowInLibrary: { _ in },
        sortOrder: $sort
    )
    .frame(width: 860, height: 520)
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("No Selection") {
    @Previewable @State var selection: Set<PlayerStats.ID> = []
    @Previewable @State var sort = PlayersDestination.defaultSortOrder

    PlayersColumnsView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        recentGames: [],
        onShowInLibrary: { _ in },
        sortOrder: $sort
    )
    .frame(width: 860, height: 520)
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PlayerStats.ID> = []
    @Previewable @State var sort = PlayersDestination.defaultSortOrder

    PlayersColumnsView(
        players: [],
        selectedKeys: $selection,
        recentGames: [],
        onShowInLibrary: { _ in },
        sortOrder: $sort
    )
    .frame(width: 860, height: 520)
}
