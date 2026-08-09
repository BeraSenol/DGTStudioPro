import Charts
import SwiftUI

/// The rating trend over *games played*, not time (Bera's ask): under c = 0 idle time changes
/// nothing, so game number is the rating's own clock — the date axis spent its width on pauses.
/// One clean monotone line, nothing else (band, dots and end annotation each shipped and were
/// removed by request); `.monotone` never claims a value the rating didn't visit.
internal struct PlayerRatingGraph: View {

    // MARK: Stored Properties
    internal let history: [Glicko1.Sample]

    // MARK: Body
    internal var body: some View {
        CollapsibleSection(.ratingTrend, title: "Rating Trend") {
            if history.isEmpty {
                // Names the number, not just its absence — "the rating starts" invites "at what?".
                Text("No rated games yet. Everyone starts at \(Int(Glicko1.initialMean)), and the rating moves once this player finishes a game against another named player.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            } else {
                RatingTrendChart(history: history)

                if history.last?.rating.isProvisional == true {
                    Text("Provisional. The rating settles as more games are played.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(3)
                }
            }
        }
    }
}

// MARK: Chart

/// The line itself, presentation-agnostic — extracted when the gallery preview became a second
/// drawer, so two hosts cannot draw one history two ways.
internal struct RatingTrendChart: View {

    // MARK: Stored Properties
    internal let history: [Glicko1.Sample]

    // MARK: Computed Properties

    /// **Step 0 is where everyone starts** (by request): the 1500/350 prior, hollow-marked — not a
    /// game, the prior every player is measured against.
    private var plotted: [(step: Int, mean: Double)] {
        [(0, Glicko1.initialMean)]
        + history.enumerated().map { ($0.offset + 1, $0.element.rating.mean) }
    }

    /// Y-domain padded past the means, rounded to tens. Means only — padding past mean ± RD would
    /// squash a provisional line into the middle third of an empty plot.
    private var yDomain: ClosedRange<Double> {
        // Over `plotted`, not `history`: the starting 1500 is on the line, and excluding it clips the
        // first segment for a player whose games all sit one side of the default.
        let means = plotted.map(\.mean)
        guard let low = means.min(), let high = means.max() else { return 1400...1600 }
        let floor = (((low - 20) / 10).rounded(.down)) * 10
        let ceiling = (((high + 20) / 10).rounded(.up)) * 10
        return floor...ceiling
    }

    // MARK: Body
    internal var body: some View {
        // Indexed identity: two rated games can share an effective date, so `\.date` could never be the
        // id — and on an ordinal axis the index IS the x-value.
        Chart(plotted, id: \.step) { point in
            LineMark(
                x: .value("Game", point.step),
                y: .value("Rating", point.mean)
            )
            .foregroundStyle(.tint)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)

            // One mark, step 0 only. Per-game dots were tried and removed by request — this marks the one
            // point that is *not* a game.
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
        // Pinned at **0** — this comment once argued for 1 ("a dead column for a game that doesn't
        // exist"), true until step 0 became the starting rating.
        .chartXScale(domain: 0...max(history.count, 1))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5))
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine()
                // `.grouping(.never)`: the locale wrote 1512 as "1.512" — no rating wears a thousands
                // separator. Concrete style — the leading-dot `.number` is ambiguous in the type-erased axis closure.
                AxisValueLabel(format: FloatingPointFormatStyle<Double>.number.grouping(.never))
            }
        }
        .frame(height: 160)
        .padding(.vertical, 4)
    }
}

// MARK: Previews

/// A hand-written settling arc — hand-written, not computed through the fold, so the preview
/// stays a picture of the view, not a second test of the maths.
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

/// Sixty games, two-year pause after game 25 — the fixture whose whole point is that the pause
/// is invisible on an ordinal axis.
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
