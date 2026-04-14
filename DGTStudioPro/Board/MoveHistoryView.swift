//
//  MoveHistoryView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 13/04/2026.
//

import SwiftUI

// MARK: Move Classification
internal enum MoveClassification: Sendable {
    case book
    case best
    case good
    case inaccuracy
    case mistake
    case blunder

    // MARK: Computed Properties
    internal var color: Color {
        switch self {
        case .book:       .brown
        case .best:       .green
        case .good:       .mint
        case .inaccuracy: .yellow
        case .mistake:    .orange
        case .blunder:    .red
        }
    }
}

// MARK: Move History View
internal struct MoveHistoryView: View {

    // MARK: Stored Properties
    internal let moves: [String]
    internal let classifications: [MoveClassification?]
    internal let currentMoveIndex: Int?
    internal let style: BoardStyle
    internal let onMoveTapped: ((Int) -> Void)?

    // MARK: Computed Properties
    private var pairCount: Int {
        (moves.count + 1) / 2
    }

    // MARK: Body
    internal var body: some View {
        if moves.isEmpty {
            emptyState
        } else {
            moveList
        }
    }

    // MARK: Instance Methods
    private var emptyState: some View {
        Text("No moves played yet")
            .font(.callout)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
    }

    private var moveList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(0 ..< pairCount, id: \.self) { pairIndex in
                        movePairRow(pairIndex: pairIndex)
                    }
                }
                .padding(.vertical, 4)
            }
            .background(.thinMaterial)
            .contentMargins(0, for: .scrollContent)
            .onAppear {
                scrollToCurrent(proxy: proxy, animated: false)
            }
            .onChange(of: currentMoveIndex) { _, _ in
                scrollToCurrent(proxy: proxy, animated: true)
            }
        }
    }

    private func movePairRow(pairIndex: Int) -> some View {
        let moveNumber = pairIndex + 1
        let whiteIndex = pairIndex * 2
        let blackIndex = whiteIndex + 1

        return HStack(spacing: 0) {
            Text("\(moveNumber).")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 30, alignment: .trailing)
                .padding(.trailing, 12)

            moveCell(at: whiteIndex, isWhite: true)

            if blackIndex < moves.count {
                moveCell(at: blackIndex, isWhite: false)
            } else {
                Spacer()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func moveCell(at index: Int, isWhite: Bool) -> some View {
        let san = moves[index]
        let isSelected = index == currentMoveIndex
        let classification = index < classifications.count ? classifications[index] : nil
        let highlightColor = Color.secondary

        return Button {
            onMoveTapped?(index)
        } label: {
            HStack(spacing: 5) {
                if let classification {
                    Circle()
                        .fill(classification.color)
                        .frame(width: 5, height: 5)
                        .padding(.bottom, 1)
                }

                Text(san)
                    .font(
                        .system(
                            size: 12,
                            weight: isSelected ? .semibold : .regular,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(highlightColor.opacity(isSelected ? 0.20 : 0))
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .id(index)
    }

    private func scrollToCurrent(proxy: ScrollViewProxy, animated: Bool) {
        guard let index = currentMoveIndex else { return }

        if animated {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(index, anchor: .center)
            }
        } else {
            proxy.scrollTo(index, anchor: .center)
        }
    }
}

// MARK: Previews
#Preview("Walnut — Ruy Lopez with Classifications") {
    MoveHistoryView(
        moves: [
            "e4", "e5", "Nf3", "Nc6", "Bb5", "a6",
            "Ba4", "Nf6", "O-O", "Be7", "Re1", "b5",
            "Bb3", "d6", "c3", "O-O", "h3", "Nb8",
            "d4", "Nbd7"
        ],
        classifications: [
            .book, .book, .book, .book, .book, .book,
            .book, .book, .best, .good, .best, .good,
            .good, .good, .best, .inaccuracy, .good, .mistake,
            .good, .blunder
        ],
        currentMoveIndex: 14,
        style: .walnut,
        onMoveTapped: { _ in }
    )
    .frame(width: 260, height: 240)
    .background(Color(.windowBackgroundColor))
}

#Preview("Rosewood — Scholar's Mate") {
    MoveHistoryView(
        moves: [
            "e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#"
        ],
        classifications: [],
        currentMoveIndex: 6,
        style: .rosewood,
        onMoveTapped: { _ in }
    )
    .frame(width: 260, height: 160)
    .background(Color(.windowBackgroundColor))
}

#Preview("Wenge — Long Game") {
    MoveHistoryView(
        moves: [
            "d4", "Nf6", "c4", "e6", "Nf3", "d5", "Nc3", "Be7",
            "Bg5", "h6", "Bh4", "O-O", "e3", "b6", "Bd3", "Bb7",
            "O-O", "Nbd7", "Qe2", "c5", "Rad1", "Rc8", "Bb1", "cxd4",
            "exd4", "dxc4", "Qxc4", "Nd5", "Bg3", "N7f6", "Ne5", "Rc7",
            "Qe2", "Qa8", "f3", "Rd8", "Qf2", "Bb4", "Bc2", "Bxc3",
            "bxc3", "Qc8", "Bd3", "Nd5", "c4", "Nf4", "Bf5", "exf5"
        ],
        classifications: [],
        currentMoveIndex: 38,
        style: .wenge,
        onMoveTapped: { _ in }
    )
    .frame(width: 260, height: 240)
    .background(Color(.windowBackgroundColor))
}

#Preview("Empty State") {
    MoveHistoryView(
        moves: [],
        classifications: [],
        currentMoveIndex: nil,
        style: .walnut,
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
                classifications: [
                    .book, .book, .book, .book, .book, .book,
                    .book, .book, .best, .good, .best, .good,
                    .good, .good, .best, .inaccuracy, .good, .mistake,
                    .good, .blunder
                ],
                currentMoveIndex: 14,
                style: .walnut,
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
