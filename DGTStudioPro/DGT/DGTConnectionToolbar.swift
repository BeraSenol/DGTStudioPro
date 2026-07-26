//
//  DGTConnectionToolbar.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 25/05/2026.
//

import SwiftUI

/// Adds a DGT-board connection control to a view's toolbar and presents the
/// connect dialog (`DGTConnectionView`) as a sheet.
///
/// Mirrors `InspectorToggleModifier`: a single reusable modifier so a
/// destination opts in with one line (`.dgtConnectionToolbar()`), rather than
/// each one open-coding a `ToolbarItem`. The button's icon and tint reflect the
/// app-global `DGTConnection` status — green antenna when connected, plain when
/// not, a small spinner mid-handshake — so the toolbar doubles as a live
/// connection indicator.
internal struct DGTConnectionToolbarModifier: ViewModifier {
    
    @Environment(DGTConnection.self) private var connection
    @State private var showSheet = false
    
    /// No default, per the `board.connectButton` agreement: a shared fallback
    /// silently gives two hosts the same identifier, and a required parameter
    /// makes forgetting a compile error.
    let identifier: String
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem {
                    Button {
                        showSheet = true
                    } label: {
                        label
                    }
                    .help(helpText)
                    .accessibilityIdentifier(identifier)
                }
            }
            .sheet(isPresented: $showSheet) {
                DGTConnectionView()
            }
    }
    
    @ViewBuilder
    private var label: some View {
        switch connection.status {
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
        switch connection.status {
        case .connected: "antenna.radiowaves.left.and.right"
        default:         "antenna.radiowaves.left.and.right.slash"
        }
    }
    
    private var tint: Color? {
        switch connection.status {
        case .connected: .green
        case .failed:    .red
        default:         nil
        }
    }
    
    private var helpText: String {
        switch connection.status {
        case .disconnected, .searching: "Connect a DGT e-Board"
        case .connecting:               "Connecting to board…"
        case .reconnecting:             "Board disconnected — reconnecting…"
        case .connected:                "Board connected — show details"
        case .failed:                   "Connection failed — try again"
        }
    }
}

extension View {
    /// Adds the DGT board connect control + dialog to this view's toolbar.
    /// Requires a `DGTConnection` in the environment.
    internal func dgtConnectionToolbar(identifier: String) -> some View {
        modifier(DGTConnectionToolbarModifier(identifier: identifier))
    }
}
