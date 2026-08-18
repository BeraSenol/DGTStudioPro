import SwiftUI

/// The filmstrip's own numbers. A value type with two presets rather than five parameters at each
/// call site - and presets rather than one shared set of numbers because **the two strips do not
/// currently agree** and unifying them would be a layout change wearing a refactor's clothes.
///
/// The divergence, named so it reads as unexplained rather than considered: 180 vs 170 pt tall,
/// 12 pt between cards vs the stack default, and the Players strip pins its card to 160 pt while
/// the Library's self-sizes. Only the Library's height has a stated reason ("the strip sizes
/// itself to the card, never the reverse"). Whether they should converge is a question for
/// someone looking at both on screen; this type's job is to make the answer a one-line edit
/// instead of a two-file one.
struct FilmstripMetrics {

    let height: CGFloat
    /// Nil lets the card size itself, which is the Library's arrangement.
    let cardWidth: CGFloat?
    /// Nil is `HStack`'s default spacing - the spelling `HStack(spacing:)` already takes.
    let interitemSpacing: CGFloat?
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    static let library = FilmstripMetrics(
        height: 180,
        cardWidth: nil,
        interitemSpacing: nil,
        horizontalPadding: 16,
        verticalPadding: 16
    )

    static let players = FilmstripMetrics(
        height: 170,
        cardWidth: 160,
        interitemSpacing: 12,
        horizontalPadding: 16,
        verticalPadding: 12
    )
}

/// A preview pane over a scrolling filmstrip, with ← / → stepping the strip - written once.
///
/// The two galleries were the icons grids' problem in smaller type: identical `VStack`, identical
/// focus chrome, identical `move(_:)`, identical scroll-sync, and a strip that differed only in
/// gutters and height. What is *not* shared is the preview pane, which is the whole point of each
/// gallery - so it arrives as a builder and this type never knows what it is drawing.
///
/// Selection stays a `Set` even though a gallery is single-by-gesture: the destinations bind one,
/// ⌘A writes one, and previewing the first of a plural selection is the behaviour both galleries
/// already had.
struct FilmstripGalleryView<Item: Identifiable, Preview: View, Card: View>: View {

    // MARK: Stored Properties

    let items: [Item]
    @Binding var selection: Set<Item.ID>
    let metrics: FilmstripMetrics

    private let preview: () -> Preview
    /// No `@escaping` on the inner `() -> Void`: it is only spellable in function *parameter*
    /// position, and a closure parameter of a function **type** is escaping already.
    private let card: (Item, Bool, () -> Void) -> Card

    // MARK: Private Properties

    /// The gallery itself is the focusable; a card click hands it focus, ← / → step the strip.
    @FocusState private var isFocused: Bool

    // MARK: Initializers

    init(
        items: [Item],
        selection: Binding<Set<Item.ID>>,
        metrics: FilmstripMetrics,
        @ViewBuilder preview: @escaping () -> Preview,
        @ViewBuilder card: @escaping (Item, Bool, () -> Void) -> Card
    ) {
        self.items = items
        self._selection = selection
        self.metrics = metrics
        self.preview = preview
        self.card = card
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            preview()
            Divider()
            filmstrip
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onMoveCommand { direction in
            move(direction)
        }
        // The whole gallery is the background target - a gallery has almost no empty space to aim
        // at; card menus still win over their own bounds.
        .contextMenu { ShowViewOptionsButton() }
    }

    // MARK: Instance Methods

    /// ← / → step, ↑ / ↓ hold - `IconGridSelection.destination`'s one-row degenerate case
    /// (`columnCount == count`, pinned in its suite); the previewed card is the anchor.
    private func move(_ direction: MoveCommandDirection) {
        guard !items.isEmpty else { return }
        let target: Int
        if let id = selection.first,
           let current = items.firstIndex(where: { $0.id == id }) {
            target = IconGridSelection.destination(
                from: current,
                direction: direction,
                columnCount: items.count,
                count: items.count
            )
        } else {
            target = 0
        }
        selection = [items[target].id]
    }

    private var filmstrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: metrics.interitemSpacing) {
                    ForEach(items) { item in
                        card(item, selection.contains(item.id), { select(item) })
                            .frame(width: metrics.cardWidth)
                            .id(item.id)
                    }
                }
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.vertical, metrics.verticalPadding)
            }
            .frame(height: metrics.height)
            .background(.thinMaterial)
            .onChange(of: selection) { _, newSelection in
                guard let id = newSelection.first else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private func select(_ item: Item) {
        selection = [item.id]
        isFocused = true
    }
}
