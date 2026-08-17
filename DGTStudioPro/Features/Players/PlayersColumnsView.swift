import SwiftData
import SwiftUI

/// Finder-column shape, `LibraryColumnsView`'s twin: flat player list left, detail right. The
/// list follows `players`' display order; the rank badge stays honest in any order (rank is
/// computed under the ranking method, not the sort). The one-column header cannot *display* an
/// ordering it did not set - accepted cost, documented at the Library twin.
struct PlayersColumnsView: View {

    // MARK: Stored Properties
    let players: [RankedPlayer]
    /// A set (shared selection model); the detail pane counts a plural selection.
    @Binding var selectedKeys: Set<PlayerStats.ID>
    /// The selected player's games, newest first - threaded exactly as the inspector gets it.
    let recentGames: [PGN]
    /// The shared recent-games cap - `StorageKeys.playersRecentGames`'s second reader; the
    /// inspector section holds the twin menu, one key keeps them agreeing.
    @AppStorage(StorageKeys.playersRecentGames) private var recentCount = 3
    let onShowInLibrary: (PlayerStats.ID) -> Void

    /// Shared with list mode through the destination (the Library twin's arrangement).
    @Binding var sortOrder: [KeyPathComparator<RankedPlayer>]

    @Environment(\.openWindow) private var openWindow

    // MARK: Computed Properties

    /// Single or nothing - the detail pane details one thing.
    private var selectedPlayer: RankedPlayer? {
        guard selectedKeys.count == 1, let key = selectedKeys.first else { return nil }
        return players.first { $0.id == key }
    }

    // MARK: Body
    var body: some View {
        HSplitView {
            // Matched to the Library's, per collection-destination parity (floor + layoutPriority reasoning there).
            playerList
                .frame(minWidth: 160, idealWidth: 200, maxWidth: 300, maxHeight: .infinity)
                .layoutPriority(1)

            detail
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Instance Methods

    /// Two empty states that both must hold: the list's own "No players" arm (previews build this
    /// view directly) and the detail placeholder.
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
            // A one-column `Table`, the Library's twin - see `LibraryColumnsView.gameList` for the header
            // cost and the missing `columnCustomization`.
            Table(players, selection: $selectedKeys, sortOrder: $sortOrder) {
                TableColumn("Player", value: \.stats.name) { player in
                    row(for: player)
                }
                // 160 floor, all three bounds - the Library twin's reasoning verbatim (min-only did not hold).
                .width(min: 160, ideal: 200, max: .infinity)
            }
            .tableStyle(.inset)
            // Selection-typed, but the menu stays single-subject: both verbs describe one player.
            .contextMenu(forSelectionType: PlayerStats.ID.self) { keys in
                if let key = keys.first {
                    PlayerActionsMenu(key: key, onShowInLibrary: onShowInLibrary)
                }
            }
        }
    }

    /// Finder's row: symbol and name, nothing else - reasoning at `LibraryColumnsView.row(for:)`.
    /// (This sentence listed "monogram, game count, rank chip" long after the row had shed all
    /// three; corrected 16 Aug 2026.)
    private func row(for player: RankedPlayer) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "person.fill")
                .imageScale(.medium)
                // Medal colours for the PODIUM glyphs only (17 Aug 2026, second pass): #1-#3
                // wear the medals, everything below keeps the default label colour - not the
                // headline's `.tint` fallback, "not tinted" being the request's exact words.
                .foregroundStyle(
                    RankMedal(rank: player.rank).map { AnyShapeStyle($0.color) }
                        ?? AnyShapeStyle(.primary)
                )
            Text(player.stats.name)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 1)
        // The menu moved to the `Table`; a per-row `.contextMenu` in a cell would shadow it.
    }

    @ViewBuilder
    private var detail: some View {
        if let player = selectedPlayer {
            playerDetail(player)
        } else if selectedKeys.count > 1 {
            // The shared multi-selection vocabulary.
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

    /// A scrolling profile, unlike the Library's fixed block: nothing fights for aspect ratio here,
    /// and the recent-games list is the part that grows.
    private func playerDetail(_ player: RankedPlayer) -> some View {
        // Vertically centred when the content is shorter than the pane (17 Aug 2026, by
        // request): the viewport height becomes the content's minimum, so short profiles
        // centre and tall ones scroll exactly as before.
        GeometryReader { pane in
            ScrollView {
                playerDetailContent(player)
                    .frame(maxWidth: .infinity, minHeight: pane.size.height)
            }
        }
    }

    private func playerDetailContent(_ player: RankedPlayer) -> some View {
            VStack(spacing: 16) {
                PlayerMonogram(name: player.stats.name, side: 96)

                // The gallery's identity row, kept in both hosts - rank earns the medal beside the name.
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

    /// The inspector's recent-games rules restated: rows open via `openWindow(value:)`, the
    /// cap is the reader's stored choice. Two hosts' decisions that agree today - deliberately
    /// not shared.
    /// `openWindow(value:)`. Two hosts' decisions that agree today - deliberately not shared.
    private var recentGamesBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Games")
                    .font(.headline)
                Spacer()
                // The inspector section's cap menu, restated - one stored key, two surfaces.
                Picker("Show", selection: $recentCount) {
                    Text("Last 3").tag(3)
                    Text("Last 5").tag(5)
                    Text("Last 10").tag(10)
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .fixedSize()
            }

            if recentGames.isEmpty {
                Text("No games")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentGames.prefix(recentCount)) { game in
                    gameRow(for: game)
                }
                if recentGames.count > recentCount {
                    Text("and \(recentGames.count - recentCount) more…")
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

/// The no-games branch - "No games", not a collapsed void.
#Preview("Selected, No Games") {
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

/// The counting branch - the state single-select columns could never render.
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
