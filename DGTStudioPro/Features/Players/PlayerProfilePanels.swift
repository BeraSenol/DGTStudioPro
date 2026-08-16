import SwiftUI

/// The three panels below the gallery preview's rating chart (13 Aug 2026).
///
/// These exist because the gallery and the inspector had converged: the same eight facts and the
/// same rating line, side by side, with the inspector adding only Recent Games. Rather than widen
/// both, the gallery goes deeper - it is the full-window read, the inspector stays the compact
/// reference, and the "each fact once" is honoured *within* a surface rather than across the
/// window.
///
/// Deliberately not added to `PlayerStatsGrid`: that type is shared with the columns detail pane,
/// which is a side panel beside a group list and has no room for three more blocks. A shared grid
/// that grew here would push the columns pane into scrolling to serve a host that isn't it.

// MARK: - By Colour

/// The white/black split, which is the only genuinely unrendered data the app had: `PlayerStats`
/// has stored `whiteWins`/`whiteDraws`/`whiteLosses` and their black twins since it was written,
/// folded on every render, and every surface collapsed them into one Record. "Do I do better as
/// White" is a question the archive could always answer and nothing asked.
///
/// Special Mates rides here rather than beside Mates in the grid because it is a *subset* of that
/// count, and two adjacent totals where one contains the other read as unrelated. Its own open
/// item is why it is labelled rather than merged: the motif classifier spells mate `contains("#")`
/// while `matesDelivered` spells it `hasSuffix("#")`, so this number can legitimately exceed the
/// Mates figure one panel over, and a reader who spots that deserves two labels rather than one
/// number that looks wrong.
struct PlayerColourSplitPanel: View {

    let stats: PlayerStats

