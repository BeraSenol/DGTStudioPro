import os
import SwiftData
import SwiftUI

/// Root of every tab: per-tab sidebar selection, per-tab `TabState`, bound to the window's
/// `PersistentIdentifier?`. `SidebarSelection` carries identifiers, never models — selections
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
    @Query(sort: \SmartTag.createdAt) private var tags: [SmartTag]
    @State private var editorDraft: TagDraft?
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
                                editorDraft = TagDraft(editing: tag)
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
                } header: {
                    HStack {
                        Text("Tags")
                        Spacer()
                        Button {
                            editorDraft = TagDraft()
                        } label: {
                            Image(systemName: "plus")
                                .padding(.trailing, 8)
                        }
                        .buttonStyle(.borderless)
                        .help("New Smart Tag")
                        // Pointer-only affordance: macOS exposes no AXButton for a borderless button in a List section
                        // header — proven 29 July; the menu-bar door is the AX-reachable one.
                        .accessibilityIdentifier(AccessibilityID.sidebarTagsAdd)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // D15′: the sidebar owns session info. New Game navigates to Board first — the sheet's
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
        // The menu-bar door: File ▸ New Smart Tag… drives this binding (the `activeGame` pattern).
        .focusedSceneValue(\.tagEditorDraft, $editorDraft)
        .sheet(item: $editorDraft) { draft in
            SmartTagEditorView(draft: draft) { finished in
                commit(finished)
            }
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
    
    /// Insert-or-update from the editor's draft, one save either way — the live model mutates only
    /// here, after OK.
    private func commit(_ draft: TagDraft) {
        if let tag = draft.editing {
            tag.name = draft.name
            tag.colorName = draft.colorName
            tag.matchAll = draft.matchAll
            tag.rules = draft.rules
        } else {
            modelContext.insert(
                SmartTag(
                    name: draft.name,
                    colorName: draft.colorName,
                    matchAll: draft.matchAll,
                    rules: draft.rules
                )
            )
        }
        saveTags(after: "commit")
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
    /// must-reach-somewhere trace — the bare `try?` this replaces could lose a delete silently.
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
    // `rankings` retired by D48′ — the selection stores the enum, so the deletion is total at
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
        // All three models explicitly — `SmartTag` has no relationships, so inference from `PGN` never
        // pulls it in and the canvas would trap on the query.
        .modelContainer(for: [PGN.self, Player.self, SmartTag.self], inMemory: true)
        .environment(OpenGamesRegistry())
        .environment(DGTConnection())
        .environment(DGTLiveSession())
        .environment(DGTSessionLog())
        .frame(width: 800, height: 600)
        .environment(InspectorSectionCollapse.preview)
        // D81′ — `BoardDestination` reads it, so the canvas traps without it. The `.preview`
        // instance is inaudible: a canvas that re-renders on every keystroke must not click.
        .environment(BoardSounds.preview)
}
