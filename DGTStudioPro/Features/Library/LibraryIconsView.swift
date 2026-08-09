import SwiftData
import SwiftUI

/// The icons grid, with Finder's two selection gestures since 2 Aug 2026:
/// arrow keys walk the grid from the last-touched card, and a click-drag
/// from anywhere sweeps a rubber-band rectangle over the cards it crosses.
///
/// **Keyboard.** The grid itself is the focusable — cards stay
/// plain-clickable and a card click hands the grid focus, so arrows work
/// immediately after any selection. Index math, not geometry: left/right are
/// ±1 in reading order (wrapping rows, as Finder reads) and up/down are
/// ±columnCount, with Finder's edge grammar — top row holds on up, a
/// bottom-row overflow lands on the last card. The stepping is
/// `IconGridSelection.destination` — shared with the Players grid, suited
/// once.
///
/// **The column count stopped being a constant on 7 Aug 2026** (it was
/// `CollectionGridMetrics.columnCount`, a hard 6) and is now derived from the
/// container width and the View Options icon size. The index math is
/// unchanged — what changed is where its one input comes from, and the reason
/// the grid is *not* `.adaptive`: SwiftUI never reports the count an adaptive
/// grid chose, so the arrows would step by a number the layout had no reason
/// to agree with. Layout and the arrow keys both read the `GeometryReader`'s
/// own width — the keys through a `move(_:width:proxy:)` parameter since
/// 8 Aug 2026, which retired the mirrored width box.
///
/// **Rubber band.** Cards report frames via `onGeometryChange` into an
/// `IconGridFrameStore` — a reference box, not `@State`, because nothing in
/// `body` renders from the frames and a write that invalidates the view
/// re-enters layout. That loop is what Console's "Geometry action is cycling
/// between duplicate values" reported; re-anchoring the coordinate space from
/// the viewport to the grid content did not end it (kept anyway — a frame
/// should be a fact about layout, not scroll offset), because the observer
/// itself was the oscillator. A store the render pass cannot see ends it
/// structurally. The space, the drag's coordinates and the band overlay all
/// speak the content system, and selection *replaces* while sweeping.
///
/// Accepted limit: `LazyVGrid` realizes only cells near the viewport, so a
/// sweep reaches only cards that have existed. At personal scale the grid
/// realizes generously and the drag does not autoscroll, so the reachable cards
/// are the realized ones anyway.
///
/// A click on empty grid space clears the selection — Finder again; card
/// clicks never reach the container (child gestures win), and the drag
/// needs 4 pt before it counts, so plain clicks stay clicks.
internal struct LibraryIconsView: View {

    // MARK: Static Constants

    /// The named space the frames and the drag rectangle share. A
    /// coordinate-space name, not an accessibility identifier — the
    /// registry governs the latter only. `nonisolated` because `View`
    /// conformance infers `@MainActor` onto the type's statics while
    /// `onGeometryChange`'s transform closure is `@Sendable`; a deeply
    /// immutable `String` needs no isolation, and this is the
    /// seven-characters-of-isolation answer rather than an opt-out.
    private nonisolated static let gridSpace = "libraryIconsGrid"

    // MARK: Stored Properties
    let games: [PGN]
    /// Which of `games` count as analyzed, read off the destination's memoized
    /// projection (D72′) — never off the models, so a card render costs no
    /// blob decode. The set is rebuilt per render from records already in the
    /// fold cache; membership here plus the ambient running id is the whole
    /// input to every card's badge.
    let analyzedIDs: Set<PGN.ID>
    @Binding var selectedPGNs: Set<PGN.ID>
    /// Takes the set since D56′ — see `open(_:)` for the rule this grid
    /// applies before calling it.
    let onOpen: ([PGN]) -> Void
    let onAnalyze: (PGN) -> Void
    let onExport: (PGN) -> Void
    let onDelete: (PGN) -> Void

    // MARK: Private Properties

    @Environment(CollectionViewOptions.self) private var options

    /// Ambient, written once by `LibraryDestination` — the badge needs it to
    /// tell "analyzed" from "on the engine right now". Argued at the
    /// environment value's declaration; nil in the previews, which is honest.
    @Environment(\.analysisRunningGameID) private var runningAnalysisID

    // `containerWidth` (an `IconGridWidthBox`) stood here from 7 Aug 2026 to
    // 8 Aug 2026 — a box mirroring the `GeometryReader`'s width out to the
    // arrow keys, with a quantized geometry action feeding it. Deleted with
    // the type: `.onMoveCommand` sits *inside* the `GeometryReader`'s scope,
    // so `move` takes `geometry.size.width` as a parameter and the mirror
    // never needed to exist. It was also one of the two suspects for the
    // launch-time "Geometry action is cycling between duplicate values"
    // warning, now gone by construction rather than by tuning.

