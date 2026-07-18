//
//  DGTSessionLog.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 28/05/2026.
//

import AppKit
import Foundation
import os
import UniformTypeIdentifiers

/// A unified, exportable diagnostic timeline for the DGT live-play subsystem.
///
/// The existing per-type `os.Logger`s stream to Console (great for `log
/// stream`, useless after the fact). This recorder is their in-memory,
/// *exportable* sibling: every semantic milestone on the live path — connect,
/// board info, each settled move, ghost-rook, recovery, and above all a
/// **full-context desync capture** — lands in one ordered buffer that can be
/// written to a file for "send me the log" debugging.
///
/// Design discipline (matches the rest of the DGT arc):
/// - **Pure types stay pure.** `DGTReconstructor`, `DGTBoardDiff`, `DGTFramer`,
///   `DGTDecoder`, and the whole `Chess/` core get *no* logger. They're read
///   by the side-effect-free `DGTDebugFormat` helpers below to render text;
///   they never write.
/// - **Orchestrators write.** `DGTConnection` and `DGTLiveSession` hold an
///   optional `sessionLog` (the same settable-hook pattern as
///   `DGTConnection.onBoardChanged`) and record into it. When unwired, the
///   live path's existing Console logging is unaffected — this is purely
///   additive.
/// - **Two entry verbs.** `record` mirrors to Console *and* buffers (for the
///   important stuff you also want in `log stream`); `capture` buffers only
///   (for milestones whose callers already log to Console, avoiding double
///   output).
///
/// App-global and `@Observable`, created on `DGTStudioProApp` and injected
/// like `DGTConnection` / `DGTLiveSession`, so a future in-app log viewer can
/// observe `entries` live.
@Observable
@MainActor
internal final class DGTSessionLog {
    
    // MARK: Logging
    
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "dgt"
    )
    
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
    
    /// Hard cap on retained entries. A full game is well under this; the cap
    /// only guards a marathon session from growing without bound. Oldest
    /// entries are dropped first.
    @ObservationIgnored private let maxEntries = 2000
    
    internal init() {}
    
    // MARK: Recording
    
    /// Buffers the entry *and* mirrors it to Console. Use for events the caller
    /// doesn't otherwise log (and for the rich desync capture).
    internal func record(_ level: Level, _ message: String) {
        append(level: level, message: message)
        switch level {
        case .debug: Self.logger.debug("\(message, privacy: .public)")
        case .info:  Self.logger.info("\(message, privacy: .public)")
        case .error: Self.logger.error("\(message, privacy: .public)")
        }
    }
    
    /// Buffers the entry only — no Console mirror. Use for milestones whose
    /// caller already logs to Console via its own `os.Logger`, so the export
    /// gets a complete timeline without duplicating Console output.
    internal func capture(_ level: Level, _ message: String) {
        append(level: level, message: message)
    }
    
    /// The headline feature: capture *everything* about a board that couldn't
    /// be reconciled to a legal move. Buffers + Console-mirrors a multi-line
    /// block with the last legal FEN, the physical board, the exact
    /// vacated/placed diff, and the recent move history — enough to replay the
    /// failure by hand. Board identity (serial / version) is already earlier in
    /// the same timeline, courtesy of `DGTConnection`.
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
    
    /// The whole timeline as plain text, newest entries last, each line
    /// timestamped. Multi-line entries (like a desync block) are preserved.
    internal func exportText() -> String {
        let stamp = Self.timestampFormatter
        var lines: [String] = [
            "DGT Studio Pro — Live Session Log",
            "Exported \(stamp.string(from: .now))",
            "\(entries.count) entr\(entries.count == 1 ? "y" : "ies")",
            String(repeating: "─", count: 48),
            ""
        ]
        for entry in entries {
            let head = "\(stamp.string(from: entry.timestamp))  [\(entry.level.rawValue.uppercased())]  "
            // Indent continuation lines of a multi-line message under the head.
            let body = entry.message
                .split(separator: "\n", omittingEmptySubsequences: false)
                .enumerated()
                .map { $0.offset == 0 ? String($0.element) : String(repeating: " ", count: head.count) + $0.element }
                .joined(separator: "\n")
            lines.append(head + body)
        }
        return lines.joined(separator: "\n")
    }
    
    /// Writes the timeline to `url`. Throws on write failure.
    internal func write(to url: URL) throws {
        try exportText().write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Presents a macOS save panel and writes the timeline to the chosen file.
    /// The "Export Live Session Log" affordance, reachable from both real
    /// callers: the M6.3 recovery panel ("Export Diagnostics…") and the M8.3
    /// Diagnostics menu. Deliberately non-throwing, failure Console-logged:
    /// buffering an export failure into the very timeline that just failed
    /// to save would only surface on a later, luckier export — Console is
    /// the reliable witness. The recording's export throws instead, because
    /// its caller *does* have a working timeline to note the failure in
    /// (flag C); see `DGTSessionRecording.exportViaSavePanel()`.
    internal func exportViaSavePanel() {
        let panel = NSSavePanel()
        panel.title = "Export Live Session Log"
        panel.nameFieldStringValue = "DGTLiveSession-\(Self.fileStampFormatter.string(from: .now)).log"
        panel.allowedContentTypes = [.plainText, .log]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try write(to: url)
            Self.logger.info("Exported live session log to \(url.lastPathComponent, privacy: .public)")
        } catch {
            Self.logger.error("Log export failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// Clears the timeline (e.g. when starting a fresh game you want isolated).
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

// MARK: - Debug Formatters

/// Side-effect-free renderers that turn the pure DGT/chess value types into
/// human-readable debug text. They *read* `Position` / `DGTBoardDiff` but never
/// mutate or log — this is what lets the pure types stay logger-free while the
/// recorder still produces rich output.
internal enum DGTDebugFormat {
    
    /// A board's piece placement in FEN rank notation (e.g.
    /// `rnbqkbnr/pppppppp/8/...`). Reuses the existing `FEN` placement logic by
    /// wrapping the position in a neutral FEN — no new chess-core code, and the
    /// pure `Position` stays untouched.
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
    
    /// The board diff as `vacated[e2=P,...] placed[e4=P,...]`, squares in
    /// algebraic notation and pieces as FEN characters, ordered by square index
    /// for stable, diff-friendly output.
    internal static func diff(_ diff: DGTBoardDiff) -> String {
        let vacated = diff.vacated.keys.sorted().map { square in
            "\(square.algebraicNotation)=\(diff.vacated[square]!.fenCharacter)"
        }.joined(separator: ",")
        let placed = diff.placed.keys.sorted().map { square in
            "\(square.algebraicNotation)=\(diff.placed[square]!.fenCharacter)"
        }.joined(separator: ",")
        return "vacated[\(vacated)] placed[\(placed)]"
    }
}
