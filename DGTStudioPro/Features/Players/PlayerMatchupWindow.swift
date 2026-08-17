import SwiftData
import SwiftUI

// MARK: Request

/// `openWindow(value:)` wrapper - the routing-by-type family's newest member (the D46′ trap:
/// the call routes by TYPE, and a second group over an existing value type silently unroutes
/// every call over it). Carries the display name as well as the key so the window can title
/// itself before any fold runs.
struct PlayerMatchupRequest: Codable, Hashable {
    let playerKey: String
    let playerName: String
}

// MARK: Matchup View

/// The head-to-head core (17 Aug 2026, by request): the fixed player against a re-selectable
/// opponent, seeded with the MOST RECENT one - "the last match up". The W-D-L reads from the
/// fixed player's side via `PlayerStats.opponents`, the same fold the gallery's old opponents
/// panel used, so these numbers cannot disagree with any other surface that folds it. Shared
/// by the matchup window and the Players gallery's preview band; hosts apply `.id(playerKey)`
/// so the opponent selection resets when the subject changes.
struct PlayerMatchupView: View {

    let playerKey: String
    let playerName: String
    let records: [GameRecord]

    /// The re-selectable half. Seeded once in `onAppear` rather than derived per render -
    /// the whole point is that the reader can point it somewhere else.
    @State private var opponentKey: String?

    private var opponents: [PlayerStats.Opponent] {
        PlayerStats.opponents(of: playerKey, in: records)
    }

    /// The other side of the player's chronologically last game - "the last match up".
    /// Decided-or-not deliberately: the most recent opponent is who you *played*, even if
    /// that game is still ongoing; the score below only ever counts decided games.
    private var mostRecentOpponentKey: String? {
        records
            .filter { $0.white?.key == playerKey || $0.black?.key == playerKey }
            .sorted(by: GameRecord.chronologicalOrder)
            .last
            .flatMap { $0.white?.key == playerKey ? $0.black?.key : $0.white?.key }
    }

    private var opponent: PlayerStats.Opponent? {
        opponents.first { $0.key == opponentKey }
    }

    var body: some View {
        VStack(spacing: 14) {
            if let opponent {
                Text("\(playerName) vs \(opponent.name)")
                    .font(.title3.weight(.semibold))

                // W-D-L from the fixed player's side - the head-to-head reading order the
                // toolbar subtitle already uses.
                HStack(spacing: 10) {
                    scoreColumn(opponent.wins, label: "Wins")
                    scoreDash
                    scoreColumn(opponent.draws, label: "Draws")
                    scoreDash
                    scoreColumn(opponent.losses, label: "Losses")
                }

                Text("\(opponent.wins + opponent.draws + opponent.losses) decided games together")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Opponent", selection: $opponentKey) {
                    ForEach(opponents) { entry in
                        Text(entry.name).tag(Optional(entry.key))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 260)
            } else {
                ContentUnavailableView(
                    "No Opponents",
                    systemImage: "person.line.dotted.person",
                    description: Text(
                        "\(playerName) has no decided games against another named player."
                    )
                )
            }
        }
        .onAppear {
            if opponentKey == nil {
                opponentKey = mostRecentOpponentKey ?? opponents.first?.key
            }
        }
    }

    private func scoreColumn(_ value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 52)
    }

    private var scoreDash: some View {
        Text("–")
            .font(.title2.weight(.light))
            .foregroundStyle(.tertiary)
    }
}

// MARK: Window

/// The player window: double-clicking a player in any Players view opens it (17 Aug 2026 -
/// the double-click's door; Get Info keeps the menus, and with them the rename). Queries the
/// Library itself - a separate window cannot borrow a destination's fold. Fetch-all-and-map
/// per render: the destinations' own cost family, censused rather than optimised ahead of a
/// measurement.
struct PlayerMatchupWindow: View {

    let request: PlayerMatchupRequest?

    @Query private var games: [PGN]

    var body: some View {
        Group {
            if let request {
                PlayerInfoTabs(request: request, games: games)
            } else {
                InspectorEmptyState(
                    title: "Nothing to Show",
                    systemImage: "person.line.dotted.person",
                    message: "Double-click a player in the Players view to see a matchup.",
                    identifier: AccessibilityID.matchupWindowEmpty
                )
            }
        }
        .frame(minWidth: 480, minHeight: 420)
    }
}

// MARK: Player Tabs

/// One player in Settings' own tab arrangement (17 Aug 2026, trimmed the same evening):
/// **Profile** first (monogram, stats grid, rating trend - the panels and a Games tab lived
/// here for an hour and left by request), then **Matchup** (the double-click's original
/// face). Every number rides a shared fold - `PlayerStats.index`, `Glicko1.histories` - so
/// nothing here can disagree with a destination.
private struct PlayerInfoTabs: View {

    let request: PlayerMatchupRequest
    let games: [PGN]

    private var records: [GameRecord] { games.map(\.gameRecord) }

    private var stats: PlayerStats? {
        PlayerStats.index(of: records).first { $0.key == request.playerKey }
    }

    private var history: [Glicko1.Sample] {
        Glicko1.histories(from: records)[request.playerKey] ?? []
    }

    var body: some View {
        TabView {
            Tab("Profile", systemImage: "person.crop.circle") {
                profileTab
            }
            Tab("Matchup", systemImage: "person.line.dotted.person") {
                ScrollView {
                    PlayerMatchupView(
                        playerKey: request.playerKey,
                        playerName: request.playerName,
                        records: records
                    )
                    .padding(24)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private var profileTab: some View {
        if let stats {
            ScrollView {
                VStack(spacing: 16) {
                    PlayerMonogram(name: stats.name, side: 72)
                    Text(stats.name)
                        .font(.title3.weight(.semibold))
                    PlayerStatsGrid(stats: stats, rating: history.last?.rating)
                    if !history.isEmpty {
                        RatingTrendChart(history: history)
                            .frame(maxWidth: 460)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        } else {
            ContentUnavailableView(
                "No Games Yet",
                systemImage: "person.crop.circle.dashed",
                description: Text("\(request.playerName) has no games in the Library.")
            )
        }
    }
}

// MARK: Previews

#Preview("Matchup") {
    PlayerMatchupView(
        playerKey: PreviewFixtures.topStats().key,
        playerName: PreviewFixtures.topStats().name,
        records: PreviewFixtures.records()
    )
    .padding(28)
    .frame(width: 460, height: 340)
}

/// The no-opponents arm - a player whose only games are ongoing or against nobody named.
#Preview("No Opponents") {
    PlayerMatchupView(
        playerKey: "nobody",
        playerName: "Nobody Yet",
        records: []
    )
    .padding(28)
    .frame(width: 460, height: 340)
}
