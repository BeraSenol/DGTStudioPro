import SwiftUI

/// The Players icons grid — the Library grid's two Finder gestures; the shared grammar lives in
/// `IconGridSelection` (the half that must not fork).
struct PlayersIconsView: View {

    // MARK: Static Constants

    /// A coordinate-space name, not an identifier. `nonisolated` — `View` conformance infers
    /// @MainActor onto statics and the transform closure is `@Sendable`.
    private nonisolated static let gridSpace = "playersIconsGrid"

    // MARK: Stored Properties
    let players: [RankedPlayer]
    @Binding var selectedKeys: Set<PlayerStats.ID>
    let onShowInLibrary: (PlayerStats.ID) -> Void

    // MARK: Private Properties

    @Environment(CollectionViewOptions.self) private var options

    /// Card frames — a box, not observed state; **populated only while a band sweeps** (the Library
    /// grid's transform gate carries the account). Membership re-checked against `players`.
    @State private var cardFrames = IconGridFrameStore<PlayerStats.ID>()
    @State private var rubberBand: CGRect?
    /// The card the last gesture touched — where an arrow steps from.
    @State private var anchorKey: PlayerStats.ID?
    @FocusState private var isFocused: Bool

    // MARK: Body
    var body: some View {
        // One Bool for all transform closures — the Library grid's gate.
        let isSweeping = rubberBand != nil
        return GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(
                        columns: options.columns(containerWidth: geometry.size.width),
                        spacing: options.spacing
                    ) {
                        ForEach(players) { player in
                            // Rank always rides the card — rank is a fact about the player, not the sort.
                            PlayerCardView(
                                stats: player.stats,
                                isSelected: selectedKeys.contains(player.id),
                                onSelect: { select(player) },
                                rank: player.rank,
                                onShowInLibrary: { onShowInLibrary(player.id) }
                            )
                            .id(player.id)
                            .onGeometryChange(for: CGRect.self) { geometry in
                                // Gated on the sweep — the fifth cycling correction, shared with the Library grid.
                                isSweeping
                                ? IconGridSelection.stableFrame(
                                    geometry.frame(in: .named(Self.gridSpace))
                                )
                                : .null
                            } action: { frame in
                                // A box write: free, invisible to the render pass.
                                cardFrames.frames[player.id] = frame
                            }
                        }
                    }
                    .padding(CollectionViewOptions.inset)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Empty space or gutters — a card's own tap wins first.
                        selectedKeys.removeAll()
                        anchorKey = nil
                        isFocused = true
                    }
                    // Background menu on the same `contentShape` as the clear tap — covers the gutters (Finder's
                    // behaviour); a card's own menu wins over its bounds.
                    .contextMenu { ShowViewOptionsButton() }
                    .gesture(rubberBandGesture)
                    // Content-anchored — see the type doc.
                    .coordinateSpace(name: Self.gridSpace)
                    .overlay(alignment: .topLeading) {
                        if let band = rubberBand {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentColor.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1)
                                )
                                .frame(width: band.width, height: band.height)
                                .offset(x: band.minX, y: band.minY)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .focusable()
                .focusEffectDisabled()
                .focused($isFocused)
                // The proxy's own width, captured at key-press time.
                .onMoveCommand { direction in
                    move(direction, width: geometry.size.width, proxy: proxy)
                }
            }
        }
    }

    // MARK: Instance Methods

    private func select(_ player: RankedPlayer) {
        selectedKeys = [player.id]
        anchorKey = player.id
        isFocused = true
    }

    /// Sweeping replaces the selection (Finder's plain drag); the anchor follows.
    private var rubberBandGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.gridSpace))
            .onChanged { value in
                let band = IconGridSelection.selectionRect(from: value.startLocation, to: value.location)
                rubberBand = band
                let crossed = Set(
                    players
                        .filter { cardFrames.frames[$0.id]?.intersects(band) == true }
                        .map(\.id)
                )
                // The Library grid's guard, worth more here: `selectedKeys` is `@State` on a destination whose
                // body folds the whole Library.
                guard crossed != selectedKeys else { return }
                selectedKeys = crossed
                anchorKey = crossed.isEmpty ? nil : players.first { crossed.contains($0.id) }?.id
            }
            .onEnded { _ in
                rubberBand = nil
                isFocused = true
            }
    }

    private func move(_ direction: MoveCommandDirection, width: CGFloat, proxy: ScrollViewProxy) {
        guard !players.isEmpty else { return }
        let target: Int
        if let anchorKey, let current = players.firstIndex(where: { $0.id == anchorKey }) {
            target = IconGridSelection.destination(
                from: current,
                direction: direction,
                columnCount: options.columnCount(containerWidth: width),
                count: players.count
            )
        } else {
            // Nothing anchored: first arrow lands on the first card.
            target = 0
        }
        let player = players[target]
        selectedKeys = [player.id]
        anchorKey = player.id
        proxy.scrollTo(player.id)
    }
}

// MARK: Previews

#Preview("With Players") {
    @Previewable @State var selection: Set<PlayerStats.ID> = []

    PlayersIconsView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 420)
    .environment(PreviewFixtures.viewOptions())
}

/// Wide enough for a full row — the 860 is load-bearing (column count derives from it), making
/// two rows. Preselected with *two* cards, the state single-select could never render.
#Preview("Wraps To Two Rows, Multi") {
    @Previewable @State var selection: Set<PlayerStats.ID> = Set(
        PreviewFixtures.deepRankedPlayers().prefix(2).map(\.id)
    )

    PlayersIconsView(
        players: PreviewFixtures.deepRankedPlayers(),
        selectedKeys: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 860, height: 420)
    .environment(PreviewFixtures.viewOptions())
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PlayerStats.ID> = []

    PlayersIconsView(players: [], selectedKeys: $selection, onShowInLibrary: { _ in })
        .frame(width: 720, height: 420)
        .environment(PreviewFixtures.viewOptions())
}
