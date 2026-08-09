/// Pure decisions behind connection QoL, extracted so the choices are testable without hardware.
internal enum DGTAutoConnectPolicy {

    // MARK: The Rule (3 Aug 2026)

    /// Which of `devices` is the board — the one spelling. Matched on `path`, never `name`: exactly
    /// one criterion in the codebase for what counts as the board.
    internal static func board(
        at boardPath: String,
        among devices: [DGTSerialDevice]
    ) -> DGTSerialDevice? {
        devices.first { $0.path == boardPath }
    }

    // MARK: Launch (M7.2; one-board form since 2 Aug 2026)

    /// The launch decision: connect silently iff enabled and **the** board is attached
    /// (`onlyBoardPath` at every production call site). A likely-looking stranger on another path
    /// never wins — there is no heuristic left to win with.
    internal static func launchTarget(
        enabled: Bool,
        boardPath: String,
        among devices: [DGTSerialDevice]
    ) -> DGTSerialDevice? {
        guard enabled else { return nil }
        return board(at: boardPath, among: devices)
    }
    
    // MARK: Reconnect Lap (M7.3)
    
    /// The three things one lap of the mid-game reconnect loop can decide.
    internal enum ReconnectLap: Equatable {
        /// The game ended or was discarded — stand down quietly.
        case stop
        /// Still worth reconnecting, but the device isn't back — sleep.
        case wait
        /// The vanished device's path has reappeared — attempt to open it.
        case attempt
    }
    
    /// Decides a lap. `gameActive` re-asked every lap; `stop` outranks `attempt` — a discarded game
    /// ends the loop even in the lap the device came back.
    internal static func reconnectLap(
        gameActive: Bool,
        targetPath: String,
        among devices: [DGTSerialDevice]
    ) -> ReconnectLap {
        guard gameActive else { return .stop }
        return board(at: targetPath, among: devices) == nil ? .wait : .attempt
    }
}
