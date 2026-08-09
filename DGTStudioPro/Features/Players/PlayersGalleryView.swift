import SwiftUI

internal struct PlayersGalleryView: View {

    let players: [RankedPlayer]
    /// A set (shared model); the gallery stays one-at-a-time by gesture and previews the *first*
    /// of a plural selection, as the Library gallery does.
    @Binding var selectedKeys: Set<PlayerStats.ID>

    /// The sole selection's rating history for the preview's trend chart — the destination already
    /// resolves it for the inspector.
    let history: [Glicko1.Sample]
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
        // The whole gallery is the background target — a gallery has almost no empty space to aim at.
        // Card menus still win over their own bounds.
        .contextMenu { ShowViewOptionsButton() }
    }

    /// ← / → step, ↑ / ↓ hold — the shared grammar's one-row degenerate case; the previewed card is
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
    
    /// Selection-driven, no `players.first` fallback — "never preview what the user didn't pick"
    /// (the Library's rule, closing the last gallery parity residue).
    @ViewBuilder
    private var preview: some View {
        if let player = selectedPlayer {
            VStack(spacing: 12) {
                PlayerMonogram(name: player.stats.name, diameter: 96)
                HStack(spacing: 8) {
                    // The rank earns the medal styling beside the name (D48′).
                    Text("#\(player.rank)")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(RankMedal.style(forRank: player.rank))
                    Text(player.stats.name)
                        .font(.title2.weight(.semibold))
                }

                // One grid, each fact once (D48′), shared so both hosts widen together.
                PlayerStatsGrid(stats: player.stats, rating: player.rating)
                    .padding(.top, 4)

                // The same line the inspector draws (`RatingTrendChart` — one chart, two hosts). Gated on
                // having something to draw.
                if !history.isEmpty {
                    // Width capped; height is the chart's own, stated once inside it.
                    RatingTrendChart(history: history)
                        .frame(maxWidth: 460)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "person.crop.circle.dashed",
                description: Text("Select a player to preview.")
            )
            // The greedy frame is load-bearing: it pins the filmstrip to the window's bottom edge — a
            // branch nobody has rendered has layout nobody has checked.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 420)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PlayerStats.ID> = []

    PlayersGalleryView(players: [], selectedKeys: $selection, history: [], onShowInLibrary: { _ in })
        .frame(width: 720, height: 420)
}

/// The full preview pane: eight-fact grid plus trend — the height check that the filmstrip
/// stays pinned.
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
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 560)
}
