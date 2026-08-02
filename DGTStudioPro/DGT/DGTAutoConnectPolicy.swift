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
    
    // MARK: Launch (M7.2; one-board form since 2 Aug 2026)

    /// The launch decision: connect silently iff the feature is enabled and
    /// **the** board is attached — `boardPath` is
    /// `DGTConnection.onlyBoardPath` at every production call site, passed
    /// as a parameter so this stays a pure function of its inputs. Matched
    /// by `path`, the stable identity (`DGTSerialDevice.id`); names can
    /// drift between driver versions.
    ///
    /// This replaced the remembered-device form when the device picker was
    /// deleted: with exactly one lawful board, "remembered" was a variable
    /// holding a constant. `isLikelyBoard` remains deliberately never
    /// consulted — a likely-*looking* stranger on another path never wins,
    /// which is now the entire point of the feature rather than a nuance
    /// of it.
    internal static func launchTarget(
        enabled: Bool,
        boardPath: String,
        among devices: [DGTSerialDevice]
    ) -> DGTSerialDevice? {
        guard enabled else { return nil }
        return devices.first { $0.path == boardPath }
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
