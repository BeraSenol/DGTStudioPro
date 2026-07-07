//
//  DGTAutoConnectPolicy.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 07/07/2026.
//

/// Pure decisions behind M7's connection quality of life, extracted from
/// `DGTConnection` so the interesting choices are unit-testable without
/// hardware — the roadmap's "if retry policy grows logic worth testing,
/// extract it pure." The transport around these calls (ports, timers, the
/// status machine) stays in `DGTConnection` and is manual-checklist
/// territory.
internal enum DGTAutoConnectPolicy {

    // MARK: Launch (M7.2)

    /// The launch decision: which device, if any, to connect to silently.
    /// Requires the feature enabled *and* the remembered device currently
    /// attached, matched by `path` — the stable identity
    /// (`DGTSerialDevice.id`); names can drift between driver versions.
    ///
    /// `isLikelyBoard` is deliberately never consulted: it is sort-only for
    /// the connect dialog, never auto-connect criteria. Silently connecting
    /// to the remembered device still respects the dialog's
    /// confirm-before-connect contract, because that device was explicitly
    /// user-confirmed once — and then proved itself by answering with a
    /// board dump (remembering happens only on the `.connected` transition).
    /// A likely-*looking* stranger has earned neither.
    internal static func launchTarget(
        enabled: Bool,
        rememberedPath: String?,
        among devices: [DGTSerialDevice]
    ) -> DGTSerialDevice? {
        guard enabled, let rememberedPath, !rememberedPath.isEmpty else {
            return nil
        }
        return devices.first { $0.path == rememberedPath }
    }

    // MARK: Reconnect Lap (M7.3)

    /// The three things one lap of the mid-game reconnect loop can decide.
    internal enum ReconnectLap: Equatable {
        /// The game ended or was discarded — stand down quietly. (Success,
        /// discard, and idle are the loop's only exits besides
        /// cancellation; this is the discard/idle one.)
        case stop
        /// Still worth reconnecting, but the device isn't back — sleep.
        case wait
        /// The vanished device's path has reappeared — attempt to open it.
        case attempt
    }

    /// Decides a reconnect lap. `gameActive` is re-asked every lap (via
    /// `DGTConnection.shouldAutoReconnect`) so a discard mid-loop stands
    /// the retry down; `stop` outranks `attempt` — a discarded game ends
    /// the loop even in the same lap the device came back.
    internal static func reconnectLap(
        gameActive: Bool,
        targetPath: String,
        among devices: [DGTSerialDevice]
    ) -> ReconnectLap {
        guard gameActive else { return .stop }
        let deviceIsPresent = devices.contains { $0.path == targetPath }
        return deviceIsPresent ? .attempt : .wait
    }
}
