import os
import SwiftData
import SwiftUI

/// Root of every tab: per-tab sidebar selection and `TabState`, bound to the window's
/// `PersistentIdentifier?`. `SidebarSelection` carries identifiers, never models — a selection must
/// stay `Hashable` and survive its subject's deletion.
struct ContentView: View {
    
    // MARK: Static Constants
    
    private static let logger = AppLog.logger(.smarttags)
    
    // MARK: Window-Bound State
    
    @Binding var loadedGameID: PersistentIdentifier?
    
    // MARK: Per-Tab State
    
    @State private var selection: SidebarSelection
    @State private var tabState = TabState()
    
    // MARK: Tags
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    /// `sortIndex` first, `createdAt` breaking the all-zero tie into exactly the pre-reorder order,
    /// so the migration is invisible until the first drag.
    @Query(sort: [
        SortDescriptor(\SmartTag.sortIndex),
        SortDescriptor(\SmartTag.createdAt),
    ]) private var tags: [SmartTag]
    @State private var newTagRequested = false
    @State private var pendingTagDeletion: SmartTag?
    
    // MARK: Players
    
    @Query(sort: \Player.name) private var players: [Player]
    
    // MARK: Initializer
    
    init(loadedGameID: Binding<PersistentIdentifier?>) {
        self._loadedGameID = loadedGameID
        let initial: SidebarSelection = loadedGameID.wrappedValue != nil
        ? .destination(.board)
        : .destination(.library)
        self._selection = State(initialValue: initial)
    }
    
