import SwiftUI

/// The Diagnostics menu: session-log export and the board-stream recorder. App-scoped - a
/// `Commands` scene has no `modelContext`, so both dependencies arrive as properties from
/// `App.init()`'s singletons. Stop-and-export is one action: a diagnostic recording stopped
/// without saving has no audience.
struct DiagnosticsCommands: Commands {
    
    let connection: DGTConnection
    let sessionLog: DGTSessionLog
    
    var body: some Commands {
        CommandMenu("Diagnostics") {
            // Ellipsis per HIG: these two open an NSSavePanel instead of acting immediately.
            Button("Export Session Log…") {
                sessionLog.exportViaSavePanel()
            }
            
            Divider()
            
            if connection.isRecording {
                Button("Stop & Export Board Recording…") {
                    // This is the unwrap, not a check: `stopRecording()` returns nil only when
                    // nothing is recording, which this branch excludes - and `recorder` is cleared
                    // inside that call and nowhere else, so nothing can flip it in between.
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
                // A recording holds the sleep inhibitor - `SleepInhibitor` reads `isRecording` - so
                // one left running keeps the Mac awake until it is stopped here.
                Button("Start Board Recording") {
                    connection.startRecording()
                }
                // Only *starting* is gated. A cable pull mid-recording must still reach the export
                // above; that is the board checklist's stop-and-export case.
                .disabled(!connection.isConnected)
            }
        }
    }
}
