//
//  DGTConnectionView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 25/05/2026.
//

import SwiftUI

/// The connect dialog for the DGT e-Board, presented as a sheet from the Board
/// toolbar (see `DGTConnectionToolbar`).
///
/// It is a thin view over the app-global `DGTConnection`: it never opens a port
/// or talks to IOKit itself, it just drives `search()` / `connect(to:)` /
/// `disconnect()` and renders `connection.status`. The five resting states map
/// to five panels:
///
/// - `.disconnected` / `.searching` → pick a device from the discovered list
/// - `.connecting`  → the handshake progress indicator (open + init sequence,
///   resolving once the board's first dump arrives)
/// - `.connected`   → the board's reported identity, plus Disconnect
/// - `.reconnecting` → the M7.3 retry loop: keep waiting, or stand it down
/// - `.failed`      → the error, with Try Again
///
/// The user confirms the device explicitly (the Connect button) before the
/// port is opened — the "confirm before finalizing" half of the locked UX.
internal struct DGTConnectionView: View {
    
    @Environment(DGTConnection.self) private var connection
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDeviceID: DGTSerialDevice.ID?
    
    /// D15′(b): the dialog's spacing, named and HIG-derived instead of ad
    /// hoc. Values follow macOS layout conventions (HIG Layout; the AppKit
    /// standard-dialog metrics the HIG encodes): 20 pt content margins at
    /// sheet edges, 12 pt between sibling controls and grouped elements,
    /// 4 pt between a text line and its subordinate caption (the system
    /// alert's title/informative rhythm). The panels previously mixed 14,
    /// 12, and the 16 pt `.padding()` default — visually near these values,
    /// which is exactly why they drifted unnoticed. Two nonconforming
    /// numbers survive by design: the fixed 420 × 380 sheet frame and the
    /// 260 pt info table are *sizing*, not spacing (the table is wide
    /// enough for a long serial, narrow enough to read as a table).
    /// `DeviceRow`'s internals are deliberately out of scope: a list row's
    /// rhythm belongs to its list style, not the dialog chrome.
    private enum Metrics {
        /// Sheet edge margin (the standard 20 pt dialog content margin).
        static let margin: CGFloat = 20
        /// Sibling controls and grouped elements (panel stacks, footer
        /// buttons — 12 pt is the Aqua push-button spacing).
        static let groupSpacing: CGFloat = 12
        /// A text line and its caption.
        static let captionSpacing: CGFloat = 4
        /// The connected panel's info table width — sizing, see above.
        static let infoTableWidth: CGFloat = 260
    }
    
