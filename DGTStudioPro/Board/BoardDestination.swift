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
            position: .starting,
            pieceTracker: .empty,
            style: boardStyle,
            perspective: perspective,
            lastMove: nil,
            checkSquare: nil,
            selectedSquare: nil
        )
        .padding()
        .inspector(isPresented: $isInspectorPresented) {
            BoardInspectorView()
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
