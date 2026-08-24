import SwiftUI

/// The connection control as `ToolbarContent` a host composes into its own builder - a second
/// `.toolbar` modifier leaves the toolbar undivided. Opens the connection *window* since
/// 16 Aug 2026 (the sheet binding it carried went with the everything-is-a-window pass).
struct DGTConnectionToolbarContent: ToolbarContent {
    
    /// Status as a plain value: dynamic properties inside a custom `ToolbarContent` are not
    /// reliably observed - which is also why the button below is its own `View`, where the
    /// `openWindow` environment read is one SwiftUI promises to resolve.
    let status: DGTConnection.Status
    
    /// Required rather than defaulted. `BoardDestination` is the only host today; a default would
    /// let a second silently inherit `board.connectButton`, and forgetting is a compile error.
    let identifier: String
    
    var body: some ToolbarContent {
        ToolbarItem {
            ConnectButton(status: status, identifier: identifier)
        }
    }
}

/// The `ShowViewOptionsButton` arrangement: a plain `View` carries the action so the environment
/// is honestly available.
private struct ConnectButton: View {
    
    let status: DGTConnection.Status
    let identifier: String
    
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Button {
            openWindow(id: DGTConnectionView.sceneID)
        } label: {
            label
        }
        .help(helpText)
        .accessibilityIdentifier(identifier)
    }
    
    @ViewBuilder
    private var label: some View {
        switch status {
        case .connecting, .reconnecting:
            // The handshake, or the M7.3 retry loop working to get the board back. The HUD carries
            // the words; this is just the pulse.
            ProgressView()
                .controlSize(.small)
        default:
            Label("Connect Board", systemImage: symbol)
                .tint(tint)
        }
    }
    
    /// **`helpText` is exhaustive; this and `tint` are not.** A new `Status` case is a compile
    /// error there and a silent fall-through here. `.failed` already takes that fall-through - it
    /// wears the disconnected glyph, and only `tint` is left to distinguish it.
    private var symbol: String {
        switch status {
        case .connected: "cable.connector"
        default:         "cable.connector.slash"
        }
    }
    
    /// The app's only `.tint(` - every comparable site uses `.foregroundStyle`. Whether it colours
    /// a `Label` inside a toolbar `Button` at all is unwitnessed; if it does not, `.failed` and
    /// `.disconnected` render identically, because `symbol` hands them the same glyph.
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
