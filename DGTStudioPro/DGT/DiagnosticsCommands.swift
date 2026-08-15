import SwiftUI

/// The Diagnostics menu: session-log export and the board-stream recorder. App-scoped — a
/// `Commands` scene has no `modelContext`. Stop-and-export is one action: a diagnostic
/// recording stopped without saving has no audience.
struct DiagnosticsCommands: Commands {
    
    let connection: DGTConnection
    let sessionLog: DGTSessionLog
    
    var body: some Commands {
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
