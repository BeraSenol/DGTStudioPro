//
//  PlayersDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import SwiftUI

internal struct PlayersDestination: View {
    
    // MARK: Private Properties
    @State private var isInspectorPresented: Bool = true
    
    // MARK: Body
    internal var body: some View {
        Text("Players")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .inspector(isPresented: $isInspectorPresented) {
                PlayersInspectorView()
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
