//
//  LibraryDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import os
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

internal struct LibraryDestination: View {

    // MARK: Static Constants
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "library"
    )

    // MARK: Stored Properties
    internal let filter: SmartTag?

    // MARK: Private Properties
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut
    @AppStorage(StorageKeys.libraryViewMode) private var viewMode: CollectionViewMode = .list
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PGN.importedAt, order: .reverse) private var games: [PGN]
    @State private var pendingDeletion: PGN?
    @State private var selectedPGNs: Set<PGN.ID> = []
    @State private var isInspectorPresented: Bool = false
    @State private var importError: ImportError?

    // MARK: Initializers
    internal init(filter: SmartTag? = nil) {
        self.filter = filter
    }

    // MARK: Computed Properties
    private var filteredGames: [PGN] {
        guard let filter else { return games }
        return games.filter { filter.matches($0) }
    }

    private var selectedPGN: PGN? {
        guard let id = selectedPGNs.first else { return nil }
        return filteredGames.first(where: { $0.id == id })
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )
    }

    private var pendingDeletionBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    private var importErrorTitle: String {
        guard let importError else { return "" }
        switch importError.error {
        case .duplicate:           return "Already Imported"
        case .missingRequiredTags: return "Missing Required Tags"
        case .malformedPGN:        return "Malformed PGN"
        case .fileReadFailed:      return "Couldn't Read File"
        }
    }

    // MARK: Body
    internal var body: some View {
        Group {
            if filteredGames.isEmpty {
                emptyState
            } else {
                modeView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dropDestination(for: URL.self) { urls, _ in
            importURLs(urls)
            return true
        }
        .inspector(isPresented: $isInspectorPresented) {
            LibraryInspectorView(pgn: selectedPGN)
                .inspectorColumnWidth(min: 260, ideal: 300, max: 400)
        }
        .toolbar { toolbarContent }
        .alert(
            importErrorTitle,
            isPresented: importErrorBinding,
            presenting: importError,
            actions: { error in importErrorActions(for: error) },
            message: { error in importErrorMessage(for: error) }
        )
        .alert(
            "Delete Game?",
            isPresented: pendingDeletionBinding,
            presenting: pendingDeletion,
            actions: { game in
                Button("Delete", role: .destructive) { delete(game) }
                Button("Cancel", role: .cancel) {}
            },
            message: { game in
                Text("\(game.name) will be permanently deleted.")
            }
        )
        .onDeleteCommand {
            if let selected = selectedPGN { pendingDeletion = selected }
        }
        .onAppear {
            backfillEmptyNames()
            if viewMode == .gallery { isInspectorPresented = true }
        }
        .onChange(of: viewMode) { _, mode in
            if mode == .gallery { isInspectorPresented = true }
        }
    }

    // MARK: Instance Methods
    @ViewBuilder
    private var modeView: some View {
        switch viewMode {
        case .icons:
            LibraryIconsView(
                games: filteredGames,
                selectedPGNs: $selectedPGNs,
                onDelete: { pendingDeletion = $0 }
            )
        case .list:
            LibraryListView(
                games: filteredGames,
                selectedPGNs: $selectedPGNs,
                onDelete: { pendingDeletion = $0 }
            )
        case .columns:
            LibraryColumnsView(
                games: filteredGames,
                selectedPGNs: $selectedPGNs,
                boardStyle: boardStyle,
                onDelete: { pendingDeletion = $0 }
            )
        case .gallery:
            LibraryGalleryView(
                games: filteredGames,
                selectedPGNs: $selectedPGNs,
                boardStyle: boardStyle,
                onDelete: { pendingDeletion = $0 }
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Picker("View Mode", selection: $viewMode) {
                ForEach(CollectionViewMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        ToolbarSpacer()
        ToolbarItem {
            Button(action: presentOpenPanel) {
                Label("Import PGN", systemImage: "square.and.arrow.down")
            }
        }
        ToolbarSpacer()
        ToolbarItem {
            Button {
                isInspectorPresented.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.trailing")
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let filter {
            ContentUnavailableView {
                Label("No \(filter.displayName) Games", systemImage: "tag")
            } description: {
                Text("No games match this tag yet.")
            }
        } else {
            ContentUnavailableView {
                Label("No Games", systemImage: "books.vertical")
            } description: {
                Text("Import a PGN file to get started.")
            }
        }
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "pgn") ?? .plainText]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            importURLs(panel.urls)
        }
    }

    private func importURLs(_ urls: [URL]) {
        let store = PGNStore(modelContext: modelContext)

        for url in urls {
            do {
                try store.importPGN(from: url)
            } catch let error as PGNStore.Error {
                Self.logger.error("Import failed for \(url.lastPathComponent, privacy: .public)")
                importError = ImportError(url: url, error: error)
                return
            } catch {
                Self.logger.error("Import failed for \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                importError = ImportError(url: url, error: .fileReadFailed(url, underlying: error))
                return
            }
        }
    }

    @ViewBuilder
    private func importErrorActions(for error: ImportError) -> some View {
        switch error.error {
        case .duplicate(let existing):
            Button("View Existing") {
                selectedPGNs = [existing.id]
            }
            Button("Cancel", role: .cancel) {}
        case .missingRequiredTags, .malformedPGN, .fileReadFailed:
            Button("OK", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func importErrorMessage(for error: ImportError) -> some View {
        switch error.error {
        case .duplicate(let existing):
            Text("\(existing.name) is already in your library.")
        case .missingRequiredTags(let tags):
            Text("The PGN is missing: \(tags.sorted().joined(separator: ", ")).")
        case .malformedPGN(let reason):
            Text(reason)
        case .fileReadFailed(let url, _):
            Text("Failed to read \(url.lastPathComponent).")
        }
    }

    private func delete(_ pgn: PGN) {
        selectedPGNs.remove(pgn.id)

        let store = PGNStore(modelContext: modelContext)
        do {
            try store.delete(pgn)
        } catch {
            Self.logger.error("Failed to delete PGN: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func backfillEmptyNames() {
        let toFix = games.filter { game in
            game.name.isEmpty || game.name == game.legacyDefaultName
        }
        guard !toFix.isEmpty else { return }
        for game in toFix {
            game.name = game.defaultDisplayName
        }
        do {
            try modelContext.save()
            Self.logger.info("Backfilled names for \(toFix.count) game(s)")
        } catch {
            Self.logger.error("Name backfill save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: Supporting Types
private struct ImportError: Identifiable {
    let id = UUID()
    let url: URL
    let error: PGNStore.Error
}

// MARK: Previews
#Preview("With Games") {
    let container = try! ModelContainer(
        for: PGN.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let samples: [PGN] = [
        PGN(event: "World Championship", site: "Dubai", round: 11,
            white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian", result: .whiteWins),
        PGN(event: "Tata Steel Masters", site: "Wijk aan Zee", round: 7,
            white: "Giri, Anish", black: "Caruana, Fabiano", result: .draw),
        PGN(event: "Norway Chess", site: "Stavanger", round: 3,
            white: "Firouzja, Alireza", black: "Ding, Liren", result: .blackWins)
    ]
    for sample in samples { container.mainContext.insert(sample) }

    return NavigationSplitView {
        List { Label("Library", systemImage: "books.vertical") }
            .navigationSplitViewColumnWidth(min: 80, ideal: 100, max: 120)
    } detail: {
        LibraryDestination()
    }
    .modelContainer(container)
}

#Preview("Empty") {
    NavigationSplitView {
        List { Label("Library", systemImage: "books.vertical") }
            .navigationSplitViewColumnWidth(min: 80, ideal: 100, max: 120)
    } detail: {
        LibraryDestination()
    }
    .modelContainer(for: PGN.self, inMemory: true)
}
