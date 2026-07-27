//
//  MoveHistoryView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 13/04/2026.
//

import SwiftUI

internal struct MoveHistoryView: View {
    
    // MARK: Stored Properties
    internal let moves: [String]
    internal let currentMoveIndex: Int?
    internal let onMoveTapped: ((Int) -> Void)?
    /// Whether this view brings its own `ScrollView`.
    ///
    /// `true` (the default, preserving every existing call site) is the
    /// self-contained pane — a bordered material panel of fixed height.
    /// `false` emits the rows bare, for a host that embeds them in its own
    /// `List`: a `List` proposes its rows unbounded height, so a nested
    /// scroll view can only ever be a fixed-size box inside an infinite
    /// one. Embedded, the moves run to the bottom of the sidebar and the
    /// host's list does the scrolling.
    internal var scrollsIndependently: Bool = true
    
    // MARK: Computed Properties
    private var pairCount: Int {
        (moves.count + 1) / 2
    }
    
    // MARK: Body
    internal var body: some View {
        Group {
            if moves.isEmpty {
                emptyState
            } else if scrollsIndependently {
                pane
            } else {
                moveRows
            }
        }
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
    
    /// The self-contained pane. Same scroll-sync as the embedded form —
    /// applied to whichever view owns the scrolling.
    private var pane: some View {
        ScrollView(.vertical) {
            moveRows
        }
        .background(.thinMaterial)
        .contentMargins(0, for: .scrollContent)
        .scrollsToCurrentMove(currentMoveIndex)
    }
    
    private var moveRows: some View {
        LazyVStack(spacing: 0) {
            ForEach(0 ..< pairCount, id: \.self) { pairIndex in
                movePairRow(pairIndex: pairIndex)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func movePairRow(pairIndex: Int) -> some View {
        let moveNumber = pairIndex + 1
        let whiteIndex = pairIndex * 2
        let blackIndex = whiteIndex + 1
        
        return HStack(spacing: 0) {
            Text("\(moveNumber).")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .frame(width: 30, alignment: .trailing)
                .padding(.trailing, 20)

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
    
    /// Keeps the scroll container this is applied to pinned to the current
    /// ply. Lives here rather than inside `MoveHistoryView` because the
    /// `ScrollViewReader` has to wrap the container that actually scrolls —
    /// which, for an embedded move list, is the host's `List`. One
    /// implementation, both shapes: the pane applies it to its own
    /// `ScrollView`, the inspectors apply it to their `List`.
    internal func scrollsToCurrentMove(_ index: Int?) -> some View {
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
    /// new ply, instant on first appearance — a game opened mid-scrub
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
#Preview("Ruy Lopez with Classifications") {
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
        Section {
            LabeledContent("White", value: "Carlsen")
            LabeledContent("Black", value: "Nepomniachtchi")
            LabeledContent("Round", value: "7")
            LabeledContent("Result", value: "*")
        } header: {
            Text("Game")
        }
        
        Section {
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
            .frame(height: 110)
            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        } header: {
            Text("Evaluation")
        }
        
        Section {
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
        } header: {
            Text("Moves")
        }
    }
    .listStyle(.sidebar)
    .frame(width: 300, height: 600)
}
