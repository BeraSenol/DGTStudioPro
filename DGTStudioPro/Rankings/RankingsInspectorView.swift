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
        List {
            if let ranked {
                RankSection(ranked: ranked, ratedGames: history.count)
                    .id(ranked.id)   // reset per-player, the inspector idiom
                TrendSection(history: history)
            } else {
                emptySection
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: Instance Methods
    private var emptySection: some View {
        Section {
            Text("No player selected")
                .foregroundStyle(.secondary)
        } header: {
            Text("Ranking")
        }
    }
}

// MARK: - Rank

private struct RankSection: View {

    let ranked: RankedPlayer
    let ratedGames: Int

    var body: some View {
        Section {
            HStack(spacing: 12) {
                PlayerMonogram(name: ranked.stats.name, diameter: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ranked.stats.name)
                        .font(.headline)
                    Text("Rank #\(ranked.rank)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

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
            Text("Ranking")
        }
        .accessibilityIdentifier(AccessibilityID.rankingsInspectorProfile)
    }
}

// MARK: - Trend

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
            Text("Rating Trend")
        }
    }
}

// MARK: Previews
#Preview {
    RankingsInspectorView(ranked: nil, history: [])
        .frame(width: 300, height: 400)
}
