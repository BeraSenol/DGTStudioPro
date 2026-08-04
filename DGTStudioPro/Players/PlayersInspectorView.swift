//
//  PlayersInspectorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

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

    /// How many players the destination's selection holds (2 Aug 2026 —
    /// the selection went multi with the Library's model). `ranked`
    /// arrives nil for empty *and* plural selections, so without the count
    /// this view could not tell "select someone" from "you selected five
    /// people". Defaulted so previews and the empty state read unchanged;
    /// the destination always passes it.
    internal var selectionCount: Int = 0

    // `onRename` lived here from M5 until M10 and is gone with the seam it
    // named. The header's three controls went one at a time and the sequence
    // is worth one comment rather than three: D40′ took Delete to the toolbar,
    // D52′ took Merge and the ellipsis menu holding it, and M10 took the
    // pencil to Get Info. What is left is a chevron.
    //
    // The property outlived every one of them. It survived D52′ documented as
    // "the one left", and M10 kept it deliberately as the seam Get Info would
    // plug into — a comment that called itself "a deadline, not a
    // description". The 4 Aug review found it wired to nothing from either
    // end. The lesson is not that keeping a seam is wrong; it is that a seam
    // with no caller and no *test* is indistinguishable from dead code, and
    // the only thing separating them was a sentence.
    //
    // **Delete is deliberately not here (D40′)** and this paragraph stays,
    // because the argument outlives the property it was attached to. M5 put a
    // per-player "Delete Player" in the menu below, guarded by
    // `recentGames.isEmpty`, and that guard could never be true: this view is
    // only ever handed a row the stats index emitted, the index folds
    // `GameRecord`s, and a record's sides are built from the resolved links —
    // so every selectable player has at least one game. Orphans, the only
    // rows the store's delete accepts, appear in no view mode at all. Any
    // future player-scoped operation belongs on the destination's toolbar or
    // in Get Info, never gated on the *selected* player lacking games.

    // MARK: Body
    internal var body: some View {
        // D26′ — empty renders outside the `List`; see `InspectorEmptyState`.
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

    /// The counting variant — the Library inspector's shape and symbol, so
    /// every "you selected many" surface speaks one vocabulary.
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

    /// `.playerProfile` — the surviving identity of the D48′ merge.
    /// `.rankingProfile` is retired from `InspectorSection` with the
    /// destination that owned it: the two grids stopped being different
    /// content the moment they became one grid, so keeping both cases would
    /// have minted two names for one section. A stored collapse under the
    /// retired raw value evicts on the next write, per D45′'s designed cost.
    ///
    /// One control in the header now: the chevron. It was three (chevron,
    /// pencil, ellipsis menu) at M5, two after D52′ retired merge, and one
    /// after M10 moved rename to Get Info. The "chevron leads so the verb
    /// stays rightmost" rule is not gone — it is `InspectorSectionHeader`'s,
    /// and it governs the Library's PGN header, which is where the app's two
    /// remaining header verbs sit.
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
            // The lone D26′ pencil, its one fixed meaning intact (edit *this*
            // thing's name). The ellipsis menu that used to sit beside it
            // existed for exactly one item — Merge Into… — after D40′ took
            // Delete out of it; when D52′ removed merge, the menu had nothing
            // left to hold and went too. If a second player-scoped verb ever
            // arrives, the two-control precedent lives in the Library's
            // PGN header, not here.
            // The pencil is gone (M10). Rename is Get Info's — the Players
            // instance of one verb the Library and Board also have, not a
            // pencil rehomed, which is what makes retiring it a generalization
            // rather than a removal.
            //
            // The `onRename` seam that survived here "for the length of one
            // pass" is gone too, and the deadline its comment set was met the
            // way deadlines should be: by the door existing. `GetInfoWindow`'s
            // player form carries the field, the `PGNStore.retag` call and
            // D39′'s refusal alert. Nothing routes through this header any
            // more, so this slot is empty rather than merely quiet.
        }
        // Stays on the section, not the header, so it named what the flow
        // tests looked for. Collapsing hides the rows and not this — the
        // seeded run had an empty collapsed set, so those tests saw the
        // section open regardless.
        //
        // Closed UNRESOLVED (D51′). Three flow tests failed here with the
        // pencil and the menu not resolving by identifier while this
        // identifier resolved fine; `.accessibilityElement(children:
        // .contain)` ahead of this line changed nothing, so the shadowing
        // explanation is disproved rather than merely unconfirmed. The
        // suite — and § Zero's hierarchy instrument with it — was deleted
        // 3 Aug 2026 before the cause was found (AUDIT-2026-08-01.md § Zero
        // records what was ruled out). If a UI suite ever returns, expect
        // these three to fail again for the same unknown reason.
        .accessibilityIdentifier(AccessibilityID.playersInspectorProfile)
    }
}

// `TrendSection` lived here until 4 Aug 2026 — replaced whole by
// `PlayerRatingGraph` (its own file), which redraws the same `.ratingTrend`
// section over games played instead of time. The date axis spent its width
// on pauses; the ordinal axis spends it on games, which is the rating's own
// clock under c = 0 (D11′). The D48′ provenance travels with the new file's
// doc.

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

/// The counting branch: nil `ranked` with a plural count — a rubber-band
/// or ⌘-click selection. No fixture reaches it by accident.
#Preview("Multi-Selection") {
    PlayersInspectorView(ranked: nil, history: [], recentGames: [], selectionCount: 5)
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
