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

    // MARK: Private Properties
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut
    @AppStorage(StorageKeys.libraryViewMode) private var viewMode: CollectionViewMode = .list
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PGN.importedAt, order: .reverse) private var games: [PGN]
    @State private var pendingDeletion: PGN?
    @State private var selectedPGNs: Set<PGN.ID> = []
    @State private var isInspectorPresented: Bool = false
    @State private var importError: ImportError?

    // MARK: Computed Properties
    private var selectedPGN: PGN? {
        guard let id = selectedPGNs.first else { return nil }
        return games.first(where: { $0.id == id })
    }

    // MARK: Body
    internal var body: some View {
        Group {
            if games.isEmpty {
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
        .alert(item: $importError, content: alert(for:))
        .alert(item: $pendingDeletion, content: deletionAlert(for:))
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
                games: games,
                selectedPGNs: $selectedPGNs,
                onDelete: { pendingDeletion = $0 }
            )
        case .list:
            LibraryListView(
                games: games,
                selectedPGNs: $selectedPGNs,
                onDelete: { pendingDeletion = $0 }
            )
        case .columns:
            ContentUnavailableView(
                "Columns",
                systemImage: "hammer",
                description: Text("Columns view coming soon.")
            )
        case .gallery:
            LibraryGalleryView(
                games: games,
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Games", systemImage: "books.vertical")
        } description: {
            Text("Import a PGN file to get started.")
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

    private func alert(for error: ImportError) -> Alert {
        switch error.error {
        case .duplicate(let existing):
            return Alert(
                title: Text("Already Imported"),
                message: Text("\(existing.name) is already in your library."),
                primaryButton: .default(Text("View Existing")) {
                    selectedPGNs = [existing.id]
                },
                secondaryButton: .cancel()
            )
        case .missingRequiredTags(let tags):
            return Alert(
                title: Text("Missing Required Tags"),
                message: Text("The PGN is missing: \(tags.sorted().joined(separator: ", "))."),
                dismissButton: .default(Text("OK"))
            )
        case .malformedPGN(let reason):
            return Alert(
                title: Text("Malformed PGN"),
                message: Text(reason),
                dismissButton: .default(Text("OK"))
            )
        case .fileReadFailed(let url, _):
            return Alert(
                title: Text("Couldn't Read File"),
                message: Text("Failed to read \(url.lastPathComponent)."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func deletionAlert(for game: PGN) -> Alert {
        Alert(
            title: Text("Delete Game?"),
            message: Text("\(game.name) will be permanently deleted."),
            primaryButton: .destructive(Text("Delete")) { delete(game) },
            secondaryButton: .cancel()
        )
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
        let toFix = games.filter { $0.name.isEmpty }
        guard !toFix.isEmpty else { return }
        for game in toFix {
            game.name = "\(game.white) vs \(game.black)"
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
