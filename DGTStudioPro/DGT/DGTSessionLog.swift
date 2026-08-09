import AppKit
import Foundation
import os
import UniformTypeIdentifiers

/// Exportable diagnostic timeline for live play — the in-memory sibling of the per-type
/// Console loggers. `record` buffers + mirrors; `capture` buffers only (callers that already
/// Console-log); `recordDesync` is the full-context capture. Ring-bounded.
@Observable
@MainActor
internal final class DGTSessionLog {
    
    // MARK: Logging
    
    private static let logger = AppLog.logger(.dgt)
    
    // MARK: Entry
    
    internal enum Level: String, Sendable {
        case debug, info, error
    }
    
    internal struct Entry: Identifiable, Sendable {
        internal let id = UUID()
        internal let timestamp: Date
        internal let level: Level
        internal let message: String
    }
    
    // MARK: Observable State
    
    /// Ordered timeline, oldest first. Bounded — see `maxEntries`.
    private(set) internal var entries: [Entry] = []
    
    // MARK: Configuration
    
    /// Hard cap; a full game is well under it. Oldest dropped first.
    @ObservationIgnored private let maxEntries = 2000
    
    internal init() {}
    
    // MARK: Recording
    
    /// Buffers *and* mirrors to Console — for events the caller doesn't otherwise log.
    internal func record(_ level: Level, _ message: String) {
        append(level: level, message: message)
        switch level {
        case .debug: Self.logger?.debug("\(message, privacy: .public)")
        case .info:  Self.logger?.info("\(message, privacy: .public)")
        case .error: Self.logger?.error("\(message, privacy: .public)")
        }
    }
    
    /// Buffers only — for milestones whose caller already Console-logs (no duplicate lines).
    internal func capture(_ level: Level, _ message: String) {
        append(level: level, message: message)
    }
    
    /// The headline: everything about an unreconcilable board — last legal FEN, physical board,
    /// exact diff, recent moves — enough to replay the failure by hand.
    internal func recordDesync(
        before: GameState,
        physical: Position,
        recentSAN: [String],
        plyCount: Int
    ) {
        let diff = DGTBoardDiff(from: before.position, to: physical)
        let recent = recentSAN.suffix(8).joined(separator: " ")
        let message = """
        DESYNC at ply \(plyCount) — board could not be reconciled to any legal move.
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
    internal func exportText() -> String {
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
            // Continuation lines indent under the head so a block stays attached to its timestamp.
            let indent = String(repeating: " ", count: head.count)
            lines.append(head + entry.message.replacingOccurrences(of: "\n", with: "\n" + indent))
        }
        return lines.joined(separator: "\n")
    }
    
    /// Writes the timeline to `url`. Throws on write failure.
    internal func write(to url: URL) throws {
        try exportText().write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Save panel + write. Non-throwing, failure Console-logged — a throw across the panel's
    /// completion would surface on a later, luckier export.
    internal func exportViaSavePanel() {
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
    
    /// No production caller — ring-bounded, nothing resets per game; exists so the suite can assert
    /// the bound and the append path independently.
    internal func clear() {
        entries.removeAll()
    }
    
    // MARK: Private
    
    private func append(level: Level, message: String) {
        entries.append(Entry(timestamp: .now, level: level, message: message))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
    
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

/// Side-effect-free renderers of the pure DGT/chess values — reads only, which is what lets the
/// pure types stay logger-free.
internal enum DGTDebugFormat {
    
    /// FEN rank notation via a neutral FEN wrap — no new chess-core code.
    internal static func placement(_ position: Position) -> String {
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
    internal static func diff(_ diff: DGTBoardDiff) -> String {
        "vacated[\(squares(diff.vacated))] placed[\(squares(diff.placed))]"
    }
    
    /// Sorted by square index so two captures of one board render identically.
    private static func squares(_ map: [Square: Piece]) -> String {
        map.sorted { $0.key < $1.key }
            .map { "\($0.key.algebraicNotation)=\($0.value.fenCharacter)" }
            .joined(separator: ",")
    }
}
