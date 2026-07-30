//
//  ContentView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/03/2026.
//

import os
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
///
/// M-prs.5: the Tags section is a `@Query` over the `SmartTag` model
/// with create/edit/delete (the editor sheet works on a value draft —
/// Cancel must never have mutated a live model). `SidebarSelection`
/// carries the tag's `PersistentIdentifier`, not the model: selections
/// must stay `Hashable` and survive the model's deletion gracefully.
///
/// M-prs.6: `.player` is a programmatic-only selection — no sidebar row
/// renders it, so the sidebar shows no highlight while it's active; the
/// Library's filter chip is deliberately both the visible state and the
/// exit. Stale ids degrade to the full Library exactly like `.tag`; the
/// `players` query exists solely for that id → model hop.
internal struct ContentView: View {

    // MARK: Static Constants

    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "smarttags"
    )

    // MARK: Window-Bound State
    
    @Binding internal var loadedGameID: PersistentIdentifier?
    
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
                        // Pointer-only affordance: macOS exposes no
                        // AXButton for a borderless button in a List
                        // section header, and a header `.contextMenu`
                        // never surfaces either — both proven by 29 July
                        // UITest runs. Every other input path (keyboard,
                        // VoiceOver, the UITest suite) goes through
                        // File ▸ New Smart Tag… (`SmartTagCommands`, fed
                        // by the `.focusedSceneValue` below). Witness for
                        // this button: the manual checklist.
                        .accessibilityIdentifier(AccessibilityID.sidebarTagsAdd)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // M-ux.3 (D15′): the sidebar is the master of session
                // info; the stage above the board stays clear. New Game
                // navigates to Board first because the sheet's presenter
                // stayed `BoardDestination` — a modal is destination
                // furniture, and presenting from every tab's ContentView
                // would raise one sheet per open window (session state is
                // app-global).
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
            case .destination(.rankings):
                RankingsDestination(
                    tabState: tabState,
                    onShowInLibrary: { selection = .player($0) }
                )
            case .tag(let id):
                // A deleted tag's stale selection degrades to the full
                // Library (nil filter) instead of trapping on a lookup.
                LibraryDestination(
                    filter: tags.first(where: { $0.id == id }).map(LibraryFilter.smartTag),
                    tabState: tabState,
                    onClearFilter: { selection = .destination(.library) }
                )
            case .player(let id):
                // Programmatic only (M-prs.6): no sidebar row carries
                // this selection — the chip is its one visible face and
                // its exit. Same stale-degrade contract as `.tag`.
                LibraryDestination(
                    filter: players.first(where: { $0.id == id }).map(LibraryFilter.player),
                    tabState: tabState,
                    onClearFilter: { selection = .destination(.library) }
                )
            }
        }
        // The menu-bar door: File ▸ New Smart Tag… drives this binding
        // from `SmartTagCommands` — the `activeGame` pattern, second use.
        // Scene-scoped, so the command reaches whichever tab is frontmost.
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
    
    // MARK: Tag CRUD (M-prs.5)
    
    /// Insert-or-update from the editor's value draft, one save either
    /// way. Update mutates the live model only *here*, after OK.
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
        // Deleting the selected tag falls back to Library *before* the
        // model dies, so the detail switch never renders a stale id.
        if selection == .tag(tag.id) {
            selection = .destination(.library)
        }
        modelContext.delete(tag)
        saveTags(after: "delete")
    }

    /// Tag edits are the one Library write outside `PGNStore`, so they owe
    /// the same must-reach-somewhere trace its saves get — the bare `try?`
    /// this replaces could lose a rename or delete with no Console witness
    /// (30 July audit). Play is never interrupted for a tag: log loudly,
    /// carry on — the `recordError` philosophy without the timeline, which
    /// tags don't have.
    private func saveTags(after operation: String) {
        do {
            try modelContext.save()
        } catch {
            Self.logger.error(
                "Tag \(operation, privacy: .public) failed to save: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

// MARK: Supporting Types

internal enum SidebarSelection: Hashable {
    case destination(Destination)
    case tag(PersistentIdentifier)
    /// Programmatic only (M-prs.6): set by "Show in Library", never by a
    /// sidebar row — the Library filter chip renders and clears it.
    case player(PersistentIdentifier)
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
        case .board:    "checkerboard.rectangle"
        case .library:  "books.vertical"
        case .players:  "person.2"
        case .rankings: "list.number"
        }
    }
}

// MARK: Previews

#Preview {
    ContentView(loadedGameID: .constant(nil))
        // All three models, explicitly — the App container's load-bearing
        // invariant applies to canvases too: this body runs a `@Query`
        // over `SmartTag`, which has no relationships, so inference from
        // `PGN` alone never pulls it into the schema and the canvas
        // traps on the query.
        .modelContainer(for: [PGN.self, Player.self, SmartTag.self], inMemory: true)
        .environment(OpenGamesRegistry())
        .environment(DGTConnection())
        .environment(DGTLiveSession())
        .environment(DGTSessionLog())
        .frame(width: 800, height: 600)
}
