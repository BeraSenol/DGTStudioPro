//
//  ContentView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/03/2026.
//

import SwiftUI

internal struct ContentView: View {
    
    // MARK: Private Properties
    @State private var selection: Destination = .board
    
    // MARK: Body
    internal var body: some View {
        NavigationSplitView {
            List(Destination.allCases, selection: $selection) { destination in
                Label(destination.title, systemImage: destination.systemImage)
                    .tag(destination)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selection {
            case .board:    BoardDestination()
            case .library:  LibraryDestination()
            case .players:  PlayersDestination()
            case .rankings: RankingsDestination()
            }
        }
    }
}

private enum Destination: String, CaseIterable, Identifiable {
    case board
    case library
    case players
    case rankings
    
    var id: String { rawValue }
    
    var title: String {
        rawValue.capitalized
    }
    
    var systemImage: String {
        switch self {
        case .board:    return "checkerboard.rectangle"
        case .library:  return "books.vertical"
        case .players:  return "person.2"
        case .rankings: return "list.number"
        }
    }
}

// MARK: Previews
#Preview {
    ContentView()
}
