//
//  ContentView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/03/2026.
//

import SwiftUI

internal struct ContentView: View {

    // MARK: Private Properties
    @State private var selection: SidebarSelection = .destination(.board)

    // MARK: Body
    internal var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Favorites") {
                    ForEach(Destination.allCases) { destination in
                        Label(destination.title, systemImage: destination.systemImage)
                            .tag(SidebarSelection.destination(destination))
                    }
                }

                Section("Tags") {
                    ForEach(SmartTag.allCases) { tag in
                        Label {
                            Text(tag.displayName)
                        } icon: {
                            Circle()
                                .fill(tag.color)
                                .frame(width: 10, height: 10)
                        }
                        .tag(SidebarSelection.tag(tag))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selection {
            case .destination(.board):    BoardDestination()
            case .destination(.library):  LibraryDestination(filter: nil)
            case .destination(.players):  PlayersDestination()
            case .destination(.rankings): RankingsDestination()
            case .tag(let tag):           LibraryDestination(filter: tag)
            }
        }
    }
}

internal enum SidebarSelection: Hashable {
    case destination(Destination)
    case tag(SmartTag)
}

internal enum Destination: String, CaseIterable, Identifiable, Hashable {
    case board
    case library
    case players
    case rankings

    internal var id: String { rawValue }

    internal var title: String {
        rawValue.capitalized
    }

    internal var systemImage: String {
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
