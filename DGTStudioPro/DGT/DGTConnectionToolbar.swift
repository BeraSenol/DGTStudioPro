import SwiftUI

/// The DGT-board connection control, as `ToolbarContent` a host composes into
/// its **own** builder — not a `.toolbar` modifier. The modifier form is gone
/// on purpose (see the note at the foot of this file): a second `.toolbar`
/// merge is what kept Board's inspector column from running full height and
/// made item order an accident of modifier nesting.
///
/// The button's icon and tint reflect the app-global `DGTConnection` status —
/// green cable when connected, red-tinted slashed cable on failure, a small
/// spinner mid-handshake or mid-reconnect — so the toolbar doubles as a live
/// connection indicator. The sheet is the host's `@State`; this only flips it.
internal struct DGTConnectionToolbarContent: ToolbarContent {
    
    /// The status as a plain value rather than a `DGTConnection` read from the
    /// environment, and the sheet as a `Binding` rather than owned `@State`:
    /// dynamic properties inside a custom `ToolbarContent` are not the
    /// well-trodden path they are inside a `View`, and neither is needed —
    /// every branch below is a function of `status`, and the host already
    /// holds both.
    internal let status: DGTConnection.Status
    
    /// No default, per the `board.connectButton` agreement: a shared fallback
    /// silently gives two hosts the same identifier, and a required parameter
    /// makes forgetting a compile error.
    internal let identifier: String
    
    @Binding internal var isSheetPresented: Bool
    
    internal var body: some ToolbarContent {
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
            // handshake — or the M7.3 retry loop working to get the board
            // back (the HUD carries the words; this is just the pulse).
            ProgressView()
                .controlSize(.small)
        default:
            Label("Connect Board", systemImage: symbol)
                .tint(tint)
        }
    }
    
    /// Failure reads as "not connected" here by design — `tint` is what
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

// The `DGTConnectionToolbarModifier` / `.dgtConnectionToolbar(identifier:)`
// pair is deleted here, not parked: its one host now composes
// `DGTConnectionToolbarContent` into its own builder, because a second
// `.toolbar` modifier is what kept Board's inspector column from running full
// height and made its item order an accident of nesting. A modifier that
// re-introduces that is worse than no convenience at all.
