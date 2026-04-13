//
//  BoardDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/04/2026.
//

import SwiftUI

internal struct BoardDestination: View {
    
    // MARK: Private Properties
    @State private var isInspectorPresented: Bool = true
    
    // MARK: Body
    internal var body: some View {
        BoardView(
            position: .empty,
            pieceTracker: .empty,
            style: .walnut,
            perspective: .white,
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
                    isInspectorPresented.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
            }
        }
    }
}
