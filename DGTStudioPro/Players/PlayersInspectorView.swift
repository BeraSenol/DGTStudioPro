//
//  PlayersInspectorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import Charts
import SwiftData
import SwiftUI

/// The player profile (M-prs.3; absorbed the Rankings inspector in D48′):
/// pure-value inputs — the ranked row and rating history arrive computed;
/// only the recent-games list carries models, for the `openWindow` handle.
/// One profile grid with each fact stated once (the old pair said Wins three
/// ways between them), then the rating trend, then recent games.
internal struct PlayersInspectorView: View {

    // MARK: Stored Properties
    internal let ranked: RankedPlayer?
    internal let history: [Glicko1.Sample]
    internal let recentGames: [PGN]

    /// M5's two selection-scoped operations, as closures rather than store
    /// reach.
    ///
    /// This view is pure-value by design — stats and rating arrive computed —
    /// and both rename and merge need a resolved `Player`, a `modelContext` and
    /// somewhere to put a sheet. Handing it closures keeps that property
    /// intact: the destination already owns the context and the key→row bridge
    /// (`showInLibrary`'s route), so it owns these too, and the inspector
    /// stays previewable without a container.
    ///
    /// **Delete is deliberately not here (D40′).** M5 put a per-player "Delete
    /// Player" in the menu below, guarded by `recentGames.isEmpty`, and that
    /// guard could never be true: this view is only ever handed a row the
    /// stats index emitted, the index folds `GameRecord`s, and a record's
    /// sides are built from the resolved links — so every selectable player
    /// has at least one game. Orphans, the only rows the store's delete
    /// accepts, appear in no view mode at all. The operation lives on the
    /// destination's toolbar, where it can reach them.
    ///
    /// Defaulted so the previews below and any future host can omit them;
    /// the app always wires both.
    internal var onRename: () -> Void = {}
    internal var onMerge: () -> Void = {}

