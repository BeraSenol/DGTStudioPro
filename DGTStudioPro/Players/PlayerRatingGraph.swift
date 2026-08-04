//
//  PlayerRatingGraph.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 04/08/2026.
//

import Charts
import SwiftUI

/// The profile's rating trend, drawn over *games played* rather than time —
/// `TrendSection`'s replacement (4 Aug 2026, Bera's ask).
///
/// **The x-axis is ordinal, and that is the whole redesign.** The old chart
/// plotted `Sample.date`, so a player who stopped for a year was a line with
/// a huge flat gap — the axis spent its width on the pause instead of on the
/// games. But a Glicko history *is* ordinal: with c = 0 (D11′) idle time
/// changes nothing, every sample is "after game n", and the date only says
/// when game n happened to fall. Game number is the rating's own clock; the
/// date axis was always borrowed.
///
/// What the reclaimed width carries: one **monotone** line — smooth without
/// overshoot, because a rating never visited 1700 on its way from 1650 to
/// 1680, and `.monotone` is the interpolation that never claims it did.
///
/// (The first version carried more, all removed by request the same
/// evening, each for the same reason once seen: a mean ± RD band read as a
/// blue wash rather than information; budget-gated per-game dots and an
/// annotated end point restated what the profile grid one row up already
/// says. The deviation speaks through the Uncertainty row and the
/// provisional caption; the current mean through the Rating row. The chart
/// is the *shape*, and the line is the shape.)
///
/// Keeps `.ratingTrend` — D45′: identity follows content, and this is the
/// same content on a truer axis. The D48′ provenance travels with it: the
/// section moved whole from the retired `RankingsInspectorView` before it
/// was redrawn here.
internal struct PlayerRatingGraph: View {

    // MARK: Stored Properties
    internal let history: [Glicko1.Sample]

    // MARK: Computed Properties

    /// Y-domain padded past the means and rounded outward to tens, so the
    /// line never touches the plot edge and the axis labels stay round.
    /// Means only, since the band left: padding past mean ± RD would squash
    /// a provisional player's line into the middle third of an empty plot.
    /// The fallback range is unreachable (the chart only renders with
    /// history) and exists for the type, not the user.
    private var yDomain: ClosedRange<Double> {
        let means = history.map(\.rating.mean)
        guard let low = means.min(), let high = means.max() else { return 1400...1600 }
        let floor = (((low - 20) / 10).rounded(.down)) * 10
        let ceiling = (((high + 20) / 10).rounded(.up)) * 10
        return floor...ceiling
    }

    // MARK: Body
    internal var body: some View {
        CollapsibleSection(.ratingTrend, title: "Rating Trend") {
            if history.isEmpty {
                Text("No rated games yet — the rating starts once this player finishes a game against another named player.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                chart

                if history.last?.rating.isProvisional == true {
                    Text("Provisional — the rating settles as more games are played.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: Instance Methods

    private var chart: some View {
        // Indexed identity, kept from the original: two rated games can
        // share an effective date (undated same-day imports), so `\.date`
        // could never be the id — and now that the axis is ordinal, the
        // index is not just the identity but the x-value itself.
        Chart(Array(history.enumerated()), id: \.offset) { index, sample in
            LineMark(
                x: .value("Game", index + 1),
                y: .value("Rating", sample.rating.mean)
            )
            .foregroundStyle(.tint)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)

            // No marks but the line, since the same evening's third pass:
            // the budget-gated per-game dots, the enlarged end point, and
            // its rating annotation each shipped and were removed by
            // request. The line alone is the chart; the current rating
            // already sits one row up in the profile grid, so the
            // annotation was saying something the eye had just read.
        }
        .chartYScale(domain: yDomain)
        // Pinned at game 1, because Charts' automatic domain rounds a
        // 1-based positive axis down to a "nice" 0 — a dead column for a
        // game that doesn't exist, a quarter of the plot at three games.
        // The first game belongs on the leading edge. (`max(…, 2)` keeps
        // the domain non-degenerate for a one-game history.)
        .chartXScale(domain: 1...max(history.count, 2))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5))
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine()
                // Ungrouped, deliberately: a rating is a scalar, and the
                // default axis format let the locale write 1512 as
                // "1.512". (The one label home — the end-point annotation
                // that carried the `verbatim` twin retired with the marks.)
                // The concrete style, not `.number`: `AxisValueLabel(format:)`
                // is generic over the format's input and the axis closure
                // erases the plotted type, so the leading-dot shorthand has
                // nothing to anchor on and reports itself as ambiguous.
                AxisValueLabel(format: FloatingPointFormatStyle<Double>.number.grouping(.never))
            }
        }
        .frame(height: 160)
        .padding(.vertical, 4)
    }
}

// MARK: Previews

/// A hand-written settling arc — the initial 1500/350 folding toward a
/// stable strength, deviations shrinking the way `Glicko1.updated` shrinks
/// them. Hand-written rather than computed through the fold so the preview
/// stays a picture of the *view*, not a second test of the maths.
private func settlingHistory() -> [Glicko1.Sample] {
    let means: [Double] = [1464, 1479, 1512, 1538, 1561, 1550, 1573, 1584, 1579, 1591, 1603, 1598]
    let deviations: [Double] = [290, 248, 216, 192, 173, 158, 146, 136, 128, 121, 115, 110]
    return zip(means, deviations).enumerated().map { index, pair in
        Glicko1.Sample(
            date: Date(timeIntervalSinceReferenceDate: Double(index) * 86_400),
            rating: Glicko1.Rating(mean: pair.0, deviation: pair.1)
        )
    }
}

/// Sixty games with a two-year pause after game 25 — the fixture that shows
/// the redesign: on the old date axis this was mostly empty space, and here
/// the pause is deliberately invisible. The dates still carry the gap; the
/// axis just no longer spends width on it.
private func veteranHistory() -> [Glicko1.Sample] {
    (0..<60).map { index in
        let wander = 40.0 * sin(Double(index) / 5.5) + Double(index) * 1.8
        let pause: Double = index >= 25 ? 730 * 86_400 : 0
        return Glicko1.Sample(
            date: Date(timeIntervalSinceReferenceDate: Double(index) * 5 * 86_400 + pause),
            rating: Glicko1.Rating(mean: 1540 + wander, deviation: max(45, 120 - Double(index) * 3))
        )
    }
}

#Preview("Settling") {
    List {
        PlayerRatingGraph(history: settlingHistory())
    }
    .listStyle(.sidebar)
    .frame(width: 340, height: 300)
    .environment(InspectorSectionCollapse.preview)
}

#Preview("Veteran — Long Break, No Gap") {
    List {
        PlayerRatingGraph(history: veteranHistory())
    }
    .listStyle(.sidebar)
    .frame(width: 340, height: 300)
    .environment(InspectorSectionCollapse.preview)
}

#Preview("Provisional — Three Games") {
    List {
        PlayerRatingGraph(history: Array(settlingHistory().prefix(3)))
    }
    .listStyle(.sidebar)
    .frame(width: 340, height: 300)
    .environment(InspectorSectionCollapse.preview)
}

#Preview("Empty") {
    List {
        PlayerRatingGraph(history: [])
    }
    .listStyle(.sidebar)
    .frame(width: 340, height: 300)
    .environment(InspectorSectionCollapse.preview)
}
