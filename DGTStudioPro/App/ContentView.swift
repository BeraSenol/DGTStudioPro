import os
import SwiftData
import SwiftUI

/// Root of every tab: per-tab sidebar selection, per-tab `TabState`, bound to the window's
/// `PersistentIdentifier?`. `SidebarSelection` carries identifiers, never models - selections
/// must stay `Hashable` and survive deletion. `.player` is programmatic-only (no sidebar row).
struct ContentView: View {

    // MARK: Static Constants

    private static let logger = AppLog.logger(.smarttags)

    // MARK: Window-Bound State
    
    @Binding var loadedGameID: PersistentIdentifier?
    
    // MARK: Per-Tab State
    
    @State private var selection: SidebarSelection
    @State private var tabState = TabState()
    
    // MARK: Tags (M-prs.5)
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    /// `sortIndex` first (drag-to-reorder, 16 Aug 2026), `createdAt` breaking the all-zero tie
    /// exactly into the pre-reorder order - so the migration is invisible until the first drag.
    @Query(sort: [
        SortDescriptor(\SmartTag.sortIndex),
        SortDescriptor(\SmartTag.createdAt),
    ]) private var tags: [SmartTag]
    /// The menu-bar door's trigger (the `boardGetInfoRequest` shape) - the editor is a window
    /// since 16 Aug 2026, so the focused value carries a request, no longer a draft.
    @State private var newTagRequested = false
    @State private var pendingTagDeletion: SmartTag?
    
    // MARK: Players (M-prs.6)
    
    @Query(sort: \Player.name) private var players: [Player]
    
    // MARK: Initializer
    
    init(loadedGameID: Binding<PersistentIdentifier?>) {
        self._loadedGameID = loadedGameID
        // Start on Board for tabs opened with a specific game, on
        // Library for tabs opened blank.
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
                        Label(destination.title, systemImage: destination.systemImage)
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
                        .help("New Smart Tag")
                        // Pointer-only affordance: macOS exposes no AXButton for a borderless button in a List section
                        // header - proven 29 July; the menu-bar door is the AX-reachable one.
                        .accessibilityIdentifier(AccessibilityID.sidebarTagsAdd)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // The sidebar owns session info. New Game navigates to Board first - the sheet's
                // presenter stays `BoardDestination`.
                SessionSidebarPanel(
                    tabState: tabState,
                    onNewGame: {
                        selection = .destination(.board)
                        tabState.manualNewGameRequested = true
                    },
                    onDismissLoadError: { loadedGameID = nil }
                )
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
                PlayersDestination(
                    tabState: tabState,
                    onShowInLibrary: { selection = .player($0) }
                )
            case .tag(let id):
                // A deleted tag's stale selection degrades to the full Library rather than trapping.
                LibraryDestination(
                    filter: tags.first(where: { $0.id == id }).map(LibraryFilter.smartTag),
                    tabState: tabState,
                    onClearFilter: { selection = .destination(.library) }
                )
            case .player(let id):
                // Programmatic only: the chip is this selection's one visible face and exit. Same
                // stale-degrade contract as `.tag`.
                LibraryDestination(
                    filter: players.first(where: { $0.id == id }).map(LibraryFilter.player),
                    tabState: tabState,
                    onClearFilter: { selection = .destination(.library) }
                )
            }
        }
        // The menu-bar door: File ▸ New Smart Tag… sets the trigger; this view opens the window
        // (a `Commands` scene has no `openWindow` - the Get Info trigger's arrangement, fourth use).
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
    
    // MARK: Tag CRUD (M-prs.5)

    // `commit` moved whole into `SmartTagEditorWindow` with the editor (16 Aug 2026): a window
    // owns its own save, where a sheet handed the draft back. Delete stays - the alert is this
    // view's, and the selection fallback below needs `selection`.

    /// Reorder from the sidebar drag (16 Aug 2026): rewrite the whole run 0..n - a handful of
    /// rows, and partial renumbering is how two tags end up sharing an index.
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
    /// must-reach-somewhere trace - the bare `try?` this replaces could lose a delete silently.
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
    /// Programmatic only: set by "Show in Library"; the filter chip renders and clears it.
    case player(PersistentIdentifier)
}

enum Destination: String, CaseIterable, Identifiable, Hashable {
    case board
    case library
    case players
    // `rankings` retired - the selection stores the enum, so the deletion is total at
    // compile time.

    var id: String { rawValue }

    var title: String {
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
        .environment(OpenGamesRegistry())
        .environment(DGTConnection())
        .environment(DGTLiveSession())
        .environment(DGTSessionLog())
        .frame(width: 800, height: 600)
        .environment(InspectorSectionCollapse.preview)
        // `BoardDestination` reads it, so the canvas traps without it. The `.preview`
        // instance is inaudible: a canvas that re-renders on every keystroke must not click.
        .environment(BoardSounds.preview)
}
