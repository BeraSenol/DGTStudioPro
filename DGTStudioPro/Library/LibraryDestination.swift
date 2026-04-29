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

    // MARK: Private Properties
    @State private var isInspectorPresented: Bool = false

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
                .inspectorColumnWidth(min: 260, ideal: 320, max: 400)
        }
        .toolbar {
            ToolbarItem {
                Picker("View Mode", selection: $viewMode) {
                    ForEach(CollectionViewMode.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            ToolbarSpacer()
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
                message: Text("\(game.name) will be permanently deleted."),
                primaryButton: .destructive(Text("Delete")) {
                    delete(game)
                },
                secondaryButton: .cancel()
            )
        }
        .onDeleteCommand {
            if let selected = selectedPGN {
                pendingDeletion = selected
            }
        }
        .onAppear {
            backfillEmptyNames()
            if viewMode == .gallery {
                isInspectorPresented = true
            }
        }
        .onChange(of: viewMode) { _, newMode in
            if newMode == .gallery {
                isInspectorPresented = true
            }
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

    @ViewBuilder
    private var modeView: some View {
        switch viewMode {
        case .icons:   iconsView
        case .list:    listView
        case .columns: placeholder("Columns")
        case .gallery: galleryView
        }
    }

    private func placeholder(_ name: String) -> some View {
        ContentUnavailableView(
            name,
            systemImage: "hammer",
            description: Text("\(name) view coming soon.")
        )
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

    private var iconsView: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)],
                spacing: 16
            ) {
                ForEach(games) { game in
                    iconCard(for: game)
                }
            }
            .padding(16)
        }
    }

    private func iconCard(for game: PGN) -> some View {
        let isSelected = selectedPGNs.contains(game.id)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(game.result.rawValue)
                    .font(.caption.monospaced())
                    .tracking(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.tertiary)
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
                Spacer()
                Text(game.displayDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(game.name)
                .font(.callout)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 4)

            Text(game.event)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(12)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : .secondary.opacity(0.2),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            selectedPGNs = [game.id]
        }
        .contextMenu {
            Button(role: .destructive) {
                pendingDeletion = game
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var listView: some View {
        Table(games, selection: $selectedPGNs) {
            TableColumn("White") { game in
                Text(game.white)
            }
            TableColumn("Black") { game in
                Text(game.black)
            }
            TableColumn("Result") { game in
                Text(game.result.rawValue)
                    .foregroundStyle(.secondary)
            }
            .width(60)
            TableColumn("Event") { game in
                Text(game.event)
                    .lineLimit(1)
            }
            TableColumn("Date") { game in
                Text(game.displayDate)
                    .foregroundStyle(.secondary)
            }
            .width(100)
            TableColumn("Round") { game in
                Text(game.displayRound)
                    .foregroundStyle(.secondary)
            }
            .width(60)
        }
        .contextMenu(forSelectionType: PGN.ID.self) { ids in
            if let id = ids.first, let game = games.first(where: { $0.id == id }) {
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

    private var galleryView: some View {
        VStack(spacing: 0) {
            galleryPreview
            Divider()
            galleryThumbnailStrip
        }
    }

    @ViewBuilder
    private var galleryPreview: some View {
        if let game = selectedPGN ?? games.first {
            VStack(spacing: 16) {
                galleryPlayerHeader(for: game)
                galleryBoard
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "square.dashed",
                description: Text("Select a game to preview.")
            )
        }
    }

    private func galleryPlayerHeader(for game: PGN) -> some View {
        VStack(spacing: 6) {
            Text(game.name)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(game.result.rawValue)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var galleryBoard: some View {
        BoardView(
            position: .starting,
            pieceTracker: .starting,
            style: boardStyle,
            perspective: .white,
            lastMove: nil,
            checkSquare: nil,
            selectedSquare: nil
        )
    }

    private var galleryThumbnailStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(games) { game in
                        galleryThumbnail(for: game)
                            .id(game.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 200)
            .background(.thinMaterial)
            .onChange(of: selectedPGNs) { _, newSelection in
                guard let id = newSelection.first else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private func galleryThumbnail(for game: PGN) -> some View {
        let isSelected = selectedPGNs.contains(game.id)

        return VStack(alignment: .leading, spacing: 6) {
            Text(game.result.rawValue)
                .font(.caption2.monospaced())
                .tracking(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.tertiary)
                .foregroundStyle(.secondary)
                .clipShape(Capsule())

            Spacer(minLength: 0)

            Text(game.name)
                .font(.caption)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)    .lineLimit(1)
        }
        .padding(10)
        .frame(width: 140, height: 110, alignment: .topLeading)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : .secondary.opacity(0.15),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            selectedPGNs = [game.id]
        }
        .contextMenu {
            Button(role: .destructive) {
                pendingDeletion = game
            } label: {
                Label("Delete", systemImage: "trash")
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

    private func delete(_ pgn: PGN) {
        selectedPGNs.remove(pgn.id)

        let store = PGNStore(modelContext: modelContext)
        do {
            try store.delete(pgn)
        } catch {
            Self.logger.error("Failed to delete PGN: \(error.localizedDescription, privacy: .public)")
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
