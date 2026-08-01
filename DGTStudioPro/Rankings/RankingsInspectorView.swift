//
//  RankingsInspectorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import Charts
import SwiftUI

/// The ladder inspector (M-prs.4): the rank in context, the rating with
/// its uncertainty made explicit, and the trend line — the whole reason
/// `Glicko1.histories` returns samples instead of just finals.
internal struct RankingsInspectorView: View {
    
    // MARK: Stored Properties
    internal let ranked: RankedPlayer?
    internal let history: [Glicko1.Sample]
    
    // MARK: Body
    internal var body: some View {
        // D26′ — empty renders outside the `List`; see `InspectorEmptyState`.
        if let ranked {
            List {
                RankSection(ranked: ranked, ratedGames: history.count)
                    .id(ranked.id)   // reset per-player, the inspector idiom
                TrendSection(history: history)
            }
            .listStyle(.sidebar)
        } else {
            emptyState
        }
    }
    
    // MARK: Instance Methods
    /// This was the furthest-drifted of the four: a secondary `Text` under a
    /// "Ranking" section header, sentence-cased and symbol-less, so the
    /// destination that ranks players looked like it had failed to load
    /// rather than like it was waiting for a selection. `list.number` is the
    /// destination's own empty-state symbol, which keeps it distinguishable
    /// from Players' `person.fill` at the same title.
    private var emptyState: some View {
        InspectorEmptyState(
            title: "No Player Selected",
            systemImage: "list.number",
            message: "Select a player to see their rank and rating trend.",
            identifier: AccessibilityID.rankingsInspectorEmpty
        )
    }
}

// MARK: Rank

private struct RankSection: View {
    
    let ranked: RankedPlayer
    let ratedGames: Int
    
    var body: some View {
        Section {
            // The rank was a caption under the name in the identity row this
            // replaces. It is a fact about the player exactly like Wins and
            // Rating, so it becomes a row like them rather than chrome — and
            // it leads, because it is what the destination sorts by (D11′).
            LabeledContent("Rank", value: "#\(ranked.rank)")
            LabeledContent("Wins", value: "\(ranked.stats.wins)")
            LabeledContent("Record", value: "\(ranked.stats.wins)–\(ranked.stats.draws)–\(ranked.stats.losses)")
            LabeledContent("Rating", value: ranked.rating?.displaySummary ?? "Unrated")
            if let rating = ranked.rating {
                // The deviation IS the honesty of the number above —
                // surface it instead of hiding it in the provisional flag.
                LabeledContent("Uncertainty", value: "±\(Int(rating.deviation.rounded()))")
            }
            LabeledContent("Rated Games", value: "\(ratedGames)")
        } header: {
            // The player's name, matching Players and Library — see
            // `ProfileSection`'s header for the argument.
            InspectorSectionHeader(ranked.stats.name)
        }
        .accessibilityIdentifier(AccessibilityID.rankingsInspectorProfile)
    }
}

// MARK: Trend

private struct TrendSection: View {
    
    let history: [Glicko1.Sample]
    
    var body: some View {
        Section {
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
        } header: {
            InspectorSectionHeader("Rating Trend")
        }
    }
}

// MARK: Previews

#Preview("Empty") {
    RankingsInspectorView(ranked: nil, history: [])
        .frame(width: 300, height: 440)
        .environment(InspectorSectionCollapse.preview)
}

#Preview("Ranked — With Trend") {
    let ranked = PreviewFixtures.rankedPlayers()[0]
    let history = Glicko1.histories(from: PreviewFixtures.records())[ranked.stats.key] ?? []
    
    return RankingsInspectorView(ranked: ranked, history: history)
        .frame(width: 300, height: 440)
        .environment(InspectorSectionCollapse.preview)
}

/// One sample: the Charts trend line has no segment to draw. Worth its own
/// preview because a single-point domain is where chart axes misbehave.
#Preview("Single Sample") {
    let ranked = PreviewFixtures.rankedPlayers().last!
    
    return RankingsInspectorView(
        ranked: ranked,
        history: [Glicko1.Sample(date: .now, rating: .initial)]
    )
    .frame(width: 300, height: 440)
    .environment(InspectorSectionCollapse.preview)
}

/// A long history with a visible swing — the trend line's real shape, and
/// the y-domain's stress case.
#Preview("Long History") {
    let ranked = PreviewFixtures.rankedPlayers()[0]
    let samples = (0..<24).map { step in
        Glicko1.Sample(
            date: Date(timeIntervalSince1970: 1_720_000_000 + Double(step) * 86_400),
            rating: Glicko1.Rating(
                mean: 1500 + Double(step) * 9 - (step.isMultiple(of: 3) ? 55 : 0),
                deviation: max(45, 350 - Double(step) * 12)
            )
        )
    }
    
    return RankingsInspectorView(ranked: ranked, history: samples)
        .frame(width: 300, height: 440)
        .environment(InspectorSectionCollapse.preview)
}
