//
//  ContentView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/03/2026.
//

import SwiftUI
import SwiftData

internal struct ContentView: View {
    // MARK: Stored Properties
    @Environment(\.modelContext) private var modelContext
    
    // MARK: Body
    internal var body: some View {
        NavigationSplitView {
            List {
                
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            BoardDestination()
        }
    }
}

#Preview {
    ContentView()
}
