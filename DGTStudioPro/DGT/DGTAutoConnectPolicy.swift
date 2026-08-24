/// Pure decisions behind connection QoL, extracted so the choices are testable without hardware -
/// `DGTAutoConnectPolicyTests` covers all three functions with no serial port in sight.
enum DGTAutoConnectPolicy {
    
    // MARK: The Rule
    
    /// Which of `devices` is the board - the one spelling. Matched on `path`, never `name`: every
    /// other use of `name` in `DGT/` is display or log text.
    ///
    /// Belt and braces, deliberately: `DGTDeviceDiscovery` already pins its IOKit query to the
    /// board's TTY, so in the normal case `devices` cannot contain a stranger. This match is what
    /// covers discovery's fallback branch, where a non-callout path makes it enumerate everything.
    static func board(
        at boardPath: String,
        among devices: [DGTSerialDevice]
    ) -> DGTSerialDevice? {
        devices.first { $0.path == boardPath }
    }
    
    // MARK: Launch
    
    /// Connect silently iff enabled and **the** board is attached. `boardPath` is a parameter only
    /// so this stays testable - production passes `DGTConnection.onlyBoardPath`, a hardcoded
    /// `/dev/cu.usbmodem01`, at every call site. A likely-looking stranger on another path never
    /// wins, because there is no heuristic to win with.
    static func launchTarget(
        enabled: Bool,
        boardPath: String,
        among devices: [DGTSerialDevice]
    ) -> DGTSerialDevice? {
        guard enabled else { return nil }
        return board(at: boardPath, among: devices)
    }
    
    // MARK: Reconnect Lap
    
    /// The three things one lap of the mid-game reconnect loop can decide.
    enum ReconnectLap: Equatable {
        /// The game ended or was discarded - stand down quietly.
        case stop
        /// Still worth reconnecting, but the device isn't back - sleep.
        case wait
        /// The vanished device's path has reappeared - attempt to open it.
        case attempt
    }
    
    /// Decides a lap. `gameActive` re-asked every lap; `stop` outranks `attempt` - a discarded game
    /// ends the loop even in the lap the device came back.
    static func reconnectLap(
        gameActive: Bool,
        targetPath: String,
        among devices: [DGTSerialDevice]
    ) -> ReconnectLap {
        guard gameActive else { return .stop }
        return board(at: targetPath, among: devices) == nil ? .wait : .attempt
    }
}
