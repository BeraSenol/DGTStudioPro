import SwiftUI

struct PlayersGalleryView: View {

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

    private var selectedPlayer: RankedPlayer? {
        guard let key = selectedKeys.first else { return nil }
        return players.first { $0.id == key }
    }
    
    /// The gallery itself is the focusable; a card click hands it focus, ← / → step the strip.
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            preview
            Divider()
            filmstrip
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onMoveCommand { direction in
            move(direction)
        }
        // The whole gallery is the background target - a gallery has almost no empty space to aim at.
        // Card menus still win over their own bounds.
        .contextMenu { ShowViewOptionsButton() }
    }

    /// ← / → step, ↑ / ↓ hold - the shared grammar's one-row degenerate case; the previewed card is
    /// the anchor.
    private func move(_ direction: MoveCommandDirection) {
        guard !players.isEmpty else { return }
        let target: Int
        if let key = selectedKeys.first,
           let current = players.firstIndex(where: { $0.id == key }) {
            target = IconGridSelection.destination(
                from: current,
                direction: direction,
                columnCount: players.count,
                count: players.count
            )
        } else {
            target = 0
        }
        selectedKeys = [players[target].id]
    }
    
    /// Selection-driven, no `players.first` fallback - "never preview what the user didn't pick"
    /// (the Library's rule, closing the last gallery parity residue).
    @ViewBuilder
    private var preview: some View {
        if let player = selectedPlayer {
            // Scrolls only when it must. The preview grew a third tier with the profile band, and a
            // centred VStack that outgrows its host clips at both ends rather than at the bottom -
            // the failure would hide the monogram, not the new content.
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

                    // The same line the inspector draws (`RatingTrendChart` - one chart, two hosts). Gated on
                    // having something to draw.
                    if !history.isEmpty {
                        // Width capped; height is the chart's own, stated once inside it.
                        RatingTrendChart(history: history)
                            .frame(maxWidth: 460)
                            .padding(.top, 8)
                    }

                    profileBand(for: player)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
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

    /// The three panels the gallery has that the inspector doesn't - what "the gallery goes deeper"
    /// actually means. Folded here rather than in the destination because both answers are about the
    /// current selection, which only this view knows.
    ///
    /// Capped at 620 to sit under the 460-wide chart without the outer two panels drifting to the
    /// window's edges on a wide display: the band should read as one block below the chart, not as
    /// three things pinned to the corners.
    @ViewBuilder
    private func profileBand(for player: RankedPlayer) -> some View {
        let key = player.stats.key

        HStack(alignment: .top, spacing: 32) {
            PlayerColourSplitPanel(stats: player.stats)
            PlayerFormPanel(form: PlayerStats.form(of: key, in: records))
            PlayerOpponentsPanel(opponents: PlayerStats.opponents(of: key, in: records))
        }
        .frame(maxWidth: 620)
        .padding(.top, 16)
    }

    private var filmstrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(players) { player in
                        PlayerCardView(
                            stats: player.stats,
                            isSelected: selectedKeys.contains(player.id),
                            onSelect: { selectedKeys = [player.id]; isFocused = true },
                            rank: player.rank,
                            onShowInLibrary: { onShowInLibrary(player.id) }
                        )
                        .frame(width: 160)
                        .id(player.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 170)
            .background(.thinMaterial)
            .onChange(of: selectedKeys) { _, newKeys in
                guard let key = newKeys.first else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(key, anchor: .center)
                }
            }
        }
    }
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

/// The full preview pane: eight-fact grid, trend, and the three profile panels - the height check
/// that the filmstrip stays pinned, and the only canvas where the band renders with content.
/// `records` is the same fixture the ladder was folded from, so the panels agree with the grid
/// above them rather than describing a different player.
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
