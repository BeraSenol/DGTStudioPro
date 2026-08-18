import Charts
import SwiftUI

// MARK: Slice

/// One sector of the donut, and the legend row that names it. A type rather than three parallel
/// arrays so the chart and the legend read one order from one place.
///
/// **The colour is the only channel the chart itself has**, and green/red is the pair most often
/// indistinguishable, so the legend beside it is not decoration: it carries the label and the count
/// in text, and it renders all three rows even at zero. The chart is the shape of the record; the
/// legend is the record.
private struct RecordSlice: Identifiable {

    let label: String
    let count: Int
    let color: Color

    var id: String { label }
}

// MARK: Record Chart

/// A W-D-L record as a green/grey/red donut with a trailing legend (18 Aug 2026, Bera's redesign).
///
/// **Two hosts, one chart** - the `RatingTrendChart` arrangement: the Matchup tab draws a
/// head-to-head with it, the Performance tab draws the career record with it, and neither can drift
/// from the other. It was born private inside `PlayerMatchupView` and left the same day the second
/// tab asked for the same picture; the extraction is what stopped the second copy being written.
///
/// It takes three counts rather than a `PlayerStats` or an `Opponent` because those are the two
/// callers and it should not have to choose: the counts are the whole input, and a host that folds
/// them some third way is already served.
struct RecordChart: View {

    // MARK: Stored Properties

    let wins: Int
    let draws: Int
    let losses: Int

    /// Outer diameter. A parameter for `PlayerCardView.monogramSide`'s reason - a host with less
    /// room should shrink the chart rather than be given a differently-built one.
    var diameter: CGFloat = 150

    /// Appended to the chart's spoken label - "… against Christophe Heylen". Empty for a career
    /// record, where the subject is whoever's window this is and saying so would be noise.
    var accessibilityContext: String = ""

    // MARK: Derived

    /// **Counted here, never taken from a host.** `PlayerStats.games` includes games in progress and
    /// this ring cannot, so a total passed in from outside would eventually disagree with the sum of
    /// its own sectors - the one number in this view that must be true by construction.
    private var decided: Int { wins + draws + losses }

    /// **W-D-L in the subject's reading order**, the one the toolbar subtitle already uses, so the
    /// legend top-to-bottom and the donut clockwise both say what the record says.
    private var slices: [RecordSlice] {
        [
            RecordSlice(label: "Wins",   count: wins,   color: .green),
            RecordSlice(label: "Draws",  count: draws,  color: .gray),
            RecordSlice(label: "Losses", count: losses, color: .red)
        ]
    }

    /// The ring's thickness, from the same 0.62 inner ratio the chart uses - stated once so the
    /// empty arm's stroked circle lands exactly where the sectors would have.
    private var ringWidth: CGFloat { diameter / 2 * (1 - 0.62) }

    // MARK: Body

    var body: some View {
        VStack(spacing: 10) {
            // **Legend trailing, donut dead centre** (Bera, 18 Aug 2026 - it sat leading for one
            // pass). The two cannot both be had from a plain `HStack`: centring that centres the
            // *pair*, so the donut sits off-axis from whatever the host stacks above and below it by
            // half the legend's width.
            //
            // The empty leading slot is what buys it. Two identical `maxWidth: .infinity` frames
            // split the space either side of the fixed-width donut equally, so the donut lands on
            // the host's centre line whatever the legend measures - and the legend hangs at the
            // leading edge of its own slot, next to the chart it explains rather than adrift at the
            // far margin. The padding goes *inside* the flexible frame; put it outside and it widens
            // the trailing slot, which is the centring undone.
            HStack(spacing: 0) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)

                donut

                legend
                    .padding(.leading, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Both hosts need the qualifier and for different reasons - the Matchup tab can hide a
            // game in progress against this opponent, and the Performance tab's ring is one tab away
            // from a Games count that includes every unfinished one. Stated by the chart so neither
            // host can forget it.
            Text("Decided games only")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: Donut

    /// The record as one circle. A donut rather than a full pie: the hole is where the total goes,
    /// and a total that would otherwise need its own line is why this fits where a pie would not.
    private var donut: some View {
        ZStack {
            if decided > 0 {
                // Zero-count slices are dropped from the CHART only. A sector of angle zero still
                // carries the inset and the corner radius, which renders as a stray tick of colour
                // on the rim; the legend keeps all three rows, because "no draws" is worth printing.
                Chart(slices.filter { $0.count > 0 }) { slice in
                    SectorMark(
                        angle: .value(slice.label, slice.count),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .foregroundStyle(slice.color)
                    .cornerRadius(4)
                }
                .chartLegend(.hidden)
            } else {
                // Reachable, and only from the Performance tab: a player whose every game is still in
                // progress has a registry row, a rating of sorts, and nothing decided to draw. An
                // empty `Chart` would render as blank space where a ring belongs, which reads as a
                // failure rather than as a zero.
                Circle()
                    .strokeBorder(.quaternary, lineWidth: ringWidth)
            }

            VStack(spacing: 0) {
                Text("\(decided)")
                    .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                Text(decided == 1 ? "game" : "games")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: diameter, height: diameter)
        // One sentence for the whole chart: VoiceOver reading three unlabelled sectors is worse
        // than reading the record, which the legend then repeats in navigable rows.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
    }

    private var spokenSummary: String {
        let record = "\(wins) wins, \(draws) draws, \(losses) losses "
            + "in \(decided) decided games"
        return accessibilityContext.isEmpty ? record : record + " " + accessibilityContext
    }

    // MARK: Legend

    /// Swatch, label, count, share - a `Grid` so the counts and percentages line up in columns
    /// rather than drifting with the label widths.
    private var legend: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
            ForEach(slices) { slice in
                GridRow {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 10, height: 10)

                    Text(slice.label)
                        .font(.callout)

                    Text("\(slice.count)")
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .gridColumnAlignment(.trailing)

                    Text(share(slice.count))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                }
            }
        }
    }

    /// Rounded to whole percent, matching the stats grid's Win Rate. Three rounded shares need not
    /// sum to 100, which is a property of rounding rather than a defect to correct here - the counts
    /// beside them are the exact answer.
    private func share(_ count: Int) -> String {
        guard decided > 0 else { return "—" }
        return (Double(count) / Double(decided))
            .formatted(.percent.precision(.fractionLength(0)))
    }
}

// MARK: Previews

#Preview("Mixed Record") {
    RecordChart(wins: 53, draws: 3, losses: 47)
        .padding(28)
        .frame(width: 460)
}

/// **The no-draws arm**: the chart drops a slice and the legend keeps the row. The one preview that
/// checks the zero filter, and the reason the legend renders from the unfiltered list.
#Preview("No Draws") {
    RecordChart(wins: 7, draws: 0, losses: 2)
        .padding(28)
        .frame(width: 460)
}

/// Nothing decided - the stroked placeholder ring, reachable from a profile whose every game is
/// still in progress.
#Preview("Nothing Decided") {
    RecordChart(wins: 0, draws: 0, losses: 0)
        .padding(28)
        .frame(width: 460)
}

/// A narrow host at a reduced diameter, checking the legend still clears the donut.
#Preview("Compact") {
    RecordChart(wins: 12, draws: 3, losses: 8, diameter: 110)
        .padding(20)
        .frame(width: 330)
}