    internal var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            footer
        }
        .frame(width: 420, height: 380)
        .onAppear {
            // Scan as soon as the dialog opens — unless we're already live,
            // or the M7.3 reconnect loop is mid-flight: `search()` tears the
            // loop down, and a player opening this sheet mid-reconnect wants
            // to see (or stop) the retry, not a device list.
            if connection.isReconnecting { return }
            if !connection.isConnected { connection.search() }
        }
        .accessibilityIdentifier(AccessibilityID.dgtConnectSheet)
    }
    
    // MARK: Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: Metrics.captionSpacing) {
            Text(title).font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Metrics.margin)
    }
    
    private var title: String {
        switch connection.status {
        case .disconnected, .searching: "Connect to Board"
        case .connecting:               "Connecting…"
        case .reconnecting:             "Reconnecting…"
        case .connected:                "Board Connected"
        case .failed:                   "Connection Failed"
        }
    }
    
    private var subtitle: String? {
        switch connection.status {
        case .disconnected, .searching:
            "Select the serial port your DGT e-Board is connected to."
        case .connecting, .reconnecting, .connected, .failed:
            nil
        }
    }
    
    // MARK: Content
    
    @ViewBuilder
    private var content: some View {
        switch connection.status {
        case .disconnected, .searching:
            deviceList
        case .connecting(let device):
            connectingPanel(device)
        case .reconnecting(let device):
            reconnectingPanel(device)
        case .connected(let device):
            connectedPanel(device)
        case .failed(let message):
            failedPanel(message)
        }
    }
    
    private var deviceList: some View {
        Group {
            if connection.availableDevices.isEmpty {
                ContentUnavailableView {
                    Label("No Serial Devices", systemImage: "antenna.radiowaves.left.and.right.slash")
                } description: {
                    Text("Plug in your DGT e-Board, then rescan.")
                }
            } else {
                List(connection.availableDevices, selection: $selectedDeviceID) { device in
                    DeviceRow(device: device)
                        .tag(device.id)
                }
                .listStyle(.sidebar)
                .accessibilityIdentifier(AccessibilityID.dgtDeviceList)
            }
        }
    }
    
    private func connectingPanel(_ device: DGTSerialDevice) -> some View {
        VStack(spacing: Metrics.groupSpacing) {
            ProgressView()
                .controlSize(.large)
            Text("Connecting to \(device.name)…")
                .font(.callout)
            Text("Resetting the board and reading its starting position.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Metrics.margin)
        .accessibilityIdentifier(AccessibilityID.dgtConnectingPanel)
    }
    
    /// M7.3 — the retry loop's face in the dialog: what happened, that the
    /// app is handling it, and how to stand it down. The loop itself lives
    /// in `DGTConnection`; this panel is pure status.
    private func reconnectingPanel(_ device: DGTSerialDevice) -> some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Reconnecting to \(device.name)…")
                .font(.callout)
            Text(
                "The board disconnected during a game. Plug it back in — "
                + "the game resumes where it left off."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityIdentifier(AccessibilityID.dgtReconnectingPanel)
    }
    
    private func connectedPanel(_ device: DGTSerialDevice) -> some View {
        VStack(spacing: Metrics.groupSpacing) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            
            Text(device.name)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: Metrics.captionSpacing) {
                infoRow("Serial", connection.boardInfo.serialNumber)
                infoRow("Version", connection.boardInfo.version)
                infoRow("Hardware", connection.boardInfo.hardwareVersion)
                infoRow("Trademark", connection.boardInfo.trademark)
            }
            .font(.caption)
            .frame(maxWidth: Metrics.infoTableWidth, alignment: .leading)
        }
        .padding(Metrics.margin)
        .accessibilityIdentifier(AccessibilityID.dgtConnectedPanel)
    }
    
    @ViewBuilder
    private func infoRow(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text(value).monospacedDigit()
            }
        }
    }
    
    private func failedPanel(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't Connect", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        }
        .accessibilityIdentifier(AccessibilityID.dgtFailedPanel)
    }
    
    // MARK: Footer
    
    private var footer: some View {
        HStack(spacing: Metrics.groupSpacing) {            switch connection.status {
        case .disconnected, .searching:
            Button("Rescan") { connection.search() }
                .accessibilityIdentifier(AccessibilityID.dgtRescanButton)
            Spacer()
            Button("Cancel") { dismiss() }
            Button("Connect") {
                guard let device = selectedDevice else { return }
                Task { await connection.connect(to: device) }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selectedDevice == nil)
            .accessibilityIdentifier(AccessibilityID.dgtConnectButton)
            
        case .connecting:
            Spacer()
            Button("Cancel") {
                Task { await connection.disconnect() }
            }
            .accessibilityIdentifier(AccessibilityID.dgtCancelButton)
            
        case .reconnecting:
            // Standing the loop down is deliberate but not destructive —
            // nothing is lost; the game stays right there on screen.
            // Ends in `.disconnected`, then `search()` swaps this panel
            // for the device list in place.
            Button("Stop Trying") {
                Task {
                    await connection.stopReconnecting()
                    connection.search()
                }
            }
            .accessibilityIdentifier(AccessibilityID.dgtStopReconnectingButton)
            Spacer()
            Button("Close") { dismiss() }
                .keyboardShortcut(.defaultAction)
            
        case .connected:
            Button("Disconnect", role: .destructive) {
                Task { await connection.disconnect() }
            }
            .accessibilityIdentifier(AccessibilityID.dgtDisconnectButton)
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
            
        case .failed:
            Spacer()
            Button("Cancel") { dismiss() }
            Button("Try Again") { connection.search() }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(AccessibilityID.dgtRetryButton)
        }
        }
        .padding()
    }
    
    // MARK: Helpers
    
    private var selectedDevice: DGTSerialDevice? {
        connection.availableDevices.first { $0.id == selectedDeviceID }
    }
}

// MARK: Device Row

private struct DeviceRow: View {
    let device: DGTSerialDevice
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: device.isLikelyBoard ? "cable.connector" : "point.3.connected.trianglepath.dotted")
                .foregroundStyle(device.isLikelyBoard ? Color.accentColor : .secondary)
                .frame(width: 22)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.callout)
                Text(device.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if device.isLikelyBoard {
                Spacer()
                Text("Likely board")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: Previews

/// `DeviceRow` is the previewable half: `DGTConnection.status` is
/// `private(set)`, so the dialog itself can't be driven past its empty
/// state from a preview. The row carries the visual logic worth seeing —
/// `isLikelyBoard` picks the icon and tint (sort-only for this dialog,
/// never auto-connect criteria).
#Preview("Device Rows") {
    VStack(alignment: .leading, spacing: 0) {
        DeviceRow(device: DGTSerialDevice(path: "/dev/cu.usbmodem01", name: "DGT Board"))
        Divider()
        DeviceRow(device: DGTSerialDevice(path: "/dev/cu.usbserial-A1B2", name: "FTDI USB Serial"))
        Divider()
        DeviceRow(device: DGTSerialDevice(path: "/dev/cu.Bluetooth-Incoming-Port",
                                          name: "Bluetooth-Incoming-Port"))
        Divider()
        DeviceRow(device: DGTSerialDevice(path: "/dev/cu.debug-console", name: "debug-console"))
    }
    .padding()
    .frame(width: 380)
}

/// Long name and long path — the truncation case for a 380 pt sheet.
#Preview("Overflowing Row") {
    DeviceRow(
        device: DGTSerialDevice(
            path: "/dev/cu.usbmodem-DGT-Revelation-II-0000000000001",
            name: "DGT Revelation II Electronic Chessboard (rev 4.02)"
        )
    )
    .padding()
    .frame(width: 380)
}
