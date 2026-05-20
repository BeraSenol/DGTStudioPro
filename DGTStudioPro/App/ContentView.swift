//
//  ContentView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/03/2026.
//

import SwiftUI
import SwiftData

internal struct ContentView: View {

    // MARK: Private Properties

    /// App-level state — open tabs, sidebar selection. Owned here
    /// (single source of truth for "where is the user looking?") and
    /// injected into the environment so descendants can read or mutate
    /// it without callback threading. See Phase 9 design notes for the
    /// rationale on why this object exists and lives at this level.
    @State private var appState = AppState()

    // MARK: Body

    internal var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            sidebar(selection: $appState.sidebarSelection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            destinationView(for: appState.sidebarSelection)
        }
        .environment(appState)
    }

    // MARK: Instance Methods

    private func sidebar(selection: Binding<SidebarSelection>) -> some View {
        List(selection: selection) {
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
    }

    @ViewBuilder
    private func destinationView(for selection: SidebarSelection) -> some View {
        switch selection {
        case .destination(.board):    BoardDestination()
        case .destination(.library):  LibraryDestination(filter: nil)
        case .destination(.players):  PlayersDestination()
        case .destination(.rankings): RankingsDestination()
        case .tag(let tag):           LibraryDestination(filter: tag)
        }
    }
}

// MARK: - Supporting Types

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

// MARK: - Previews

#Preview {
    ContentView()
        .modelContainer(for: PGN.self, inMemory: true)
}
