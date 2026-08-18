import SwiftUI

/// The Players gallery: a profile preview of the selected player over a filmstrip of cards. The
/// scaffold is `FilmstripGalleryView`'s (the Library gallery's twin, shared since 18 Aug 2026);
/// what is here is the preview pane, which is the whole point of each gallery and the one part
/// that was never the same.
struct PlayersGalleryView: View {

    // MARK: Stored Properties

    let players: [RankedPlayer]
    /// A set (shared model); the gallery stays one-at-a-time by gesture and previews the *first*
    /// of a plural selection, as the Library gallery does.
    @Binding var selectedKeys: Set<PlayerStats.ID>

    /// The sole selection's rating history for the preview's trend chart - the destination already
    /// resolves it for the inspector.
    let history: [Glicko1.Sample]

    /// Every record, for the opponents and form folds. Taken rather than pre-folded because both
    /// answers are per-*selection*: the destination would have to fold for a player it does not yet
    /// know, or fold for all of them to serve one. It already holds this array - `fold.records`,
    /// computed once per body - so passing it costs a reference.
    ///
    /// Cost, stated rather than discovered: two O(records) folds per render while a player is
    /// selected. Same order as the `Glicko1.histories` fold this surface already pays, and it joins
    /// the known-costs census rather than being optimised ahead of M7's measurement.
    let records: [GameRecord]

    let onShowInLibrary: (PlayerStats.ID) -> Void
    /// Double-click's door - the matchup window (17 Aug 2026). Defaulted so previews stand.
    var onOpenMatchup: (PlayerStats.ID) -> Void = { _ in }

    // MARK: Private Properties

    private var selectedPlayer: RankedPlayer? {
        guard let key = selectedKeys.first else { return nil }
        return players.first { $0.id == key }
    }

    // MARK: Body
    var body: some View {
        FilmstripGalleryView(
            items: players,
            selection: $selectedKeys,
            metrics: .players
        ) {
            preview
        } card: { player, isSelected, select in
            PlayerCardView(
                stats: player.stats,
                isSelected: isSelected,
                onSelect: select,
                rank: player.rank,
                rating: player.rating,
                onShowInLibrary: { onShowInLibrary(player.id) },
                onOpen: { onOpenMatchup(player.id) }
            )
        }
    }

    /// Selection-driven, no `players.first` fallback - "never preview what the user didn't pick"
    /// (the Library's rule, closing the last gallery parity residue).
    @ViewBuilder
    private var preview: some View {
        if let player = selectedPlayer {
            // Scrolls only when it must. The preview grew a third tier with the profile band, and a
            // centred VStack that outgrows its host clips at both ends rather than at the bottom -
            // the failure would hide the monogram, not the new content.
            // Vertically centred when the content is shorter than the viewport (17 Aug 2026,
            // by request) - the viewport height becomes the minimum; taller content scrolls
            // exactly as before, clipping at both ends per the original reasoning.
            GeometryReader { pane in
                ScrollView(.vertical) {
                    VStack(spacing: 12) {
                        PlayerMonogram(name: player.stats.name, side: 96)
                        HStack(spacing: 8) {
                            // The rank earns the medal styling beside the name.
                            Text("#\(player.rank)")
                                .font(.title2.weight(.bold).monospacedDigit())
                                .foregroundStyle(RankMedal.style(forRank: player.rank))
                            Text(player.stats.name)
                                .font(.title2.weight(.semibold))
                        }

                        // One grid, each fact once, shared so both hosts widen together.
                        PlayerStatsGrid(stats: player.stats, rating: player.rating)
                            .padding(.top, 4)

                        // The same line the inspector draws (`RatingTrendChart` - one chart, two
                        // hosts). Gated on having something to draw.
                        if !history.isEmpty {
                            // Width capped; height is the chart's own, stated once inside it.
                            RatingTrendChart(history: history)
                                .frame(maxWidth: 460)
                                .padding(.top, 8)
                        }

                        // The matchup band (17 Aug 2026, by request): the head-to-head content
                        // replaced Recent Form / By Colour / Opponents wholesale - the same
                        // `PlayerMatchupView` the double-click window shows, so the two surfaces
                        // cannot drift. `.id` resets the opponent selection when the subject
                        // changes; without it the previous player's opponent lingers.
                        PlayerMatchupView(
                            playerKey: player.stats.key,
                            playerName: player.stats.name,
                            records: records
                        )
                        .id(player.stats.key)
                        .frame(maxWidth: 620)
                        .padding(.top, 16)
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, minHeight: pane.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "person.crop.circle.dashed",
                description: Text("Select a player to preview.")
            )
            // The greedy frame is load-bearing: it pins the filmstrip to the window's bottom edge - a
            // branch nobody has rendered has layout nobody has checked.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // (`profileBand` stood here until 17 Aug 2026 - Recent Form / By Colour / Opponents,
    // replaced by request with the matchup band above. The three panels briefly moved to the
    // matchup window's Profile tab and were deleted from there the same evening, also by
    // request - they now stand in `PlayerProfilePanels` with no consumer, and whether they
    // retire is a decision for a calmer day, not this edit's rider.)
}

// MARK: Previews

#Preview("With Players") {
    @Previewable @State var selection: Set<PlayerStats.ID> = []

    PlayersGalleryView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        history: [],
        records: [],
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 420)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PlayerStats.ID> = []

    PlayersGalleryView(
        players: [], selectedKeys: $selection, history: [], records: [],
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 420)
}

/// The full preview pane: eight-fact grid, trend, and the matchup band - the height check that the
/// filmstrip stays pinned, and the only canvas where the band renders with content. `records` is
/// the same fixture the ladder was folded from, so the band agrees with the grid above it rather
/// than describing a different player.
#Preview("Gallery, Preselected") {
    @Previewable @State var selection: Set<PlayerStats.ID> = [PreviewFixtures.topStats().id]

    let history = (0..<9).map { step in
        Glicko1.Sample(
            date: Date(timeIntervalSinceReferenceDate: Double(step) * 86_400),
            rating: Glicko1.Rating(
                mean: 1500 + Double(step) * 14 - (step.isMultiple(of: 3) ? 40 : 0),
                deviation: max(60, 350 - Double(step) * 30)
            )
        )
    }

    PlayersGalleryView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        history: history,
        records: PreviewFixtures.records(),
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 640)
}
