import SwiftUI

struct MoveHistoryView: View {
    
    // MARK: Stored Properties
    let moves: [String]
    let currentMoveIndex: Int?
    let onMoveTapped: ((Int) -> Void)?
    /// Whether this view brings its own `ScrollView` - `false` lets a host `List` own scrolling
    /// (a nested scroll view is a fixed-size box inside an infinite proposal).
    ///
    /// **Both hosts pass `false`, so `pane`, its `.thinMaterial`, the `LazyVStack` and the scroll
    /// sync inside `pane` render on canvas only.** Kept as the honest shape for a standalone move
    /// list, and because the split is what makes the embedded form correct. Note the default is
    /// the *unrendered* value - the reverse of `DGTConnectionToolbarContent.identifier`'s rule.
    var scrollsIndependently: Bool = true
    
    // MARK: Computed Properties
    private var pairCount: Int {
        (moves.count + 1) / 2
    }
    
    // MARK: Body
    var body: some View {
        Group {
            if moves.isEmpty {
                emptyState
            } else if scrollsIndependently {
                pane
            } else {
                moveRows
            }
        }
        // Cancels the 8 pt leading/trailing `listRowInsets` both hosts apply, so the rows run to
        // the section's edge. One decision, spelled in three files.
        .padding(.horizontal, -8)
    }
    
    // MARK: Instance Methods
    private var emptyState: some View {
        Text("No moves played yet")
            .font(.callout)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
    }
    
    /// The self-contained pane. Same scroll-sync as the embedded form -
    /// applied to whichever view owns the scrolling.
    private var pane: some View {
        ScrollView(.vertical) {
            moveRows
        }
        .background(.thinMaterial)
        .contentMargins(0, for: .scrollContent)
        .scrollsToCurrentMove(currentMoveIndex)
    }
    
    /// **Lazy only where laziness can work** (21 Aug 2026). A `LazyVStack` needs a scrolling
    /// viewport to clip against; inside a host `List`'s cell it is handed an unbounded height
    /// proposal and materialises every row regardless - so the embedded form was paying a lazy
    /// container's indirection for a claim it could not honour, and a 90-ply game built all
    /// forty-five rows into one list cell either way. The self-scrolling `pane` keeps
    /// `LazyVStack`, where the viewport exists and the laziness is real.
    ///
    /// The other candidate - giving the embedded form its own bounded-height `ScrollView` - stays
    /// rejected for the reason `scrollsIndependently` already states above: a nested scroll view is
    /// a fixed-size box inside an infinite proposal. Matching the container to the proposal is the
    /// honest half of that decision.
    @ViewBuilder
    private var moveRows: some View {
        if scrollsIndependently {
            LazyVStack(spacing: 0) { pairRows }
                .padding(.vertical, 4)
        } else {
            VStack(spacing: 0) { pairRows }
                .padding(.vertical, 4)
        }
    }
    
    /// `id: \.self` is load-bearing, not redundant: it selects `ForEach`'s
    /// `RandomAccessCollection` initializer. Dropping it picks the constant-`Range<Int>` one,
    /// which SwiftUI supports only for a range that never changes - and `pairCount` grows on
    /// every move.
    @ViewBuilder
    private var pairRows: some View {
        ForEach(0 ..< pairCount, id: \.self) { pairIndex in
            movePairRow(pairIndex: pairIndex)
        }
    }
    
    private func movePairRow(pairIndex: Int) -> some View {
        let moveNumber = pairIndex + 1
        let whiteIndex = pairIndex * 2
        let blackIndex = whiteIndex + 1
        
        return HStack(spacing: 0) {
            Text("\(moveNumber).")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .frame(width: 20, alignment: .leading)
                .padding(.trailing, 35)
            
            moveCell(at: whiteIndex)
            
            if blackIndex < moves.count {
                moveCell(at: blackIndex)
            } else {
                Spacer()
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func moveCell(at index: Int) -> some View {
        let san = moves[index]
        let isSelected = index == currentMoveIndex
        
        // The Button is built either way, so a nil handler leaves a control that does nothing -
        // live play passes nil, and every SAN there is clickable and announced as a button while
        // acting on nothing. `.disabled(onMoveTapped == nil)` would fix the semantics at the cost
        // of greying the text.
        return Button {
            onMoveTapped?(index)
        } label: {
            Text(san)
                .font(.body)
                .fontWeight(isSelected ? .medium : .regular)
                .fontDesign(.monospaced)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.secondary.opacity(isSelected ? 0.25 : 0))
                        .padding(.leading, 3)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .id(index)
    }
}

// MARK: Scroll Sync

extension View {
    
    /// Pins the applied container to the current ply - lives here because `ScrollViewReader` must
    /// wrap the container that actually scrolls.
    func scrollsToCurrentMove(_ index: Int?) -> some View {
        modifier(CurrentMoveScrollSync(currentMoveIndex: index))
    }
}

private struct CurrentMoveScrollSync: ViewModifier {
    
    let currentMoveIndex: Int?
    
    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .onAppear { scroll(proxy, animated: false) }
                .onChange(of: currentMoveIndex) { _, _ in scroll(proxy, animated: true) }
        }
    }
    
    /// Targets the `.id(index)` on each move cell. Animated on a scrub or a
    /// new ply, instant on first appearance - a game opened mid-scrub
    /// shouldn't animate from move 1.
    private func scroll(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let currentMoveIndex else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(currentMoveIndex, anchor: .center)
            }
        } else {
            proxy.scrollTo(currentMoveIndex, anchor: .center)
        }
    }
}

