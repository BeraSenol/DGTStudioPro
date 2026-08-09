import SwiftUI

/// The Players icons grid, with the Library grid's two Finder gestures
/// since the Players selection went multi (2 Aug 2026): arrow keys walk the
/// grid from the last-touched card, and a click-drag from empty space
/// sweeps a rubber-band over the cards it crosses.
///
/// The scaffolding here restates `LibraryIconsView`'s on purpose — the
/// grammar the two grids must agree on (arrow stepping, band
/// normalization) lives once in `IconGridSelection`, while the plumbing
/// (frames, focus, gesture state) is per-view: the element types and cards
/// differ, and collapsing the remainder means a container generic over its
/// content, which two grids haven't earned. The `OpeningSection` em-dash
/// argument, applied to interaction code.
///
/// Same content-anchored coordinate space as the Library's, for the same
/// reason: viewport-anchored frames made every scroll tick rewrite every
/// frame ("Geometry action is cycling between duplicate values").
internal struct PlayersIconsView: View {

    // MARK: Static Constants

    /// A coordinate-space name, not an accessibility identifier — the
    /// registry governs the latter only. `nonisolated` for the
    /// `LibraryIconsView.gridSpace` reason: `View` conformance infers
    /// `@MainActor` onto statics, and the geometry transform closure is
    /// `@Sendable`.
    private nonisolated static let gridSpace = "playersIconsGrid"

    // MARK: Stored Properties
    let players: [RankedPlayer]
    @Binding var selectedKeys: Set<PlayerStats.ID>
    let onShowInLibrary: (PlayerStats.ID) -> Void

    // MARK: Private Properties

    @Environment(CollectionViewOptions.self) private var options

    // The `IconGridWidthBox` mirror stood here from 7 Aug 2026 to 8 Aug 2026
    // — deleted with the type for the Library grid's reason: `.onMoveCommand`
    // is inside the `GeometryReader`'s scope, so `move` takes the width as a
    // parameter and the mirror never needed to exist.

    /// Realized cards' frames in `gridSpace` — a box, not observed state
    /// (see `IconGridFrameStore`); the sweep re-checks membership against
    /// `players` rather than trusting the keys. **Populated only while a band
    /// is sweeping** (8 Aug 2026) — the Library grid's transform gate, and
    /// its comment carries the account.
    @State private var cardFrames = IconGridFrameStore<PlayerStats.ID>()
    @State private var rubberBand: CGRect?
    /// The card the last selection gesture touched — where an arrow steps
    /// from.
    @State private var anchorKey: PlayerStats.ID?
    @FocusState private var isFocused: Bool

    // MARK: Body
    var body: some View {
        // One Bool for all the transform closures — the Library grid's gate.
        let isSweeping = rubberBand != nil
        return GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(
                        columns: options.columns(containerWidth: geometry.size.width),
                        spacing: options.spacing
                    ) {
                        ForEach(players) { player in
                            // Rank always rides the card (D48′) — in name order
                            // too, because the rank is a fact about the player,
                            // not about the current sort.
                            PlayerCardView(
                                stats: player.stats,
                                isSelected: selectedKeys.contains(player.id),
                                onSelect: { select(player) },
                                rank: player.rank,
                                onShowInLibrary: { onShowInLibrary(player.id) }
                            )
                            .id(player.id)
                            .onGeometryChange(for: CGRect.self) { geometry in
                                // Gated on the sweep — the fifth correction on
                                // the cycling warning, shared with the Library
                                // grid, whose transform comment carries the
                                // whole account: idle returns one constant, so
                                // launch wobble has no value stream to cycle.
                                isSweeping
                                ? IconGridSelection.stableFrame(
                                    geometry.frame(in: .named(Self.gridSpace))
                                )
                                : .null
                            } action: { frame in
                                // A box write: free, and invisible to the
                                // render pass — no invalidation, no loop.
                                cardFrames.frames[player.id] = frame
                            }
                        }
                    }
                    .padding(CollectionViewOptions.inset)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Empty space, or the gutters between cards — a card's
                        // own tap wins before this fires.
                        selectedKeys.removeAll()
                        anchorKey = nil
                        isFocused = true
                    }
                    // The background's own context menu (7 Aug 2026). It sits
                    // on the same `contentShape` the clear-selection tap uses, so
                    // it covers the gutters too — a right-click *between* cards is
                    // a background right-click, which is what Finder does and what
                    // a reader trying to reach this will actually aim at. A card's
                    // own menu wins over its own bounds, so the two never compete.
                    .contextMenu { ShowViewOptionsButton() }
                    .gesture(rubberBandGesture)
                    // Content-anchored, deliberately — see the type doc.
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
                // The Library grid's arrangement: the proxy's own width,
                // captured at key-press time. The width box and its geometry
                // action stood here until 8 Aug 2026.
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

    /// Sweeping replaces the selection with the crossed cards — Finder's
    /// plain drag; the anchor follows the sweep.
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
                // The Library grid's guard, and it bought more here — see
                // `LibraryIconsView` for the argument. `selectedKeys` is
                // `@State` on `PlayersDestination`, whose body folds the whole
                // Library, so every frame of a sweep that crossed nothing new
                // used to re-run `Glicko1.histories` and `PlayerStats.index`.
                // The memo took most of that; this takes the rest of the
                // render.
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
            // Nothing anchored: the first arrow lands on the first card.
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

/// Wide enough for a full row — wrapping only shows itself with more players
/// than one row holds. The column count is derived from this frame's width
/// and the View Options icon size, so the 860 here is load-bearing: it is
/// what makes this preview show two rows rather than one.
/// Preselected with *two* cards, the state the single-select grid could
/// never render.
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
