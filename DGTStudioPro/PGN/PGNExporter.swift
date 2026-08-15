import AppKit
import UniformTypeIdentifiers
import os

/// The export door's transport half (D24′): panels and writes — waived under the save-panel
/// family; every byte comes from the pure serializer. Batch = one numbered file per game.
@MainActor
enum PGNExporter {
    
    private static let logger = AppLog.logger(.pgnexport)
    
    /// Declared by the system via the `.pgn` extension; the fallback keeps
    /// the panel's filter usable rather than showing none if that ever fails.
    private static var pgnType: UTType {
        UTType(filenameExtension: "pgn") ?? .plainText
    }
    
    /// `games` must arrive in **display order** — the filenames are numbered,
    /// so a `Set`'s arbitrary order would number them arbitrarily.
    static func export(_ games: [PGN]) {
        guard !games.isEmpty else { return }
        if games.count == 1 {
            exportSingle(games[0])
        } else {
            exportBatch(games)
        }
    }
    
    private static func exportSingle(_ pgn: PGN) {
        let panel = NSSavePanel()
        panel.title = "Export PGN"
        panel.nameFieldStringValue = pgn.exportFileName(index: 1)
        panel.allowedContentTypes = [pgnType]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(pgn, to: url)
    }
    
    private static func exportBatch(_ games: [PGN]) {
        let panel = NSOpenPanel()
        panel.title = "Export \(games.count) PGN Files"
        panel.prompt = "Export"
        panel.message = "Choose a folder for the exported games."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let folder = panel.url else { return }

        // D32′ — same-named files overwrite silently: re-exporting into last time's folder should
        // refresh (the export is a pure function of the rows).
        for (offset, game) in games.enumerated() {
            write(game, to: folder.appending(path: game.exportFileName(index: offset + 1)))
        }
    }
    
    /// Failures log rather than alert: a partly written batch is already
    /// visible in Finder, and one modal per failed file in a fifty-game
    /// export would be worse than a log line. The M8.3 export precedent,
    /// applied to a loop.
    private static func write(_ pgn: PGN, to url: URL) {
        do {
            try Data(pgn.pgnText.utf8).write(to: url, options: .atomic)
            logger?.info(
                "Exported '\(pgn.name, privacy: .public)' to \(url.lastPathComponent, privacy: .public)"
            )
        } catch {
            logger?.error(
                """
                PGN export failed for '\(pgn.name, privacy: .public)': \
                \(error.localizedDescription, privacy: .public)
                """
            )
        }
    }
}