    var body: some View {
        ProfilePanel("By Colour") {
            VStack(alignment: .leading, spacing: 6) {
                row("As White", wins: stats.whiteWins, draws: stats.whiteDraws, losses: stats.whiteLosses)
                row("As Black", wins: stats.blackWins, draws: stats.blackDraws, losses: stats.blackLosses)

                if stats.specialMatesDelivered > 0 {
                    Divider().padding(.vertical, 2)
                    LabeledContent("Special Mates") {
                        Text("\(stats.specialMatesDelivered)")
                            .font(.callout.monospacedDigit())
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// The seat's own win rate, not the player's - a split that repeated the overall percentage
    /// twice would be two labels over one fact.
    private func row(_ label: String, wins: Int, draws: Int, losses: Int) -> some View {
        let decided = wins + draws + losses
        return LabeledContent {
            HStack(spacing: 8) {
                Text("\(wins)–\(draws)–\(losses)")
                    .font(.callout.monospacedDigit())
                Text(
                    decided > 0
                        ? (Double(wins) / Double(decided))
                            .formatted(.percent.precision(.fractionLength(0)))
                        : RosterSummary.displayUnknown
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
            }
        } label: {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Form

/// The last ten decided results, oldest to newest. The one panel here that shows a *shape* rather
/// than a number - a slump and a streak read identically in a 38–2–26 record and are the whole
/// point of looking.
///
/// Reading order is the fold's, not the view's: `PlayerStats.form` returns oldest-first precisely
/// so this renders straight and cannot be reversed twice.
struct PlayerFormPanel: View {

    let form: [PlayerStats.Outcome]

    var body: some View {
        ProfilePanel("Recent Form") {
            if form.isEmpty {
                Text(RosterSummary.displayUnknown)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        // Index-keyed: outcomes are values and repeat constantly, so the value cannot
                        // be the identity - ten wins would collapse to one pip.
                        //
                        // `indices`, not an enumerated pair keyed by its element: `Outcome` is a value
                        // with three cases over a ten-slot strip, so element-as-identity collapses a
                        // run of wins to one pip. `AnalysisQueueStatusWindowView` keys that way
                        // legitimately - its elements are `PersistentIdentifier`s, which are unique.
                        ForEach(form.indices, id: \.self) { index in
                            pip(form[index])
                        }
                    }
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recent form")
        .accessibilityValue(form.isEmpty ? "No decided games" : summary)
    }

    private var summary: String {
        let wins = form.filter { $0 == .win }.count
        let draws = form.filter { $0 == .draw }.count
        let losses = form.filter { $0 == .loss }.count
        return "Last \(form.count): \(wins)–\(draws)–\(losses)"
    }

    /// Colour *and* letter, deliberately: a red/green pip strip is unreadable to the most common
    /// form of colour blindness, and this is the one panel with no numbers to fall back on.
    private func pip(_ outcome: PlayerStats.Outcome) -> some View {
        let letter: String
        let tint: Color
        switch outcome {
        case .win:  letter = "W"; tint = .green
        case .draw: letter = "D"; tint = .secondary
        case .loss: letter = "L"; tint = .red
        }

        return Text(letter)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(tint.opacity(0.85), in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Opponents

/// Who this player actually plays, most-played first. The rivalry the head-to-head toolbar line
/// (`DestinationSubtitle`) can only show for a two-player selection, available for one.
struct PlayerOpponentsPanel: View {

    let opponents: [PlayerStats.Opponent]
    /// Four rows fits the band beside the other two panels without scrolling. A scroller here would
    /// put a second scrollable region on a surface whose filmstrip already owns that gesture.
    var limit: Int = 4

    var body: some View {
        ProfilePanel("Opponents") {
            if opponents.isEmpty {
                Text(RosterSummary.displayUnknown)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(opponents.prefix(limit)) { opponent in
                        LabeledContent {
                            Text("\(opponent.wins)–\(opponent.draws)–\(opponent.losses)")
                                .font(.callout.monospacedDigit())
                        } label: {
                            // Rendered raw, like every other `stats.name` site: `GameRecord.Side.name`
                            // carries `Player.name`, which `resolvePlayer` already put through the                             // transform. Re-applying it here would be a no-op that implies otherwise.
                            Text(opponent.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }

                    if opponents.count > limit {
                        Text("and \(opponents.count - limit) more")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Shared chrome

/// One titled block. The three panels sit in a row and must agree on title weight, spacing and
/// minimum width or the band reads as three unrelated widgets - the `InspectorSectionHeader`
/// argument at a smaller scale.
private struct ProfilePanel<Content: View>: View {

    private let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
            content
            Spacer(minLength: 0)
        }
        .frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#Preview("By Colour") {
    PlayerColourSplitPanel(stats: PreviewFixtures.topStats())
        .padding()
        .frame(width: 220)
}

/// Every outcome and the empty arm - the branches a real fixture reaches only by accident.
#Preview("Form - Every Arity") {
    VStack(alignment: .leading, spacing: 24) {
        PlayerFormPanel(form: [.win, .win, .draw, .loss, .win, .loss, .draw, .win, .win, .win])
        PlayerFormPanel(form: [.loss, .loss, .loss])
        PlayerFormPanel(form: [])
    }
    .padding()
    .frame(width: 260)
}

#Preview("Opponents") {
    VStack(alignment: .leading, spacing: 24) {
        PlayerOpponentsPanel(opponents: [
            .init(key: "heylen, christophe", name: "Christophe Heylen", wins: 21, draws: 1, losses: 12),
            .init(key: "baelus, lorenzo", name: "Lorenzo Baelus", wins: 8, draws: 0, losses: 5),
            .init(key: "brouns, reinaud", name: "Reinaud Brouns", wins: 6, draws: 2, losses: 3),
            .init(key: "vanmullem, marco", name: "Marco Vanmullem", wins: 3, draws: 0, losses: 1),
            .init(key: "leben, brecht", name: "Brecht Leben", wins: 2, draws: 0, losses: 1),
        ])
        PlayerOpponentsPanel(opponents: [])
    }
    .padding()
    .frame(width: 260)
}

/// The band as the gallery renders it - the check that three panels of different natural heights
/// still align on their titles.
#Preview("The Band") {
    HStack(alignment: .top, spacing: 32) {
        PlayerColourSplitPanel(stats: PreviewFixtures.topStats())
        PlayerFormPanel(form: [.win, .draw, .loss, .win, .win])
        PlayerOpponentsPanel(opponents: [
            .init(key: "heylen, christophe", name: "Christophe Heylen", wins: 21, draws: 1, losses: 12),
            .init(key: "baelus, lorenzo", name: "Lorenzo Baelus", wins: 8, draws: 0, losses: 5),
        ])
    }
    .padding()
    .frame(width: 620)
}
