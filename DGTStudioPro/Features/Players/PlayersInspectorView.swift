import SwiftData
import SwiftUI

/// The player profile (absorbed the Rankings inspector): pure-value inputs; only the
/// recent-games list carries models, for the `openWindow` handle. One grid, each fact once.
struct PlayersInspectorView: View {

    // MARK: Stored Properties
    let ranked: RankedPlayer?
    let history: [Glicko1.Sample]
    let recentGames: [PGN]

    /// Selection count: `ranked` arrives nil for empty *and* plural, so this tells "select someone"
    /// from "you selected five".
    var selectionCount: Int = 0

    // MARK: Body
    var body: some View {
        // Empty renders outside the `List`; see `InspectorEmptyState`.
        if let ranked {
            List {
                ProfileSection(
                    ranked: ranked,
                    ratedGames: history.count
                )
                .id(ranked.id)   // reset per-player, the Library-inspector idiom
                PlayerRatingGraph(history: history)
                RecentGamesSection(playerKey: ranked.stats.key, games: recentGames)
            }
            .listStyle(.sidebar)
        } else if selectionCount > 1 {
            multiSelectionState
        } else {
            emptyState
        }
    }

    // MARK: Instance Methods
    private var emptyState: some View {
        InspectorEmptyState(
            title: "No Player Selected",
            systemImage: "person.fill",
            message: "Select a player to see their profile, rating trend and recent games.",
            identifier: AccessibilityID.playersInspectorEmpty
        )
    }

    /// The counting variant — the Library inspector's shape and symbol, one vocabulary.
    private var multiSelectionState: some View {
        InspectorEmptyState(
            title: "\(selectionCount) Players Selected",
            systemImage: "person.2.fill",
            message: "Select a single player to see their profile, or use Show in Library from a card's menu.",
            identifier: AccessibilityID.playersInspectorMulti
        )
    }
}

// MARK: Profile

private struct ProfileSection: View {

    let ranked: RankedPlayer
    let ratedGames: Int

    /// `.playerProfile` — the surviving identity of the merge; a stored collapse under the
    /// retired raw value evicts on the next write (the designed cost).
    var body: some View {
        CollapsibleSection(.playerProfile, title: ranked.stats.name) {
            // Rank leads (the default sort); Record absorbs the old separate Wins row.
            LabeledContent("Rank", value: "#\(ranked.rank)")
            LabeledContent("Games", value: "\(ranked.stats.games)")
            LabeledContent("Record", value: "\(ranked.stats.wins)–\(ranked.stats.draws)–\(ranked.stats.losses)")
            LabeledContent("Win Rate", value: ranked.stats.winRate.formatted(.percent.precision(.fractionLength(0))))
            LabeledContent("Rating", value: ranked.rating?.displaySummary ?? "Unrated")
            if let rating = ranked.rating {
                // The deviation IS the honesty of the number above — surfaced, not hidden in the provisional flag.
                LabeledContent("Uncertainty", value: "±\(Int(rating.deviation.rounded()))")
            }
            LabeledContent("Rated Games", value: "\(ratedGames)")
            LabeledContent("Mates Delivered", value: "\(ranked.stats.matesDelivered)")
            LabeledContent("First Played", value: RosterSummary.displayDate(ranked.stats.firstPlayed))
            LabeledContent("Last Played", value: RosterSummary.displayDate(ranked.stats.lastPlayed))
        } actions: {
            // The player's name is the title — the destination says what kind of thing this is; the header
            // says *which*.
        }
        // Identifier stays on the section: collapsing hides the rows, not this. A future suite should
        // expect the § Zero failures here — header controls unresolvable by identifier, cause unknown
        // (shadowing disproved; closed unresolved).
        .accessibilityIdentifier(AccessibilityID.playersInspectorProfile)
    }
}

// MARK: Recent Games

private struct RecentGamesSection: View {

    let playerKey: String
    let games: [PGN]

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        CollapsibleSection(.recentGames, title: "Recent Games") {
            if games.isEmpty {
                Text("No games")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(games.prefix(10)) { game in
                    row(for: game)
                }
                if games.count > 10 {
                    Text("and \(games.count - 10) more…")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    /// Row tap opens the game — same `openWindow(value:)` route as the Library inspector.
    private func row(for game: PGN) -> some View {
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

#Preview("Empty") {
    PlayersInspectorView(ranked: nil, history: [], recentGames: [])
        .frame(width: 300, height: 400)
        .environment(InspectorSectionCollapse.preview)
}

/// The counting branch — no fixture reaches it by accident.
#Preview("Multi-Selection") {
    PlayersInspectorView(ranked: nil, history: [], recentGames: [], selectionCount: 5)
        .frame(width: 300, height: 400)
        .environment(InspectorSectionCollapse.preview)
}

/// Provisional rating: the longest value in the section (can wrap at 260 pt), Uncertainty
/// beneath, single-sample trend (one-point domains are where chart axes misbehave).
#Preview("Provisional Rating") {
    PlayersInspectorView(
        ranked: RankedPlayer(
            rank: 4,
            stats: PreviewFixtures.playerStats().last!,
            rating: Glicko1.Rating(mean: 1487.0, deviation: 218.6)
        ),
        history: [Glicko1.Sample(date: .now, rating: .initial)],
        recentGames: []
    )
    .frame(width: 260, height: 560)
    .modelContainer(for: PGN.self, inMemory: true)
    .environment(InspectorSectionCollapse.preview)
}

/// Unrated: the Rating row's nil branch, no Uncertainty, empty trend.
#Preview("Unrated") {
    PlayersInspectorView(
        ranked: RankedPlayer(rank: 1, stats: PreviewFixtures.topStats(), rating: nil),
        history: [],
        recentGames: []
    )
    .frame(width: 300, height: 560)
    .modelContainer(for: PGN.self, inMemory: true)
    .environment(InspectorSectionCollapse.preview)
}

/// Long history with a visible swing — the y-domain's stress case.
#Preview("Long History") {
    let samples = (0..<24).map { step in
        Glicko1.Sample(
            date: Date(timeIntervalSince1970: 1_720_000_000 + Double(step) * 86_400),
            rating: Glicko1.Rating(
                mean: 1500 + Double(step) * 9 - (step.isMultiple(of: 3) ? 55 : 0),
                deviation: max(45, 350 - Double(step) * 12)
            )
        )
    }

    return PlayersInspectorView(
        ranked: PreviewFixtures.rankedPlayers()[0],
        history: samples,
        recentGames: []
    )
    .frame(width: 300, height: 620)
    .modelContainer(for: PGN.self, inMemory: true)
    .environment(InspectorSectionCollapse.preview)
}
