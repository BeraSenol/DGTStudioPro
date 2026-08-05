import SwiftUI

/// The Diagnostics menu (M8.3, flag C) — wiring the last unsurfaced
/// diagnostics features: the session-log export (also reachable from the
/// M6.3 recovery panel; a menu path means it needn't wait for a desync to
/// be worth saving) and the opt-in board-stream recording for offline,
/// hardware-free replay of reconstruction/recovery (`DGTSessionRecording`).
///
/// Holds the app-global objects directly — passed in by `DGTStudioProApp`,
/// which owns them — rather than via `@FocusedValue`: unlike the Game menu,
/// diagnostics are app-scoped, not per-tab. Reading `connection.isRecording`
/// and `connection.isConnected` inside `body` registers Observation
/// dependencies, so the menu's titles and enabled states track live state.
///
/// Stop and export are one action, deliberately: a recording is
/// diagnostic-only, so stopping without saving has no audience — cancelling
/// the save panel discards it, the same outcome with one fewer menu item.
/// A recording-export write failure is recorded into the session log itself
/// (Console + buffer) rather than alerted: a `Commands` scene has no
/// natural presentation surface, and a diagnostics failure landing in the
/// diagnostics timeline is exactly where the person debugging would look.
internal struct DiagnosticsCommands: Commands {
    
    internal let connection: DGTConnection
    internal let sessionLog: DGTSessionLog
    
    internal var body: some Commands {
        CommandMenu("Diagnostics") {
            // Ellipsis per HIG: this opens an NSSavePanel rather than acting
            // immediately. Same for the stop-and-export item below; "Start
            // Board Recording" correctly has none.
            Button("Export Session Log…") {
                sessionLog.exportViaSavePanel()
            }
            
            Divider()
            
            if connection.isRecording {
                Button("Stop & Export Board Recording…") {
                    guard let recording = connection.stopRecording() else {
                        return
                    }
                    do {
                        try recording.exportViaSavePanel()
                    } catch {
                        sessionLog.record(
                            .error,
                            "Board recording export failed: \(error.localizedDescription)"
                        )
                    }
                }
            } else {
                Button("Start Board Recording") {
                    connection.startRecording()
                }
                // A recording captures the live board stream; without a
                // connected board there is nothing to record.
                .disabled(!connection.isConnected)
            }
        }
    }
}
