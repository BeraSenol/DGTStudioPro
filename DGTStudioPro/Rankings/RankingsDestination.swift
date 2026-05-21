//
//  RankingsDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import SwiftUI

internal struct RankingsDestination: View {
    
    // MARK: Tab State (lives on enclosing `ContentView`)
    @Bindable internal var tabState: TabState
    
    // MARK: Body
    internal var body: some View {
        ContentUnavailableView(
            "Rankings",
            systemImage: "list.number",
            description: Text("Rankings coming soon.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .inspector(isPresented: $tabState.rankingsInspectorPresented) {
            RankingsInspectorView()
                .inspectorColumnWidth(min: 260, ideal: 320, max: 400)
        }
        .inspectorToggle(isPresented: $tabState.rankingsInspectorPresented)
    }
}

// MARK: - Previews

#Preview {
    RankingsDestination(tabState: TabState())
}
