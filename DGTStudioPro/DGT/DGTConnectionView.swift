import SwiftUI

/// The board connection window - a confirmation/error surface since the device picker was
/// deleted (the app connects to `onlyBoardPath`, never anything else). A thin view over the
/// app-global `DGTConnection`; never opens a port itself.
struct DGTConnectionView: View {

    /// Its own window since 16 Aug 2026 (was `BoardDestination`'s sheet - the everything-is-a-window
    /// pass). A singleton `Window` opened by id, the View Options shape: one board, one connection,
    /// no wrapper type to mint. `dismiss` closes the window now; the buttons read the same.
    static let sceneID = "boardConnection"

    @Environment(DGTConnection.self) private var connection
    @Environment(\.dismiss) private var dismiss

    /// HIG-derived spacing, named: 20 pt sheet margins, 12 pt siblings, 4 pt captions. The
    /// 420 × 320 frame and 260 pt table are *sizing*, not spacing.
    private enum Metrics {
        /// Sheet edge margin (the standard 20 pt dialog content margin).
        static let margin: CGFloat = 20
        /// Sibling controls and grouped elements (12 pt Aqua spacing).
        static let groupSpacing: CGFloat = 12
        /// A text line and its caption.
        static let captionSpacing: CGFloat = 4
        /// The connected panel's info table width - sizing, see above.
        static let infoTableWidth: CGFloat = 260
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            footer
        }
        // Width fixed, height a floor (was a fixed 320 until the trademark showed in full,
        // 16 Aug 2026): the scene's `.contentSize` resizability sizes the window to whatever
        // the connected panel needs, and the sparser panels keep their old proportions.
        .frame(width: 420)
        .frame(minHeight: 320)
        .onAppear {
            // Attempt on sight - unless live or mid-reconnect: a player opening this mid-loop wants to see
            // (or stop) the retry, not restart it.
            if connection.isReconnecting || connection.isConnected { return }
            attemptConnect()
        }
        .accessibilityIdentifier(AccessibilityID.dgtConnectSheet)
    }

    // MARK: The One Attempt

    private func attemptConnect() {
        // `search()` resolves the board itself - the "what counts as the board" rule stays out of views.
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
                // An attempt is in flight; status flips to `.connecting` when the port opens.
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

    /// The one absence the window can name precisely: the path is a constant, so "not found" always
    /// means the same cable.
    private var notFoundPanel: some View {
        ContentUnavailableView {
            Label("Board Not Found", systemImage: "cable.connector.slash")
        } description: {
            Text("Nothing is attached at \(DGTConnection.onlyBoardPath).\nPlug the board in, then try again.")
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

    /// The retry loop's face; the loop lives in `DGTConnection` - this panel is pure status.
    private func reconnectingPanel(_ device: DGTSerialDevice) -> some View {
        VStack(spacing: Metrics.groupSpacing) {
            ProgressView()
                .controlSize(.large)
            Text("Reconnecting to \(device.name)…")
                .font(.callout)
            Text(
                "The board disconnected during a game. Plug it back in, "
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

                // The trademark is the handshake's whole multi-line banner - name, copyright,
                // firmware and hardware lines - so a label:value row truncated it to its first
                // line. A block of its own, shown fully (16 Aug 2026, by request); `fixedSize`
                // is the anti-truncation half of the fix, the window's flexible height the other.
                if let trademark = connection.boardInfo.trademark, !trademark.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trademark").foregroundStyle(.secondary)
                        Text(trademark)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, Metrics.captionSpacing)
                }
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
                // Dismisses too: a cancelled attempt would otherwise read as an attempt that isn't happening.
                Button("Cancel") {
                    Task {
                        await connection.disconnect()
                        dismiss()
                    }
                }
                .accessibilityIdentifier(AccessibilityID.dgtCancelButton)

            case .reconnecting:
                // Standing down is deliberate but not destructive; `search()` refreshes so the resolved panel
                // tells the truth.
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
                // Dismisses - a deliberate disconnect shouldn't resolve to a panel that looks like a stalled connect.
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

/// `status` is `private(set)`, so a canvas can't pass the resting state - the standing waiver.
/// The not-found panel is what a boardless canvas honestly shows.
#Preview("Board Not Found") {
    DGTConnectionView()
        .environment(DGTConnection())
}
