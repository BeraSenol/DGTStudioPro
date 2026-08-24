import AppKit
import Foundation
import os
import UniformTypeIdentifiers

/// Exportable diagnostic timeline for live play - the in-memory sibling of the per-type Console
/// loggers. `record` buffers *and* mirrors; `capture` buffers only. Which one to call is the
/// caller's judgement about Console rather than a property of the event: most `capture` sites are
/// per-settle chatter that deliberately never reaches Console at all.
///
/// Ring-bounded, and the ring spans the whole app session - nothing resets per game.
@Observable
@MainActor
final class DGTSessionLog {
    
    // MARK: Logging
    
    private static let logger = AppLog.logger(.dgt)
    
    // MARK: Entry
    
    enum Level: String, Sendable {
        case debug, info, error
    }
    
    struct Entry: Identifiable, Sendable {
        let id = UUID()
        let timestamp: Date
        let level: Level
        let message: String
    }
    
    // MARK: Observable State
    
    /// Ordered timeline, oldest first. Bounded - see `maxEntries`.
    private(set) var entries: [Entry] = []
    
    // MARK: Configuration
    
    /// Hard cap across the whole app session, not per game: `clear()` has no production caller, so
    /// a long sitting of several games shares this one ring. Oldest dropped first.
    @ObservationIgnored private let maxEntries = 2000
    
    init() {}
    
    // MARK: Recording
    
    /// Buffers *and* mirrors to Console.
    func record(_ level: Level, _ message: String) {
        append(level: level, message: message)
        switch level {
        case .debug: Self.logger?.debug("\(message, privacy: .public)")
        case .info:  Self.logger?.info("\(message, privacy: .public)")
        case .error: Self.logger?.error("\(message, privacy: .public)")
        }
    }
    
    /// Buffers only. Whether Console also needs a line is decided separately at the call site, and
    /// most callers decide it does not.
    func capture(_ level: Level, _ message: String) {
        append(level: level, message: message)
    }
    
    /// The headline: everything about an unreconcilable board - last legal FEN, physical board,
    /// exact diff, recent moves - enough to replay the failure by hand.
    func recordDesync(
        before: GameState,
        physical: Position,
        recentSAN: [String],
        plyCount: Int
    ) {
        let diff = DGTBoardDiff(from: before.position, to: physical)
        let recent = recentSAN.suffix(8).joined(separator: " ")
        let message = """
        DESYNC at ply \(plyCount) - board could not be reconciled to any legal move.
          side to move : \(before.activeColor)
          last legal   : \(FEN(before).string)
          physical     : \(DGTDebugFormat.placement(physical))
          diff         : \(DGTDebugFormat.diff(diff))
          recent moves : \(recent.isEmpty ? "(game start)" : recent)
        """
        record(.error, message)
    }
    
    // MARK: Export
    
    /// The timeline as plain text, newest last, timestamped; multi-line entries preserved.
    func exportText() -> String {
        let stamp = Self.timestampFormatter
        var lines: [String] = [
            "DGT Studio Pro Live Session Log",
            "Exported \(stamp.string(from: .now))",
            "\(entries.count) entr\(entries.count == 1 ? "y" : "ies")",
            String(repeating: "─", count: 48),
            ""
        ]
        for entry in entries {
            let head = "\(stamp.string(from: entry.timestamp))  [\(entry.level.rawValue.uppercased())]  "
            // Continuation lines indent under *this* head, so a block stays attached to its
            // timestamp - the width follows the level string and is not uniform down the file.
            let indent = String(repeating: " ", count: head.count)
            lines.append(head + entry.message.replacingOccurrences(of: "\n", with: "\n" + indent))
        }
        return lines.joined(separator: "\n")
    }
    
    /// Writes the timeline to `url`. Throws on write failure.
    func write(to url: URL) throws {
        try exportText().write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Save panel + write. Non-throwing, failure Console-logged - a throw across the panel's
    /// completion would surface on a later, luckier export.
    func exportViaSavePanel() {
        let panel = NSSavePanel()
        panel.title = "Export Live Session Log"
        panel.nameFieldStringValue = "DGTLiveSession-\(Self.fileStampFormatter.string(from: .now)).log"
        panel.allowedContentTypes = [.plainText, .log]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try write(to: url)
            Self.logger?.info("Exported live session log to \(url.lastPathComponent, privacy: .public)")
        } catch {
            Self.logger?.error("Log export failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// No production caller - nothing resets the ring; exists so the suite can assert the bound and
    /// the append path independently.
    func clear() {
        entries.removeAll()
    }
    
    // MARK: Private
    
    private func append(level: Level, message: String) {
        entries.append(Entry(timestamp: .now, level: level, message: message))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
    
    // `DateFormatter` is not `Sendable`, so both of these have to stay inside the `@MainActor`
    // type - hoisting either to file scope is a mode-6 error, not a style change.
    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    private static let fileStampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

// MARK: Debug Formatters

/// Side-effect-free renderers of the pure DGT/chess values - reads only, which is what lets the
/// pure types stay logger-free. `recordDesync` above is the only consumer in the tree.
enum DGTDebugFormat {
    
    /// FEN rank notation via a neutral FEN wrap - no new chess-core code. Every field but the
    /// position is a placeholder; only `piecePlacement` is read.
    static func placement(_ position: Position) -> String {
        FEN(
            position: position,
            activeColor: .white,
            castlingRights: .none,
            enPassantTarget: nil,
            halfmoveClock: 0,
            fullmoveNumber: 1
        ).piecePlacement
    }
    
    /// `vacated[e2=P,…] placed[e4=P,…]`, ordered by square index for stable output.
    static func diff(_ diff: DGTBoardDiff) -> String {
        "vacated[\(squares(diff.vacated))] placed[\(squares(diff.placed))]"
    }
    
    /// Sorted by square index so two captures of one board render identically.
    private static func squares(_ map: [Square: Piece]) -> String {
        map.sorted { $0.key < $1.key }
            .map { "\($0.key.algebraicNotation)=\($0.value.fenCharacter)" }
            .joined(separator: ",")
    }
}
