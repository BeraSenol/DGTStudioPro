//
//  LibraryDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

internal struct LibraryDestination: View {

    // MARK: Private Properties
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PGN.importedAt, order: .reverse) private var games: [PGN]
    @State private var pendingDeletion: PGN?
    @State private var selectedPGN: PGN?
    @State private var isInspectorPresented: Bool = false
    @State private var importError: ImportError?

    // MARK: Body
    internal var body: some View {
        Group {
            if games.isEmpty {
                emptyState
            } else {
                gameList
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
        .toolbar {
            ToolbarItem {
                Button {
                    presentOpenPanel()
                } label: {
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
        .alert(item: $importError) { error in
            alert(for: error)
        }
        .alert(item: $pendingDeletion) { game in
            Alert(
                title: Text("Delete Game?"),
                message: Text("\(game.white) vs \(game.black) will be permanently deleted."),
                primaryButton: .destructive(Text("Delete")) {
                    delete(game)
                },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: Instance Methods
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Games", systemImage: "books.vertical")
        } description: {
            Text("Import a PGN file to get started.")
        }
    }

    private var gameList: some View {
        List(games, selection: $selectedPGN) { game in
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(game.white)
                    Text("vs")
                        .foregroundStyle(.tertiary)
                    Text(game.black)
                }
                .font(.body)

                HStack(spacing: 6) {
                    Text(game.result.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(game.event)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 2)
            .tag(game)
            .contextMenu {
                Button(role: .destructive) {
                    pendingDeletion = game
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .onDeleteCommand {
            if let selected = selectedPGN {
                pendingDeletion = selected
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
                importError = ImportError(url: url, error: error)
                return
            } catch {
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
                message: Text("\(existing.white) vs \(existing.black) is already in your library."),
                primaryButton: .default(Text("View Existing")) {
                    selectedPGN = existing
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

    private func delete(_ pgn: PGN) {
        if selectedPGN == pgn {
            selectedPGN = nil
        }

        let store = PGNStore(modelContext: modelContext)
        do {
            try store.delete(pgn)
        } catch {
            // Delete failures are rare (disk full, model context issues).
            // Silently logging is acceptable for now; revisit if it becomes a real failure mode.
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
        PGN(
            event: "World Championship",
            site: "Dubai",
            round: 11,
            white: "Carlsen, Magnus",
            black: "Nepomniachtchi, Ian",
            result: .whiteWins
        ),
        PGN(
            event: "Tata Steel Masters",
            site: "Wijk aan Zee",
            round: 7,
            white: "Giri, Anish",
            black: "Caruana, Fabiano",
            result: .draw
        ),
        PGN(
            event: "Norway Chess",
            site: "Stavanger",
            round: 3,
            white: "Firouzja, Alireza",
            black: "Ding, Liren",
            result: .blackWins
        )
    ]

    for sample in samples {
        container.mainContext.insert(sample)
    }

    return NavigationSplitView {
        List {
            Label("Library", systemImage: "books.vertical")
        }
        .navigationSplitViewColumnWidth(min: 80, ideal: 100, max: 120)
    } detail: {
        LibraryDestination()
    }
    .modelContainer(container)
}

#Preview("Empty") {
    NavigationSplitView {
        List {
            Label("Library", systemImage: "books.vertical")
        }
        .navigationSplitViewColumnWidth(min: 80, ideal: 100, max: 120)
    } detail: {
        LibraryDestination()
    }
    .modelContainer(for: PGN.self, inMemory: true)
}
