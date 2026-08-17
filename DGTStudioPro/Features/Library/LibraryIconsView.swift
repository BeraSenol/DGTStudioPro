import SwiftData
import SwiftUI

/// The icons grid with Finder's two selection gestures: arrow keys walk from the last-touched
/// card (index math in reading order - the grid is not `.adaptive`, so the column count is
/// computable), and a click-drag sweeps a rubber-band over the cards it crosses.
struct LibraryIconsView: View {

    // MARK: Static Constants

    /// The named space the frames and the band share (a coordinate space, not an identifier).
    /// `nonisolated`: `View` conformance infers @MainActor onto statics.
    private nonisolated static let gridSpace = "libraryIconsGrid"

    // MARK: Stored Properties
    let games: [PGN]
    /// Which games count as analyzed, off the memoized projection - never off the models, so
    /// a card render costs no blob decode.
    let analyzedIDs: Set<PGN.ID>
    @Binding var selectedPGNs: Set<PGN.ID>
    /// All four verbs take the set, resolved through `subjects(for:)` - Finder's rule for
    /// every card action, not just Open. Analyze, Export and Delete were `(PGN) -> Void`
    /// until 17 Aug 2026 and acted on one game however many were selected, while the list's
    /// `.contextMenu(forSelectionType:)` handed it the whole selection free - the
    /// "select all, delete all, it deletes one" report.
    let onOpen: ([PGN]) -> Void
    let onAnalyze: ([PGN]) -> Void
    let onExport: ([PGN]) -> Void
    let onDelete: ([PGN]) -> Void

    // MARK: Private Properties

    @Environment(CollectionViewOptions.self) private var options

    /// Ambient, written once by the destination; nil in previews, which is honest.
    @Environment(\.analysisRunningGameID) private var runningAnalysisID

    /// Realized card frames in `gridSpace` - a box, not observed state. **Populated only while a
    /// band is sweeping**; stale entries are re-checked against `games` rather than trusted.
    @State private var cardFrames = IconGridFrameStore<PGN.ID>()
    @State private var rubberBand: CGRect?
    /// The card the last selection gesture touched - where an arrow steps from.
    @State private var anchorID: PGN.ID?
    @FocusState private var isFocused: Bool

    // MARK: Body
    var body: some View {
        // Read once ahead of the `ForEach`, so sixty closures capture one Bool, not sixty @State reads.
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
                                onOpen:    { onOpen(subjects(for: game)) },
                                onAnalyze: { onAnalyze(subjects(for: game)) },
                                onExport:  { onExport(subjects(for: game)) },
                                onDelete:  { onDelete(subjects(for: game)) }
                            )
                            .id(game.id)
                            .onGeometryChange(for: CGRect.self) { geometry in
                                // Gated on the sweep - the fifth "cycling between duplicate values" correction, and the first
                                // that removes the observation instead of tuning it: frames are only read mid-sweep.
                                isSweeping
                                ? IconGridSelection.stableFrame(
                                    geometry.frame(in: .named(Self.gridSpace))
                                )
                                : .null
                            } action: { frame in
                                // A box write: free, invisible to the render pass. `.null` lands once per card when a sweep
                                // ends; harmless - `.null` intersects nothing.
                                cardFrames.frames[game.id] = frame
                            }
                        }
                    }
                    .padding(CollectionViewOptions.inset)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Empty space or gutters - a card's own tap wins before this fires.
                        selectedPGNs.removeAll()
                        anchorID = nil
                        isFocused = true
                    }
                    // Background context menu on the same `contentShape` as the clear-selection tap, so it covers
                    // the gutters - Finder's behaviour; a card's own menu wins over its bounds.
                    .contextMenu { ShowViewOptionsButton() }
                    .gesture(rubberBandGesture)
                    // Content-anchored: the space, the gesture coordinates and the band overlay live on this
                    // container, inside the scroll.
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
                // `geometry.size.width` directly - the proxy the layout reads, captured at key-press time when
                // layout has settled.
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

    /// Finder's rule, spelled by hand (`LibraryListView` gets it free from
    /// `.contextMenu(forSelectionType:)` and `primaryAction`): acting on a card inside a
    /// multi-selection acts on the whole selection; on anything else, just that card.
    /// One resolution for all four verbs since 17 Aug 2026 - it belonged to Open alone
    /// (as `open(_:)`), and the other three quietly acted on one game whatever was
    /// selected. Ordered off `games` - that is tab and processing order.
    private func subjects(for game: PGN) -> [PGN] {
        if selectedPGNs.count > 1, selectedPGNs.contains(game.id) {
            return games.filter { selectedPGNs.contains($0.id) }
        }
        return [game]
    }

    /// Sweeping replaces the selection with the crossed cards (Finder's plain drag); the anchor
    /// follows the sweep so the next arrow steps from inside it.
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
                // Guarded: most drag frames cross nothing new, and an unguarded write invalidated the
                // destination's body at pointer rate.
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
            // Nothing anchored: the first arrow lands on the first card - Finder's opening move.
            target = 0
        }
        let game = games[target]
        selectedPGNs = [game.id]
        anchorID = game.id
        proxy.scrollTo(game.id)
    }

    // (Arrow stepping and band normalization live in `IconGridSelection` - one grammar, two grids.)
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

/// Seven cards over six columns: a partial second row, so overflow and wrap are exercisable.
/// First three carry the analyzed badge so both verdicts render.
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