    /// Realized cards' frames in `gridSpace` — see `IconGridFrameStore`
    /// for why this is a box and not observed state. Entries for deleted
    /// games go stale until their cell vanishes, so the sweep re-checks
    /// membership against `games` rather than trusting the keys.
    ///
    /// **Populated only while a band is sweeping** (8 Aug 2026, the fifth
    /// correction on the cycling warning — see the transform at the card).
    /// Empty at launch and between drags, which is honest: nothing reads it
    /// then.
    @State private var cardFrames = IconGridFrameStore<PGN.ID>()
    @State private var rubberBand: CGRect?
    /// The card the last selection gesture touched — where an arrow steps
    /// from.
    @State private var anchorID: PGN.ID?
    @FocusState private var isFocused: Bool

    // MARK: Body
    var body: some View {
        // Read once per render, ahead of the `ForEach`, so sixty transform
        // closures capture one Bool rather than sixty `@State` reads.
        let isSweeping = rubberBand != nil
        return GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(
                        columns: options.columns(containerWidth: geometry.size.width),
                        spacing: options.spacing
                    ) {
                        ForEach(games) { game in
                            LibraryGameCardView(
                                game: game,
                                glyphWidth: options.glyphWidth,
                                analysisState: AnalysisGlyph.state(
                                    of: game,
                                    isAnalyzed: analyzedIDs.contains(game.id),
                                    runningID: runningAnalysisID
                                ),
                                isSelected: selectedPGNs.contains(game.id),
                                onSelect:  { select(game) },
                                onOpen:    { open(game) },
                                onAnalyze: { onAnalyze(game) },
                                onExport:  { onExport(game) },
                                onDelete:  { onDelete(game) }
                            )
                            .id(game.id)
                            .onGeometryChange(for: CGRect.self) { geometry in
                                // **Gated on the sweep — the fifth correction
                                // on "cycling between duplicate values", and
                                // the first that removes the observation
                                // instead of tuning it** (8 Aug 2026; the
                                // account of all five lives on
                                // `IconGridSelection.stableFrame`). Idle, the
                                // transform returns one constant, so there is
                                // no value stream to cycle however layout
                                // wobbles at launch. The frames are only ever
                                // read mid-drag, and the drag's first
                                // `onChanged` sets `rubberBand`, which
                                // re-renders this grid, rebuilds these
                                // transforms with `isSweeping` true, and
                                // populates the box in the same layout pass —
                                // so the band's second callback tests real
                                // frames, which is Finder's own feel (the
                                // first 4 pt of a sweep select nothing).
                                isSweeping
                                ? IconGridSelection.stableFrame(
                                    geometry.frame(in: .named(Self.gridSpace))
                                )
                                : .null
                            } action: { frame in
                                // A box write: free, and invisible to the
                                // render pass — no invalidation, no loop.
                                // `.null` lands here once per card when a
                                // sweep ends; harmless, `.null` intersects
                                // nothing.
                                cardFrames.frames[game.id] = frame
                            }
                        }
                    }
                    .padding(CollectionViewOptions.inset)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Empty space, or the gutters between cards — a card's
                        // own tap wins before this fires.
                        selectedPGNs.removeAll()
                        anchorID = nil
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
                    // Content-anchored, deliberately: see the rubber-band doc
                    // above. The space, the gesture's coordinates and the band
                    // overlay all live on this container, inside the scroll.
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
                // `geometry.size.width` directly — the same proxy the layout
                // reads, captured at key-press time when layout has long
                // settled. The width box and its geometry action stood here
                // until 8 Aug 2026; see the note at the retired property.
                .onMoveCommand { direction in
                    move(direction, width: geometry.size.width, proxy: proxy)
                }
            }
        }
    }

    // MARK: Instance Methods

    private func select(_ game: PGN) {
        selectedPGNs = [game.id]
        anchorID = game.id
        isFocused = true
    }

    /// Finder's double-click rule, which `LibraryListView` gets free from
    /// `primaryAction` and this grid has to spell (D56′): double-clicking a card
    /// that is **part of a multi-selection** opens the whole selection;
    /// double-clicking anything else opens just it.
    ///
    /// Spelled rather than skipped because the alternative is the divergence
    /// this project keeps finding — right-clicking a rubber-banded sweep and
    /// choosing "Open 6 in Board" would open six while double-clicking inside
    /// that same sweep opened one, which is two answers to one question in one
    /// view mode.
    ///
    /// The membership test is what keeps it honest: a double-click on an
    /// *unselected* card is not a bulk gesture, and `LibraryGameCardView`'s
    /// simultaneous select-then-open means the selection has already collapsed
    /// to that card by the time this runs — so the `contains` check reads true
    /// only when the sweep genuinely survived the click.
    ///
    /// Ordered off `games`, not off the `Set`, because that is tab order.
    private func open(_ game: PGN) {
        if selectedPGNs.count > 1, selectedPGNs.contains(game.id) {
            onOpen(games.filter { selectedPGNs.contains($0.id) })
        } else {
            onOpen([game])
        }
    }

    /// Sweeping replaces the selection with the crossed cards — Finder's
    /// plain drag. The anchor follows the sweep so a subsequent arrow steps
    /// from inside it rather than from a card the sweep just deselected.
    private var rubberBandGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.gridSpace))
            .onChanged { value in
                let band = IconGridSelection.selectionRect(from: value.startLocation, to: value.location)
                rubberBand = band
                let crossed = Set(
                    games
                        .filter { cardFrames.frames[$0.id]?.intersects(band) == true }
                        .map(\.id)
                )
                // **Guarded, because most frames of a drag cross nothing new.**
                // This fires per drag callback, and `selectedPGNs` is `@State`
                // on `LibraryDestination` — so an unguarded write invalidated
                // that body at pointer rate, and its body re-narrows and
                // re-sorts the Library. Extending a band across a gutter, or
                // simply holding still, wrote an identical `Set` and paid for
                // it. The equality check is a set compare over ids; the render
                // it skips is the whole destination.
                //
                // `anchorID` rides inside the guard rather than beside it: it
                // is derived from `crossed` alone, so an unchanged sweep cannot
                // move it, and the `first(where:)` walk is skipped with it.
                guard crossed != selectedPGNs else { return }
                selectedPGNs = crossed
                anchorID = crossed.isEmpty ? nil : games.first { crossed.contains($0.id) }?.id
            }
            .onEnded { _ in
                rubberBand = nil
                isFocused = true
            }
    }

    private func move(_ direction: MoveCommandDirection, width: CGFloat, proxy: ScrollViewProxy) {
        guard !games.isEmpty else { return }
        let target: Int
        if let anchorID, let current = games.firstIndex(where: { $0.id == anchorID }) {
            target = IconGridSelection.destination(
                from: current,
                direction: direction,
                columnCount: options.columnCount(containerWidth: width),
                count: games.count
            )
        } else {
            // Nothing anchored: the first arrow lands on the first card,
            // Finder's opening move.
            target = 0
        }
        let game = games[target]
        selectedPGNs = [game.id]
        anchorID = game.id
        proxy.scrollTo(game.id)
    }

    // (The arrow stepping and band normalization moved to
    // `IconGridSelection` when the Players grid became their second
    // consumer — one grammar, two grids.)
}

