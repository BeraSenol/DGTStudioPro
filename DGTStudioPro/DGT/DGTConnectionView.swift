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
        .accessibilityIdentifier("dgt.connectSheet")
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
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
                .listStyle(.inset)
                .accessibilityIdentifier("dgt.deviceList")
            }
        }
    }

    private func connectingPanel(_ device: DGTSerialDevice) -> some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Connecting to \(device.name)…")
                .font(.callout)
            Text("Resetting the board and reading its starting position.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityIdentifier("dgt.connectingPanel")
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
        .accessibilityIdentifier("dgt.reconnectingPanel")
    }

    private func connectedPanel(_ device: DGTSerialDevice) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text(device.name)
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                infoRow("Serial", connection.boardInfo.serialNumber)
                infoRow("Version", connection.boardInfo.version)
                infoRow("Hardware", connection.boardInfo.hardwareVersion)
                infoRow("Trademark", connection.boardInfo.trademark)
            }
            .font(.caption)
            .frame(maxWidth: 260, alignment: .leading)
        }
        .padding()
        .accessibilityIdentifier("dgt.connectedPanel")
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
        .accessibilityIdentifier("dgt.failedPanel")
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            switch connection.status {
            case .disconnected, .searching:
                Button("Rescan") { connection.search() }
                    .accessibilityIdentifier("dgt.rescanButton")
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Connect") {
                    guard let device = selectedDevice else { return }
                    Task { await connection.connect(to: device) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedDevice == nil)
                .accessibilityIdentifier("dgt.connectButton")

            case .connecting:
                Spacer()
                Button("Cancel") {
                    Task { await connection.disconnect() }
                }
                .accessibilityIdentifier("dgt.cancelButton")

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
                .accessibilityIdentifier("dgt.stopReconnectingButton")
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)

            case .connected:
                Button("Disconnect", role: .destructive) {
                    Task { await connection.disconnect() }
                }
                .accessibilityIdentifier("dgt.disconnectButton")
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)

            case .failed:
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Try Again") { connection.search() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("dgt.retryButton")
            }
        }
        .padding()
    }

    // MARK: Helpers

    private var selectedDevice: DGTSerialDevice? {
        connection.availableDevices.first { $0.id == selectedDeviceID }
    }
}

// MARK: - Device Row

private struct DeviceRow: View {
    let device: DGTSerialDevice

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: device.isLikelyBoard ? "cable.connector" : "point.3.connected.trianglepath.dotted")
                .foregroundStyle(device.isLikelyBoard ? Color.accentColor : .secondary)
                .frame(width: 18)

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
        .padding(.vertical, 2)
    }
}