    // MARK: Body
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Favorites") {
                    ForEach(Destination.allCases) { destination in
                        Label(destination.displayName, systemImage: destination.systemImage)
                            .tag(SidebarSelection.destination(destination))
                            .accessibilityIdentifier(AccessibilityID.sidebarDestination(destination.rawValue))
                    }
                }
                
                Section {
                    ForEach(tags) { tag in
                        Label {
                            Text(tag.name)
                        } icon: {
                            Circle()
                                .fill(tag.color)
                                .frame(width: 10, height: 10)
                        }
                        .tag(SidebarSelection.tag(tag.id))
                        .accessibilityIdentifier(AccessibilityID.sidebarTag(tag.name))
                        .contextMenu {
                            Button {
                                openWindow(value: SmartTagEditorRequest.edit(tag.id))
                            } label: {
                                Label("Edit Tag", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                pendingTagDeletion = tag
                            } label: {
                                Label("Delete Tag", systemImage: "trash")
                            }
                        }
                    }
                    .onMove(perform: moveTags)
                } header: {
                    HStack {
                        Text("Tags")
                        Spacer()
                        Button {
                            openWindow(value: SmartTagEditorRequest.new)
                        } label: {
                            Image(systemName: "plus")
                                .padding(.trailing, 8)
                        }
                        .buttonStyle(.borderless)
                        .help("Create a new smart tag")
                        // Pointer-only: macOS exposes no AXButton for a borderless button in a List
                        // section header, so the identifier below is unreachable and the menu-bar
                        // door is the AX route.
                        .accessibilityIdentifier(AccessibilityID.sidebarTagsAdd)
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
                LibraryDestination(
                    filter: nil,
                    tabState: tabState,
                    onOpenInPlace: openGameInThisTab
                )
            case .destination(.players):
                PlayersDestination(
                    tabState: tabState,
                    onShowInLibrary: { selection = .player($0) }
                )
            case .tag(let id):
                // A deleted tag's stale selection degrades to the full Library rather than trapping.
                LibraryDestination(
                    filter: tags.first(where: { $0.id == id }).map(LibraryFilter.smartTag),
                    tabState: tabState,
                    onClearFilter: { selection = .destination(.library) },
                    onOpenInPlace: openGameInThisTab
                )
            case .player(let id):
                // The chip is this selection's one visible face and its only exit. Same
                // stale-degrade contract as `.tag`.
                LibraryDestination(
                    filter: players.first(where: { $0.id == id }).map(LibraryFilter.player),
                    tabState: tabState,
                    onClearFilter: { selection = .destination(.library) },
                    onOpenInPlace: openGameInThisTab
                )
            }
        }
        // File ▸ New Smart Tag… sets the trigger and this view opens the window, because a
        // `Commands` scene has no `openWindow`.
        .focusedSceneValue(\.newSmartTagRequested, $newTagRequested)
        .onChange(of: newTagRequested) { _, requested in
            guard requested else { return }
            newTagRequested = false
            openWindow(value: SmartTagEditorRequest.new)
        }
        .alert(
            "Delete Tag?",
            isPresented: Binding(present: $pendingTagDeletion),
            presenting: pendingTagDeletion
        ) { tag in
            Button("Delete \"\(tag.name)\"", role: .destructive) {
                delete(tag)
            }
            Button("Cancel", role: .cancel) {}
        } message: { tag in
            Text("The tag is removed from the sidebar. No games are affected.")
        }
    }
    
    // MARK: Opening Games
    
    /// Double-click's route: the game lands in **this** tab. Only this view can do it — the
    /// window's `loadedGameID` and the sidebar selection are both its state. Every Library variant
    /// hands the same closure down, so the gesture means one thing wherever the reader is standing.
    private func openGameInThisTab(_ pgn: PGN) {
        loadedGameID = pgn.persistentModelID
        selection = .destination(.board)
    }
    
    // MARK: Tag CRUD
    
    // Save lives in `SmartTagEditorWindow`, which owns the editor. Delete stays here: the alert is
    // this view's, and the selection fallback below needs `selection`.
    
    /// Rewrites the whole run 0..n — a handful of rows, and partial renumbering is how two tags
    /// end up sharing an index.
    private func moveTags(from source: IndexSet, to destination: Int) {
        var reordered = tags
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, tag) in reordered.enumerated() where tag.sortIndex != index {
            tag.sortIndex = index
        }
        saveTags(after: "reorder")
    }
    
    private func delete(_ tag: SmartTag) {
        // Fall back to Library *before* the model dies, so the detail switch never renders a stale id.
        if selection == .tag(tag.id) {
            selection = .destination(.library)
        }
        modelContext.delete(tag)
        saveTags(after: "delete")
    }
    
    /// Tag edits are the one Library write outside `PGNStore`, so they owe the same
    /// must-reach-somewhere trace: a bare `try?` can lose a delete silently.
    private func saveTags(after operation: String) {
        do {
            try modelContext.save()
        } catch {
            Self.logger?.error(
                "Tag \(operation, privacy: .public) failed to save: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

// MARK: Supporting Types

enum SidebarSelection: Hashable {
    case destination(Destination)
    case tag(PersistentIdentifier)
    /// Programmatic only, with no sidebar row: set by "Show in Library", cleared by the filter chip.
    case player(PersistentIdentifier)
}

enum Destination: String, CaseIterable, Identifiable, Hashable {
    case board
    case library
    case players
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var systemImage: String {
        switch self {
        case .board:    "checkerboard.rectangle"
        case .library:  "books.vertical"
        case .players:  "person.2"
        }
    }
}

// MARK: Previews

#Preview {
    ContentView(loadedGameID: .constant(nil))
    // All three models explicitly - `SmartTag` has no relationships, so inference from `PGN` never
    // pulls it in and the canvas would trap on the query.
        .modelContainer(for: [PGN.self, Player.self, SmartTag.self], inMemory: true)
    // Every environment object the destinations read must be injected here, or the canvas traps
    // on the first read rather than rendering an empty state.
        .environment(OpenGamesRegistry())
        .environment(DGTConnection())
        .environment(DGTLiveSession())
        .environment(DGTSessionLog())
        .environment(AnalysisQueueController())
        .environment(PreviewFixtures.viewOptions())
        .frame(width: 800, height: 600)
        .environment(InspectorSectionCollapse.preview)
    // Inaudible: a canvas that re-renders on every keystroke must not click.
        .environment(BoardSounds.preview)
}
