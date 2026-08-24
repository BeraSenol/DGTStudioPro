import SwiftUI

/// The icons grid itself - Finder's two selection gestures over any card, written once.
///
/// `IconGridSelection` has always owned the *pure* half of this surface (arrow stepping, band
/// rectangles, frame quantization). The stateful half - the drag gesture, the frame observation,
/// the band overlay, the focus chrome, the anchor - was spelled twice, in `LibraryIconsView` and
/// `PlayersIconsView`, and stayed identical only because every correction was applied twice by
/// hand. The comments admit it: "the fifth cycling correction, **shared with the Library grid**"
/// is a note that a fix landed in two places. That is the arrangement this type ends; a sixth
/// correction now has one home.
///
/// **The card is the caller's, the gesture is ours.** The builder takes the item, whether it is
/// selected, and the select action - nothing else. Everything a card needs beyond that (glyph
/// width, monogram side, the verbs, the analysis glyph) is closed over at the call site, which is
/// also where the environment it reads belongs. So the two grids keep their own vocabulary and
/// share the only thing that must not fork.
///
/// Not generic over the *selection* type: a `Set<Item.ID>` is what both destinations bind and
/// what ⌘A writes.
struct IconGridView<Item: Identifiable, Card: View>: View {

    // MARK: Stored Properties

    let items: [Item]
    @Binding var selection: Set<Item.ID>

    /// The coordinate space the card frames and the band share - a name, not an accessibility
    /// identifier, and taken as a parameter rather than a static because **a generic type cannot
    /// have stored static properties**. The two grids keep their distinct names ("libraryIconsGrid",
    /// "playersIconsGrid") so a space never resolves across a destination switch.
    let space: String

    /// Which collection's geometry to lay out with. A parameter for the same reason `space` is
    /// one: this type is shared by both destinations, and since icon size and spacing became
    /// per-destination (18 Aug 2026) "the grid geometry" is no longer a single answer the
    /// environment can give. The caller already knows which surface it is.
    let collection: CollectionViewOptionsSubject.Collection

    /// **The inner `@escaping` is load-bearing.** A closure parameter is non-escaping by default
    /// wherever it appears - inside a function *type* just as much as in a declaration's parameter
    /// list - and every card stores its `onSelect` rather than calling it inline, so a non-escaping
    /// `select` cannot be handed over ("passing non-escaping parameter to function expecting an
    /// '@escaping' closure"). It was briefly dropped on 18 Aug 2026 on the theory that the
    /// attribute is unspellable in nested position; it is spellable, and it is required.
    private let card: (Item, Bool, @escaping () -> Void) -> Card

    // MARK: Private Properties

    @Environment(CollectionViewOptions.self) private var options

    /// Realized card frames in `space` - a box, not observed state, because nothing renders from
    /// them: a write must never invalidate the view. **Populated only while a band is sweeping**;
    /// stale entries are re-checked against `items` rather than trusted.
    @State private var cardFrames = IconGridFrameStore<Item.ID>()
    @State private var rubberBand: CGRect?

    /// The card the last selection gesture touched - where an arrow steps from.
    @State private var anchorID: Item.ID?
    @FocusState private var isFocused: Bool

    /// The column count the grid lays out with - written by the width observation in `body`, read
    /// by the `LazyVGrid` and the arrow keys. An `Int` in `@State` **by design**: the body depends
    /// on the fitted count, never on the continuous width, so a width animation - the inspector
    /// slide, a window drag - invalidates this view only at the frames where a column boundary is
    /// actually crossed. The `GeometryReader` this replaces (23 Aug 2026) proposed the whole grid
    /// again on **every frame** of such an animation: every card's view struct rebuilt, every
    /// per-card observer re-registered, the full subtree diffed, at animation rate - which is what
    /// made toggling the inspector visibly laggy in icons view. Starts at 1 and corrects in the
    /// first layout pass, before drawing - the same one-pass settling the reader had.
    @State private var columnCount = 1

    // MARK: Initializers

    init(
        items: [Item],
        selection: Binding<Set<Item.ID>>,
        space: String,
        collection: CollectionViewOptionsSubject.Collection,
        @ViewBuilder card: @escaping (Item, Bool, @escaping () -> Void) -> Card
    ) {
        self.items = items
        self._selection = selection
        self.space = space
        self.collection = collection
        self.card = card
    }

    // MARK: Body

