//
//  BoardDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/04/2026.
//

import SwiftUI

internal struct BoardDestination: View {
    
    // MARK: Private Properties
    @AppStorage("boardStyle") private var boardStyle: BoardStyle = .walnut
    @State private var perspective: PieceColor = .white
    @State private var isInspectorPresented: Bool = true

    // MARK: Body
    internal var body: some View {
        BoardView(
            position: .empty,
            pieceTracker: .empty,
            style: boardStyle,
            perspective: perspective,
            lastMove: nil,
            checkSquare: nil,
            selectedSquare: nil
        )
        .padding()
        .inspector(isPresented: $isInspectorPresented) {
            BoardInspectorView(
                pgn: nil,
                evaluations: [],
                moves: [],
                currentMoveIndex: nil,
                style: boardStyle,
                onMoveTapped: nil
            )
            .inspectorColumnWidth(min: 260, ideal: 300, max: 400)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    perspective = perspective.opponent
                } label: {
                    Label("Flip Board", systemImage: "arrow.up.arrow.down")
                }
            }
            ToolbarItem {
                Button {
                    isInspectorPresented.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
            }
        }
    }
}

// MARK: Previews
#Preview("Board Destination") {
    NavigationSplitView {
        List {
            Label("Board", systemImage: "checkerboard.rectangle")
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    } detail: {
        BoardDestination()
    }
}

#Preview("Standalone") {
    BoardDestination()
}
