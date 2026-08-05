import SwiftUI

/// The board connection window — a confirmation/error surface since
/// 2 Aug 2026, when the device picker was deleted whole (user decree: the
/// app connects to `DGTConnection.onlyBoardPath`, never ever anything
/// else). What was a five-panel dialog over a discovered-device list is now
/// four resting states over one hardcoded identity:
///
/// - opening the sheet **attempts the connection immediately** — there is
///   nothing to pick, so there is nothing to confirm beforehand; the old
///   confirm-before-connect contract is discharged by the decree itself
///   (the one path is the standing confirmation)
/// - `.connecting`   → the handshake progress indicator
/// - `.connected`    → the board's reported identity, plus Disconnect
/// - `.reconnecting` → the M7.3 retry loop's face, and its stand-down door
///   ("Stop Trying" — the per-incident choice the Settings footer points
///   at, so it must survive the picker it used to share a window with)
/// - `.failed` / board absent → the error, with Try Again
///
/// Still a thin view over the app-global `DGTConnection`: it never opens a
/// port or talks to IOKit itself.
internal struct DGTConnectionView: View {

    @Environment(DGTConnection.self) private var connection
    @Environment(\.dismiss) private var dismiss

    /// D15′(b): the dialog's spacing, named and HIG-derived instead of ad
    /// hoc — 20 pt content margins at sheet edges, 12 pt between sibling
    /// controls, 4 pt between a text line and its caption. Survives the
    /// picker's deletion untouched because the dialogs that borrow these three
    /// numbers cite them by name and reason rather than importing them; the
    /// 420 × 320 frame and 260 pt info table are *sizing*, not spacing
    /// (320, down from 380 — the height the device list earned went with
    /// it).
    ///
    /// The two that cited them by name — `RenamePlayerSheet` and
    /// `MergePlayerSheet` — are both retired (M10 and D52′). `GetInfoWindow`
    /// is the current borrower, of `margin` alone. Named as a class rather
    /// than as a list, because an enumerated-caller list on a primitive is the
    /// anti-pattern that put two dead type names in this comment.
    private enum Metrics {
        /// Sheet edge margin (the standard 20 pt dialog content margin).
        static let margin: CGFloat = 20
        /// Sibling controls and grouped elements (12 pt Aqua spacing).
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
        .frame(width: 420, height: 320)
        .onAppear {
            // Attempt on sight — unless we're already live, or the M7.3
            // loop is mid-flight: a player opening this mid-reconnect
            // wants to see (or stop) the retry, not restart it.
            if connection.isReconnecting || connection.isConnected { return }
            attemptConnect()
        }
        .accessibilityIdentifier(AccessibilityID.dgtConnectSheet)
    }

    // MARK: The One Attempt

    private func attemptConnect() {
        // `search()` refreshes the enumeration synchronously and resolves the
        // board itself, so the view still never touches IOKit — and no longer
        // restates the path test either. It used to scan `availableDevices`
        // here, which put the "what counts as the board" rule in a view.
        connection.search()
        guard let board = connection.attachedBoard else { return }  // not-found panel renders
        Task { await connection.connect(to: board) }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Metrics.captionSpacing) {
            Text(title).font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Metrics.margin)
    }

    private var title: String {
        switch connection.status {
        case .disconnected, .searching:
            connection.attachedBoard == nil ? "Board Not Found" : "Connecting…"
        case .connecting:   "Connecting…"
        case .reconnecting: "Reconnecting…"
        case .connected:    "Board Connected"
        case .failed:       "Connection Failed"
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch connection.status {
        case .disconnected, .searching:
            if connection.attachedBoard == nil {
                notFoundPanel
            } else {
                // An attempt is in flight (or one click away after a
                // stand-down); the status flips to `.connecting` the
                // moment the port opens.
                ProgressView()
                    .controlSize(.large)
                    .padding(Metrics.margin)
            }
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

    /// The one absence the window can name precisely: the path is a
    /// constant, so "not found" always means the same cable.
    private var notFoundPanel: some View {
        ContentUnavailableView {
            Label("Board Not Found", systemImage: "cable.connector.slash")
        } description: {
            Text("Nothing is attached at \(DGTConnection.onlyBoardPath). Plug the board in, then try again.")
        }
        .accessibilityIdentifier(AccessibilityID.dgtNotFoundPanel)
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

    /// M7.3 — the retry loop's face: what happened, that the app is
    /// handling it, and how to stand it down. The loop itself lives in
    /// `DGTConnection`; this panel is pure status.
    private func reconnectingPanel(_ device: DGTSerialDevice) -> some View {
        VStack(spacing: Metrics.groupSpacing) {
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
        .padding(Metrics.margin)
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
        HStack(spacing: Metrics.groupSpacing) {
            switch connection.status {
            case .disconnected, .searching:
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Try Again") { attemptConnect() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier(AccessibilityID.dgtRetryButton)

            case .connecting:
                Spacer()
                // Dismisses too: a cancelled attempt leaves `.disconnected`
                // with the board still enumerated, and the resting panel
                // would read as an attempt that isn't happening.
                Button("Cancel") {
                    Task {
                        await connection.disconnect()
                        dismiss()
                    }
                }
                .accessibilityIdentifier(AccessibilityID.dgtCancelButton)

            case .reconnecting:
                // Standing the loop down is deliberate but not destructive —
                // nothing is lost; the game stays right there on screen.
                // The `search()` refreshes the enumeration so the panel
                // this resolves to tells the truth about the (almost
                // certainly absent) board.
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
                // Dismisses for the Cancel reason: a deliberate disconnect
                // shouldn't resolve to a panel that looks like a stalled
                // connect.
                Button("Disconnect", role: .destructive) {
                    Task {
                        await connection.disconnect()
                        dismiss()
                    }
                }
                .accessibilityIdentifier(AccessibilityID.dgtDisconnectButton)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)

            case .failed:
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Try Again") { attemptConnect() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier(AccessibilityID.dgtRetryButton)
            }
        }
        .padding(Metrics.margin)
    }
}

// MARK: Previews

/// `DGTConnection.status` is `private(set)`, so the window can't be driven
/// past its resting state from a preview — the standing waiver. What a
/// boardless canvas honestly shows is the not-found panel, which is also
/// the one state a boardless *manual* run can verify; the other panels are
/// connect-flow manual-check territory, as they always were.
#Preview("Board Not Found") {
    DGTConnectionView()
        .environment(DGTConnection())
}