// MARK: Previews
private func iconsPreviewGames() -> [PGN] {
    [
        PGN(event: "World Championship", site: "Dubai", round: 11,
            white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian", result: .whiteWins),
        PGN(event: "Tata Steel Masters", site: "Wijk aan Zee", round: 7,
            white: "Giri, Anish", black: "Caruana, Fabiano", result: .draw),
        PGN(event: "Norway Chess", site: "Stavanger", round: 3,
            white: "Firouzja, Alireza", black: "Ding, Liren", result: .blackWins),
        PGN(event: "Candidates Tournament", site: "Madrid", round: 14,
            white: "Nepomniachtchi, Ian", black: "Ding, Liren", result: .ongoing),
        PGN(event: "Candidates Tournament", site: "Madrid", round: 2,
            white: "Caruana, Fabiano", black: "Firouzja, Alireza", result: .draw),
        PGN(event: "Tata Steel Masters", site: "Wijk aan Zee", round: 1,
            white: "Ding, Liren", black: "Giri, Anish", result: .whiteWins),
        PGN(event: "Norway Chess", site: "Stavanger", round: 9,
            white: "Carlsen, Magnus", black: "Caruana, Fabiano", result: .whiteWins)
    ]
}

/// Seven cards over six columns: a second, partial row, so the down-arrow
/// overflow rule and the wrap at the row boundary are both exercisable in
/// the canvas (click a card, then arrow around). The first three carry the
/// analyzed badge so both verdicts render in one canvas (D72′).
#Preview("With Games") {
    @Previewable @State var selection: Set<PGN.ID> = []

    let games = iconsPreviewGames()

    LibraryIconsView(
        games: games,
        analyzedIDs: Set(games.prefix(3).map(\.id)),
        selectedPGNs: $selection,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 900, height: 480)
    .environment(PreviewFixtures.viewOptions())
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PGN.ID> = []

    LibraryIconsView(
        games: [],
        analyzedIDs: [],
        selectedPGNs: $selection,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 720, height: 480)
    .environment(PreviewFixtures.viewOptions())
    .modelContainer(for: PGN.self, inMemory: true)
}
