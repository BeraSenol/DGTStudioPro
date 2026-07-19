//
//  ContentView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/03/2026.
//

import SwiftData
import SwiftUI

/// Root content of every tab in the unified `WindowGroup`. Each tab
/// has its own sidebar selection (`@State`), its own per-tab state
/// bundle (`TabState`), and is bound to a per-window
/// `PersistentIdentifier?` from the `WindowGroup`.
///
/// Tabs opened from `openWindow(value: pgn.persistentModelID)` start
/// with the sidebar on Board, showing the loaded game. The first tab
/// at app launch (and any tab opened via ⌘N) has a nil bound value
/// and starts on Library.
///
/// `TabState` is owned here (rather than on each destination) so the
/// state survives the destination view being recreated when the user
/// switches the sidebar. See `TabState` for the rationale.
internal struct ContentView: View {

    // MARK: Window-Bound State

    @Binding internal var loadedGameID: PersistentIdentifier?

    // MARK: Per-Tab State

    @State private var selection: SidebarSelection
    @State private var tabState = TabState()

    // MARK: Initializer

    internal init(loadedGameID: Binding<PersistentIdentifier?>) {
        self._loadedGameID = loadedGameID
        // Start on Board for tabs opened with a specific game, on
        // Library for tabs opened blank.
        let initial: SidebarSelection = loadedGameID.wrappedValue != nil
        ? .destination(.board)
        : .destination(.library)
        self._selection = State(initialValue: initial)
    }

    // MARK: Body

    internal var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Favorites") {
                    ForEach(Destination.allCases) { destination in
                        Label(destination.title, systemImage: destination.systemImage)
                            .tag(SidebarSelection.destination(destination))
                            .accessibilityIdentifier(AccessibilityID.sidebarDestination(destination.rawValue))
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
                        .accessibilityIdentifier(AccessibilityID.sidebarTag(tag.rawValue))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .accessibilityIdentifier(AccessibilityID.sidebar)
        } detail: {
            switch selection {
            case .destination(.board):
                BoardDestination(loadedGameID: $loadedGameID, tabState: tabState)
            case .destination(.library):
                LibraryDestination(filter: nil, tabState: tabState)
            case .destination(.players):
                PlayersDestination(tabState: tabState)
            case .destination(.rankings):
                RankingsDestination(tabState: tabState)
            case .tag(let tag):
                LibraryDestination(filter: tag, tabState: tabState)
            }
        }
        .onDisappear {
            // Tab teardown. `ContentView` is the window/tab root: it
            // disappears when the tab closes, never on destination
            // switches (those recreate the *detail* views only) — which
            // is exactly the boundary the analysis queue should die at.
            // A batch survives Board↔Library round-trips (TabState's
            // whole purpose) and stands down with its tab, releasing the
            // Stockfish subprocess.
            let analysisQueue = tabState.analysisQueue
            Task { await analysisQueue.shutdown() }
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
    ContentView(loadedGameID: .constant(nil))
        .modelContainer(for: PGN.self, inMemory: true)
}
