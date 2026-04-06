//
//  ContentView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/03/2026.
//

import SwiftUI
import SwiftData

internal struct ContentView: View {
    // MARK: - Stored Properties
    @Environment(\.modelContext) private var modelContext

    // MARK: - Body
    var body: some View {
        NavigationSplitView {
            List {

            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            BoardView(
                position: Position(),
                pieceTracker: PieceTracker.empty,
                style: .walnut,
                perspective: .white,
                lastMove: nil,
                checkSquare: nil,
                selectedSquare: nil
            )
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
