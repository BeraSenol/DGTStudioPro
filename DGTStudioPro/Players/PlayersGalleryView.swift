import SwiftUI

internal struct PlayersGalleryView: View {
    
    let players: [RankedPlayer]
    /// A set since 2 Aug 2026 (the shared selection model). The gallery
    /// remains a one-at-a-time surface by gesture — thumbnails select
    /// singly — and previews the *first* of a plural selection, as the
    /// Library gallery does.
    @Binding var selectedKeys: Set<PlayerStats.ID>
    let onShowInLibrary: (PlayerStats.ID) -> Void

    private var selectedPlayer: RankedPlayer? {
        guard let key = selectedKeys.first else { return nil }
        return players.first { $0.id == key }
    }
    
    /// The grids' focus arrangement (4 Aug 2026): the gallery itself is the
    /// focusable, a card click hands it focus, and ← / → step the strip.
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
    }

    /// ← / → step the filmstrip; ↑ / ↓ hold — `LibraryGalleryView.move`'s
    /// twin, and the reasoning lives there: the shared grammar's one-row
    /// degenerate case (`columnCount == count`), the previewed card as the
    /// anchor, first arrow lands on the first card.
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
    
    /// Selection-driven with no fallback to `players.first` since 4 Aug 2026
    /// — the Library gallery's rule ("never preview what the user didn't
    /// pick"), adopted here to close the last gallery parity residue: the two
    /// galleries answered empty selection opposite ways, each documented as
    /// correct. The placeholder below was unreachable in production before
    /// this (the destination gates on an empty registry); it is now the
    /// honest unselected state.
    @ViewBuilder
    private var preview: some View {
        if let player = selectedPlayer {
            VStack(spacing: 12) {
                PlayerMonogram(name: player.stats.name, diameter: 96)
                HStack(spacing: 8) {
                    // The retired Rankings gallery's identity row, kept: the
                    // rank is the destination's default sort and earns the
                    // medal styling beside the name.
                    Text("#\(player.rank)")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(RankMedal.style(forRank: player.rank))
                    Text(player.stats.name)
                        .font(.title2.weight(.semibold))
                }

                // One grid, each fact once (D48′), shared since the columns
                // redesign made a second host — see `PlayerStatsGrid` for
                // the history this extraction closes.
                PlayerStatsGrid(stats: player.stats, rating: player.rating)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "person.crop.circle.dashed",
                description: Text("Select a player to preview.")
            )
            // The greedy frame is load-bearing, not styling: it is what
            // pins the filmstrip to the window's bottom edge. The selected
            // arm carries the same frame on its VStack; without it here the
            // gallery collapses to intrinsic height, centers, and the strip
            // floats mid-window — seen on this arm's *first production
            // render* (4 Aug 2026), minutes after the parity close made it
            // reachable. A branch nobody has rendered has layout nobody has
            // checked, no matter how plain it looks.
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
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 420)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PlayerStats.ID> = []

    PlayersGalleryView(players: [], selectedKeys: $selection, onShowInLibrary: { _ in })
        .frame(width: 720, height: 420)
}

#Preview("Gallery — Preselected") {
    @Previewable @State var selection: Set<PlayerStats.ID> = [PreviewFixtures.topStats().id]

    PlayersGalleryView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 420)
}