// MARK: Previews

/// **Four of these five take `scrollsIndependently`'s default, so they render `pane`** - the
/// branch neither host uses. Read them as the standalone shape; "Inspector Integration" is the
/// only one showing what ships.
#Preview("Ruy Lopez") {
    MoveHistoryView(
        moves: [
            "e4", "e5", "Nf3", "Nc6", "Bb5", "a6",
            "Ba4", "Nf6", "O-O", "Be7", "Re1", "b5",
            "Bb3", "d6", "c3", "O-O", "h3", "Nb8",
            "d4", "Nbd7"
        ],
        currentMoveIndex: 14,
        onMoveTapped: { _ in }
    )
    .frame(width: 260)
    .background(Color(.windowBackgroundColor))
}

#Preview("Scholar's Mate") {
    MoveHistoryView(
        moves: [
            "e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#"
        ],
        currentMoveIndex: 6,
        onMoveTapped: { _ in }
    )
    .frame(width: 260, height: 160)
    .background(Color(.windowBackgroundColor))
}

#Preview("Long Game") {
    MoveHistoryView(
        moves: [
            "d4", "Nf6", "c4", "e6", "Nf3", "d5", "Nc3", "Be7",
            "Bg5", "h6", "Bh4", "O-O", "e3", "b6", "Bd3", "Bb7",
            "O-O", "Nbd7", "Qe2", "c5", "Rad1", "Rc8", "Bb1", "cxd4",
            "exd4", "dxc4", "Qxc4", "Nd5", "Bg3", "N7f6", "Ne5", "Rc7",
            "Qe2", "Qa8", "f3", "Rd8", "Qf2", "Bb4", "Bc2", "Bxc3",
            "bxc3", "Qc8", "Bd3", "Nd5", "c4", "Nf4", "Bf5", "exf5"
        ],
        currentMoveIndex: 38,
        onMoveTapped: { _ in }
    )
    .frame(width: 260, height: 240)
    .background(Color(.windowBackgroundColor))
}

#Preview("Empty State") {
    MoveHistoryView(
        moves: [],
        currentMoveIndex: nil,
        onMoveTapped: nil
    )
    .frame(width: 260, height: 100)
    .background(Color(.windowBackgroundColor))
}

#Preview("Inspector Integration") {
    List {
        CollapsibleSection(.roster, title: "Magnus Carlsen vs Ian Nepomniachtchi") {
            LabeledContent("White", value: "Carlsen")
            LabeledContent("Black", value: "Nepomniachtchi")
            LabeledContent("Round", value: "7")
            LabeledContent("Result", value: "*")
        }
        
        CollapsibleSection(.evaluation, title: "Evaluation") {
            EvaluationGraphView(
                evaluations: [
                    0.50, 0.52, 0.51, 0.49, 0.50, 0.52, 0.50, 0.48,
                    0.46, 0.44, 0.46, 0.44, 0.42, 0.44, 0.43, 0.45,
                    0.42, 0.40, 0.42, 0.44, 0.41, 0.38, 0.40, 0.42,
                    0.38, 0.35, 0.37, 0.40, 0.36, 0.32, 0.35, 0.30,
                    0.34, 0.42, 0.50, 0.58, 0.72, 0.88, 0.96
                ],
                currentMoveIndex: 14,
                style: .walnut
            )
            .frame(height: 140)
            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        }
        
        CollapsibleSection(.moves, title: "Moves") {
            MoveHistoryView(
                moves: [
                    "e4", "e5", "Nf3", "Nc6", "Bb5", "a6",
                    "Ba4", "Nf6", "O-O", "Be7", "Re1", "b5",
                    "Bb3", "d6", "c3", "O-O", "h3", "Nb8",
                    "d4", "Nbd7"
                ],
                currentMoveIndex: 14,
                onMoveTapped: { _ in }
            )
            .frame(height: 200)
            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        }
    }
    .listStyle(.sidebar)
    .frame(width: 300, height: 600)
    .environment(InspectorSectionCollapse.preview)
}
