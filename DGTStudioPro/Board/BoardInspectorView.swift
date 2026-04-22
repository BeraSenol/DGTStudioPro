//
//  BoardInspectorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/04/2026.
//

import SwiftUI

internal struct BoardInspectorView: View {
    
    // MARK: Stored Properties
    internal let pgn: PGN?
    internal let evaluations: [Double]
    internal let moves: [String]
    internal let currentMoveIndex: Int?
    internal let style: BoardStyle
    internal let onMoveTapped: ((Int) -> Void)?
    
    // MARK: Body
    internal var body: some View {
        List {
            metadataSection
            evaluationSection
            movesSection
        }
        .listStyle(.sidebar)
    }
    
    // MARK: Instance Methods
    private var metadataSection: some View {
        Section {
            LabeledContent("White", value: pgn?.white ?? "—")
            LabeledContent("Black", value: pgn?.black ?? "—")
            LabeledContent("Round", value: pgn?.displayRound ?? "—")
            LabeledContent("Result", value: pgn?.result.rawValue ?? "—")
        } header: {
            Text("Game")
        }
    }
    
    private var evaluationSection: some View {
        Section {
            EvaluationGraphView(
                evaluations: evaluations,
                currentMoveIndex: currentMoveIndex,
                style: style
            )
            .frame(height: 140)
        } header: {
            Text("Evaluation")
        }
    }
    
    private var movesSection: some View {
        Section {
            MoveHistoryView(
                moves: moves,
                currentMoveIndex: currentMoveIndex,
                style: style,
                onMoveTapped: onMoveTapped
            )
            .frame(height: 240)
        } header: {
            Text("Moves")
        }
    }
}

// MARK: Previews
#Preview("Game Data") {BoardInspectorView(
    pgn: PGN(
        event: "World Championship",
        site: "Dubai",
        round: 7,
        white: "Carlsen",
        black: "Nepomniachtchi",
        result: .ongoing
    ),
    evaluations: [
        0.50, 0.52, 0.51, 0.49, 0.50, 0.52, 0.50, 0.48,
        0.46, 0.44, 0.46, 0.44, 0.42, 0.44, 0.43, 0.45,
        0.42, 0.40, 0.42, 0.44, 0.41, 0.38, 0.40, 0.42,
        0.38, 0.35, 0.37, 0.40, 0.36, 0.32, 0.35, 0.30,
        0.34, 0.42, 0.50, 0.58, 0.72, 0.88, 0.96
    ],
    moves: [
        "e4", "e5", "Nf3", "Nc6", "Bb5", "a6",
        "Ba4", "Nf6", "O-O", "Be7", "Re1", "b5",
        "Bb3", "d6", "c3", "O-O", "h3", "Nb8",
        "d4", "Nbd7"
    ],
    currentMoveIndex: 14,
    style: .walnut,
    onMoveTapped: { _ in }
)
.frame(width: 300, height: 600)
}

#Preview("No Game Data") {
    BoardInspectorView(
        pgn: nil,
        evaluations: [],
        moves: [],
        currentMoveIndex: nil,
        style: .walnut,
        onMoveTapped: nil
    )
    .frame(width: 300, height: 400)
}