    // MARK: Body
    internal var body: some View {
        // D26′ — empty renders outside the `List`; see `InspectorEmptyState`.
        if let ranked {
            List {
                ProfileSection(
                    ranked: ranked,
                    ratedGames: history.count,
                    onRename: onRename,
                    onMerge: onMerge
                )
                .id(ranked.id)   // reset per-player, the Library-inspector idiom
                TrendSection(history: history)
                RecentGamesSection(playerKey: ranked.stats.key, games: recentGames)
            }
            .listStyle(.sidebar)
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
}

// MARK: Profile

private struct ProfileSection: View {

    let ranked: RankedPlayer
    let ratedGames: Int
    let onRename: () -> Void
    let onMerge: () -> Void

    /// `.playerProfile` — the surviving identity of the D48′ merge.
    /// `.rankingProfile` is retired from `InspectorSection` with the
    /// destination that owned it: the two grids stopped being different
    /// content the moment they became one grid, so keeping both cases would
    /// have minted two names for one section. A stored collapse under the
    /// retired raw value evicts on the next write, per D45′'s designed cost.
    ///
    /// Three controls in the header — chevron, pencil, menu. The chevron
    /// leads, so the verbs stay rightmost.
    var body: some View {
        CollapsibleSection(.playerProfile, title: ranked.stats.name) {
            // Rank leads because it is what the destination sorts by
            // (D11′); Record absorbs the old separate Wins row — the
            // RankingsInspectorView Wins-twice open item, closed by
            // deleting the duplication rather than the row.
            LabeledContent("Rank", value: "#\(ranked.rank)")
            LabeledContent("Games", value: "\(ranked.stats.games)")
            LabeledContent("Record", value: "\(ranked.stats.wins)–\(ranked.stats.draws)–\(ranked.stats.losses)")
            LabeledContent("Win Rate", value: ranked.stats.winRate.formatted(.percent.precision(.fractionLength(0))))
            LabeledContent("Rating", value: ranked.rating?.displaySummary ?? "Unrated")
            if let rating = ranked.rating {
                // The deviation IS the honesty of the number above —
                // surface it instead of hiding it in the provisional flag.
                LabeledContent("Uncertainty", value: "±\(Int(rating.deviation.rounded()))")
            }
            LabeledContent("Rated Games", value: "\(ratedGames)")
            LabeledContent("Mates Delivered", value: "\(ranked.stats.matesDelivered)")
            LabeledContent("First Played", value: RosterSummary.displayDate(ranked.stats.firstPlayed))
            LabeledContent("Last Played", value: RosterSummary.displayDate(ranked.stats.lastPlayed))
        } actions: {
            // The player's name is the title above — not "Player Profile" — for
            // the reason it always was: the destination already says what kind
            // of thing this is, and the header is the one place that can say
            // *which*.
            //
            // Two controls, the Library inspector's PGN-header shape: the D26′
            // pencil keeps its one fixed meaning (edit *this* thing's name),
            // and everything that isn't a rename lives in a menu beside it.
            // Widening the pencil to also merge would turn a named affordance
            // into a generic icon button and lose the guarantee three
            // inspectors' pencils currently give.
            //
            // The menu holds one item since D40′ took Delete out of it, and
            // stays a menu rather than becoming a second glyph button: a merge
            // icon would have to be either a new parameter on the shared pencil
            // or a locally open-coded button, and both are the drift D26′
            // exists to prevent. A menu is also where the next player-scoped
            // verb goes without another decision.
            HStack(spacing: 12) {
                InspectorEditButtonView(
                    label: "Rename Player",
                    identifier: AccessibilityID.playersRenameButton,
                    action: onRename
                )
                actionsMenu
            }
        }
        // Stays on the section, not the header, so it keeps naming what the
        // UITest expects it to name. Collapsing hides the rows and not this —
        // the seeded run has an empty collapsed set, so the flow tests see the
        // section open regardless.
        //
        // UNVERIFIED as of 1 August, and flagged rather than left reading as
        // settled: `test_players_profileHeaderControls_areHittable`,
        // `…renameRewritesTheListedName` and `…mergeFoldsTheLoserAway` all fail
        // here, with the pencil and the menu not resolving by identifier while
        // this identifier resolves fine. `.accessibilityElement(children:
        // .contain)` ahead of this line was tried and changed nothing, so the
        // shadowing explanation is disproved rather than merely unconfirmed.
        // Cause still unknown; see AUDIT-2026-08-01.md § Zero for what has been
        // ruled out and the instrument that would settle it.
        .accessibilityIdentifier(AccessibilityID.playersInspectorProfile)
    }

    private var actionsMenu: some View {
        Menu {
            Button("Merge Into…", action: onMerge)
                .accessibilityIdentifier(AccessibilityID.playersMergeMenuItem)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        // `InspectorEditButtonView`'s reason: a glyph at header font size is
        // an ~11 pt mouse target.
        .font(.body)
        .help("Merge this player into another")
        .accessibilityIdentifier(AccessibilityID.playersActionsMenu)
    }
}

// MARK: Trend

/// Moved whole from the retired `RankingsInspectorView` (D48′) — same
/// `.ratingTrend` identity, because the section shows the same thing from a
/// new host, and D45′ says identity follows content, not address.
private struct TrendSection: View {

    let history: [Glicko1.Sample]

    var body: some View {
        CollapsibleSection(.ratingTrend, title: "Rating Trend") {
            if history.isEmpty {
                Text("No rated games yet — the rating starts once this player finishes a game against another named player.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Indexed identity: two rated games can share an effective
                // date (undated same-day imports), so `\.date` can't be
                // the id.
                Chart(Array(history.enumerated()), id: \.offset) { _, sample in
                    LineMark(
                        x: .value("Date", sample.date),
                        y: .value("Rating", sample.rating.mean)
                    )
                    PointMark(
                        x: .value("Date", sample.date),
                        y: .value("Rating", sample.rating.mean)
                    )
                }
                .frame(height: 160)
                .padding(.vertical, 4)

                if history.last?.rating.isProvisional == true {
                    Text("Provisional — the rating settles as more games are played.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
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

    /// Row tap opens the game — the inspector's open affordance, same
    /// `openWindow(value:)` route as the Library inspector (macOS dedups
    /// and tabs the windows).
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

/// A provisional rating meeting the merged grid: the qualifier string is the
/// longest value in the section — the one that can wrap in a 260 pt
/// inspector — and Uncertainty renders beneath it. The single-sample trend
/// rides along: a one-point domain is where chart axes misbehave.
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

/// Unrated: a resolved player whose games never produced a rated pairing —
/// the Rating row's nil branch, no Uncertainty row, an empty trend.
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

/// A long history with a visible swing — the trend line's real shape, and
/// the y-domain's stress case.
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