    var body: some View {
        // Read once ahead of the `ForEach`, so sixty closures capture one Bool, not sixty @State reads.
        let isSweeping = rubberBand != nil
        // Hoisted for the same reason the fork used a `nonisolated static let`: `onGeometryChange`'s
        // transform is `@Sendable`, and `View` conformance infers @MainActor onto this type - so the
        // closure must capture a `Sendable` local, never `self.space`. A `String` by value is both.
        let spaceName = space
        // Hoisted for the width observation's transform, same rule: two `CGFloat`s by value.
        let iconSize = options.iconSize(for: collection)
        let spacing = options.spacing(for: collection)
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(
                    columns: options.columns(count: columnCount, for: collection),
                    spacing: spacing
                ) {
                    ForEach(items) { item in
                        card(item, selection.contains(item.id), { select(item) })
                            .id(item.id)
                            .onGeometryChange(for: CGRect.self) { geometry in
                                // Gated on the sweep - the fifth "cycling between duplicate values"
                                // correction, and the first that removes the observation instead of
                                // tuning it: frames are only read mid-sweep.
                                isSweeping
                                ? IconGridSelection.stableFrame(
                                    geometry.frame(in: .named(spaceName))
                                )
                                : .null
                            } action: { frame in
                                // A box write: free, invisible to the render pass. `.null` lands once per
                                // card when a sweep ends; harmless - `.null` intersects nothing.
                                cardFrames.frames[item.id] = frame
                            }
                    }
                }
                .padding(CollectionViewOptions.inset)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Empty space or gutters - a card's own tap wins before this fires.
                    selection.removeAll()
                    anchorID = nil
                    isFocused = true
                }
                // Background context menu on the same `contentShape` as the clear-selection tap, so it
                // covers the gutters - Finder's behaviour; a card's own menu wins over its bounds.
                .contextMenu { ShowViewOptionsButton() }
                .gesture(rubberBandGesture)
                // Content-anchored: the space, the gesture coordinates and the band overlay live on this
                // container, inside the scroll.
                .coordinateSpace(name: space)
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
            // Width enters the view as a **count**: the transform quantizes, and `action` runs
            // only when the transformed value changes - so the body re-evaluates at column
            // boundaries, a handful of times across an inspector slide, instead of every frame.
            // `LazyVGrid`'s flexible items track the continuous width in the layout pass, which
            // needs no body involvement. No cycle by construction: the count cannot feed back
            // into the container width the transform reads (the sixth "cycling" shape, avoided
            // rather than corrected - see `IconGridSelection.stableFrame` for the first five).
            .onGeometryChange(for: Int.self) { geometry in
                CollectionViewOptions.columnCount(
                    containerWidth: geometry.size.width,
                    iconSize: iconSize,
                    spacing: spacing
                )
            } action: { count in
                columnCount = count
            }
            // The settled count the layout used - no longer a width captured at key-press time.
            .onMoveCommand { direction in
                move(direction, proxy: proxy)
            }
        }
    }

    // MARK: Instance Methods

    private func select(_ item: Item) {
        selection = [item.id]
        anchorID = item.id
        isFocused = true
    }

    /// Sweeping replaces the selection with the crossed cards (Finder's plain drag); the anchor
    /// follows the sweep so the next arrow steps from inside it.
    private var rubberBandGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(space))
            .onChanged { value in
                let band = IconGridSelection.selectionRect(from: value.startLocation, to: value.location)
                rubberBand = band
                let crossed = Set(
                    items
                        .filter { cardFrames.frames[$0.id]?.intersects(band) == true }
                        .map(\.id)
                )
                // Guarded: most drag frames cross nothing new, and an unguarded write invalidated the
                // destination's body at pointer rate - worth more on the Players side, whose binding is
                // `@State` on a destination that folds the whole Library.
                guard crossed != selection else { return }
                selection = crossed
                anchorID = crossed.isEmpty ? nil : items.first { crossed.contains($0.id) }?.id
            }
            .onEnded { _ in
                rubberBand = nil
                isFocused = true
            }
    }

    private func move(_ direction: MoveCommandDirection, proxy: ScrollViewProxy) {
        guard !items.isEmpty else { return }
        let target: Int
        if let anchorID, let current = items.firstIndex(where: { $0.id == anchorID }) {
            target = IconGridSelection.destination(
                from: current,
                direction: direction,
                // The same `columnCount` the grid laid out with - one value for layout and
                // stepping, where the reader-era spelling recomputed it from a captured width.
                columnCount: columnCount,
                count: items.count
            )
        } else {
            // Nothing anchored: the first arrow lands on the first card - Finder's opening move.
            target = 0
        }
        let item = items[target]
        selection = [item.id]
        anchorID = item.id
        proxy.scrollTo(item.id)
    }
}
