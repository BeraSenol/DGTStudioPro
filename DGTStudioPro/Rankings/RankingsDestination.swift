//
//  RankingsDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import SwiftUI

internal struct RankingsDestination: View {
    
    // MARK: Private Properties
    @State private var isInspectorPresented: Bool = false
    
    // MARK: Body
    internal var body: some View {
        ContentUnavailableView(
            "Rankings",
            systemImage: "list.number",
            description: Text("Rankings coming soon.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .inspector(isPresented: $isInspectorPresented) {
            RankingsInspectorView()
                .inspectorColumnWidth(min: 260, ideal: 320, max: 400)
        }
        .inspectorToggle(isPresented: $isInspectorPresented)
    }
}
