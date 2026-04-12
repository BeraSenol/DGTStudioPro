//
//  RankingsDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import SwiftUI

internal struct RankingsDestination: View {
    
    // MARK: Private Properties
    @State private var isInspectorPresented: Bool = true
    
    // MARK: Body
    internal var body: some View {
        Text("Rankings")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .inspector(isPresented: $isInspectorPresented) {
                RankingsInspectorView()
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
