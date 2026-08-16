import SwiftUI

/// The connection control as `ToolbarContent` a host composes into its own builder - a second
/// `.toolbar` modifier leaves the toolbar undivided. The sheet is the host's `@State`; this
/// only flips it.
struct DGTConnectionToolbarContent: ToolbarContent {
    
    /// Status as a plain value, sheet as a `Binding`: dynamic properties inside a custom
    /// `ToolbarContent` are not reliably observed.
    let status: DGTConnection.Status
    
    /// No default, per the `board.connectButton` agreement: a shared fallback
    /// silently gives two hosts the same identifier, and a required parameter
    /// makes forgetting a compile error.
    let identifier: String
    
    @Binding var isSheetPresented: Bool
    
    var body: some ToolbarContent {
        ToolbarItem {
            Button {
                isSheetPresented = true
            } label: {
                label
            }
            .help(helpText)
            .accessibilityIdentifier(identifier)
        }
    }
    
    @ViewBuilder
    private var label: some View {
        switch status {
        case .connecting, .reconnecting:
            // A spinner in the toolbar communicates the in-progress
            // handshake - or the M7.3 retry loop working to get the board
            // back (the HUD carries the words; this is just the pulse).
            ProgressView()
                .controlSize(.small)
        default:
            Label("Connect Board", systemImage: symbol)
                .tint(tint)
        }
    }
    
    /// Failure reads as "not connected" here by design - `tint` is what
    /// distinguishes it (red vs plain). The enumerated `.failed` case returned
    /// the same string as `default` and decided nothing; if a distinct failure
    /// glyph is ever wanted, it goes back here.
    private var symbol: String {
        switch status {
        case .connected: "cable.connector"
        default:         "cable.connector.slash"
        }
    }
    
    private var tint: Color? {
        switch status {
        case .connected: .green
        case .failed:    .red
        default:         nil
        }
    }
    
    private var helpText: String {
        switch status {
        case .disconnected, .searching: "Connect a DGT e-Board"
        case .connecting:               "Connecting to board…"
        case .reconnecting:             "Board disconnected, reconnecting…"
        case .connected:                "Board connected, show details"
        case .failed:                   "Connection failed, try again"
        }
    }
}
