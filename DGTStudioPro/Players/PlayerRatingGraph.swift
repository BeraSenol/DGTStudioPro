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
    /// The plotted series: **step 0 is where everyone starts** (5 Aug 2026, by
    /// request), then one step per rated game.
    ///
    /// Glicko-1 gives every player the same opening position — 1500 with an RD
    /// of 350 (D11′) — and until this existed the chart's first point was the
    /// rating *after* game one, so the single most informative segment of a new
    /// player's history, the jump away from the default, was the one you could
    /// not see. Step 0 is not a game; it is the prior every player is measured
    /// against, which is why it earns a mark of its own below.
    ///
    /// Synthesised rather than stored: `Glicko1.Sample` records a rating *and a
    /// date*, and the starting rating has no date — it is true before the first
    /// game rather than on any particular day. Putting it in the history array
    /// would mean inventing one, and the fold would then have to skip it.
    private var plotted: [(step: Int, mean: Double)] {
        [(0, Glicko1.initialMean)]
        + history.enumerated().map { ($0.offset + 1, $0.element.rating.mean) }
    }

    private var yDomain: ClosedRange<Double> {
        // Over `plotted`, not `history`: the starting 1500 is a point on the
        // line, so a domain that excluded it would clip the first segment for
        // any player whose games all sit above or below the default.
        let means = plotted.map(\.mean)
        guard let low = means.min(), let high = means.max() else { return 1400...1600 }
        let floor = (((low - 20) / 10).rounded(.down)) * 10
        let ceiling = (((high + 20) / 10).rounded(.up)) * 10
        return floor...ceiling
    }

    // MARK: Body
    internal var body: some View {
        CollapsibleSection(.ratingTrend, title: "Rating Trend") {
            if history.isEmpty {
                // Names the number rather than only its absence: "the rating
                // starts" invites "at what?", and the graph beside it cannot
                // answer while there is nothing to draw.
                Text("No rated games yet. Everyone starts at \(Int(Glicko1.initialMean)), and the rating moves once this player finishes a game against another named player.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            } else {
                chart

                if history.last?.rating.isProvisional == true {
                    Text("Provisional. The rating settles as more games are played.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(3)
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
        Chart(plotted, id: \.step) { point in
            LineMark(
                x: .value("Game", point.step),
                y: .value("Rating", point.mean)
            )
            .foregroundStyle(.tint)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)

            // One mark, at step 0 only.
            //
            // The per-game dots were tried and removed by request — "the line
            // alone is the chart" — and this does not reopen that: those marked
            // every point, which restates what the line already draws. This
            // marks the one point that is *not* a game, so the reader can see
            // where the line started rather than inferring it from an axis. A
            // hollow circle rather than a filled one, so it reads as an origin
            // rather than as a data point of the same kind as the rest.
            if point.step == 0 {
                PointMark(
                    x: .value("Game", point.step),
                    y: .value("Rating", point.mean)
                )
                .foregroundStyle(.tint)
                .symbol {
                    Circle()
                        .strokeBorder(lineWidth: 2)
                        .frame(width: 7, height: 7)
                }
            }
        }
        .chartYScale(domain: yDomain)
        // Pinned at **0**, which reverses this comment's own reasoning and is
        // worth keeping rather than rewriting. It read: "a dead column for a
        // game that doesn't exist" — true while nothing was plotted there, and
        // false the moment step 0 became the starting rating. The premise was
        // sound and the conclusion expired when the data changed underneath it.
        //
        // (`max(…, 1)` keeps the domain non-degenerate for a player with no
        // rated games — one who would render 0...0 and collapse the plot.)
        .chartXScale(domain: 0...max(history.count, 1))
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

#Preview("Veteran, Long Break, No Gap") {
    List {
        PlayerRatingGraph(history: veteranHistory())
    }
    .listStyle(.sidebar)
    .frame(width: 340, height: 300)
    .environment(InspectorSectionCollapse.preview)
}

#Preview("Provisional, Three Games") {
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
