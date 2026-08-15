import Foundation
import os

/// App-global connection to a single DGT e-Board — the byte pipe, the connection state machine,
/// and the physical-board snapshot; deliberately not rendering, reconstruction, or chess rules.
/// One app-wide `@Observable`, injected everywhere (the `ModelContainer` pattern).
@Observable
@MainActor
final class DGTConnection {
    
    // MARK: Logging
    
    private static let logger = AppLog.logger(.dgt)
    
    // MARK: Status
    
    enum Status: Equatable {
        case disconnected
        case searching
        case connecting(DGTSerialDevice)
        case connected(DGTSerialDevice)
        /// M7.3 — vanished mid-game, retry loop working. A first-class case, not a side flag: the enum
        /// is this object's single mode (the session's `Mode` discipline).
        case reconnecting(DGTSerialDevice)
        case failed(String)
    }
    
    /// Identifying strings the board reports during the init handshake.
    struct BoardInfo: Equatable, Sendable {
        var serialNumber: String?
        var longSerialNumber: String?
        var trademark: String?
        var version: String?
        var hardwareVersion: String?

        /// The `[Board "…"]` value (D28′): `"DGT "` + the long serial, matching the reference exports
        /// byte for byte; short-serial fallback (truthful beats pretty). On the value type — testable
        /// without a port.
        var identityTag: String? {
            guard let serial = longSerialNumber ?? serialNumber else { return nil }
            return "DGT \(serial)"
        }
    }
    
    // MARK: Observable State
    
    /// The one board this app will ever open (user decree): the literal callout path, matched
    /// exactly. Enumeration-number drift is an accepted failure mode — if macOS renames the port,
    /// Connect shows the error until the board is back on this path.
    nonisolated static let onlyBoardPath = "/dev/cu.usbmodem01"

    private(set) var status: Status = .disconnected

    /// The board, if the last enumeration found it — nil otherwise. Was the whole enumeration array
    /// until the picker retired; a board or nothing is the only distinction the panels draw.
    private(set) var attachedBoard: DGTSerialDevice?
    private(set) var boardInfo = BoardInfo()
    
    /// Live snapshot of detected pieces, app coordinates. Dumps replace wholesale; field updates
    /// patch one square. This is what the mirror renders.
    private(set) var physicalBoard: Position = .empty
    
    var isConnected: Bool {
        if case .connected = status { return true }
        return false
    }

    /// D49′ — one on-demand full dump for the session's `.unresolved` pre-flight. `sendBoard` doesn't
    /// change the board's mode, so the dump rides the existing `.boardDump` handling — free.
    /// Fire-and-forget: a dead port cannot strand the one-shot gate.
    func requestBoardResync() {
        guard isConnected else {
            Self.logger?.info("Board resync requested while disconnected, ignored")
            return
        }
        Self.logger?.info("Requesting full board dump to reconcile before recovery")
        Task {
            do {
                try await port.send(.sendBoard)
            } catch {
                Self.logger?.error(
                    "Board resync send failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
    
    /// True while the reconnect loop runs — the session panel says "reconnecting…", and the connect
    /// dialog avoids tearing the loop down on open.
    var isReconnecting: Bool {
        if case .reconnecting = status { return true }
        return false
    }
    
    // MARK: Diagnostics
    
    /// Optional diagnostic timeline, shared with `DGTLiveSession`; nil-safe.
    @ObservationIgnored var sessionLog: DGTSessionLog?
    
    /// Opt-in board-stream capture for offline replay. Observed — not ignored — because the sleep
    /// inhibitor's tracking loop reads `isRecording` (D14′), so start/stop must register.
    private var recorder: DGTSessionRecorder?
    
    var isRecording: Bool { recorder != nil }
    
    // MARK: Private State
    
    /// The transport (F9-injectable): production wires the real port, tests a scripted fake.
    /// Shared contract: the event stream finishing is the single "port is gone" signal.
    @ObservationIgnored private let port: any DGTPortProviding
    
    /// Called after every board change with the new board; drives the session's quiescence timer.
    /// A wiring hook, not UI state.
    @ObservationIgnored var onBoardChanged: ((Position) -> Void)?
    
    /// M7.3 — is a vanished board worth auto-reconnecting to? Asked at stream end and on every lap
    /// (so the loop stands down when the game goes away). Nil (headless tests) means never.
    @ObservationIgnored var shouldAutoReconnect: (() -> Bool)?
    
    /// Device-enumeration seam (F9): real IOKit walk by default, scripted list in tests.
    @ObservationIgnored var enumerateDevices: () -> [DGTSerialDevice] = {
        DGTDeviceDiscovery.availableDevices()
    }
    
    /// UserDefaults seam (F9): tests inject a throwaway suite so ⌘U never reads real preferences.
    @ObservationIgnored var defaults: UserDefaults = .standard
    
    @ObservationIgnored private var readTask: Task<Void, Never>?
    @ObservationIgnored private var errorClearTask: Task<Void, Never>?
    
    /// M7.3 — the retry loop, alive only while `status` is `.reconnecting`.
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    
    /// Last reconnect-failure message this episode, so present-but-unopenable logs once per distinct
    /// failure rather than ~1200×/h (B4).
    @ObservationIgnored private var lastReconnectFailureLogged: String?
    
    /// Init-command spacing so a shallow input buffer isn't overrun; tests zero it (F9).
    @ObservationIgnored var initCommandStagger: Duration = .milliseconds(75)
    
    /// How long a `.failed` status lingers before auto-clearing to
    /// `.disconnected`.
    @ObservationIgnored private let errorLingerDuration: Duration = .seconds(5)
    
    /// M7.3 lap spacing. Timed retry over IOKit arrival notifications is a deliberate v1 simplification.
    @ObservationIgnored var reconnectRetryInterval: Duration = .seconds(3)
    
    /// Production takes the default (real serial port); tests pass a fake (F9).
    init(port: any DGTPortProviding = DGTSerialPort()) {
        self.port = port
    }
    
    // MARK: Discovery
    
    /// Enumerates for the connect dialog; synchronous and cheap. Precondition: not connected —
    /// `search()` demotes status without tearing the port down.
    func search() {
        assert(!isConnected, "search() while connected strands status in .searching")
        cancelReconnect()
        cancelErrorClear()
        status = .searching
        // Through the policy, not a local `first { path == … }` — one rule, suited there; a restatement
        // here would be the third spelling in two files.
        attachedBoard = DGTAutoConnectPolicy.board(
            at: Self.onlyBoardPath,
            among: enumerateDevices()
        )
        // The board's presence, not a device count — the count was the picker's question.
        if let attachedBoard {
            Self.logger?.info("Board found at \(attachedBoard.path, privacy: .public)")
            sessionLog?.capture(.debug, "search: board attached [\(attachedBoard.name)]")
        } else {
            Self.logger?.info("No board attached")
            sessionLog?.capture(.debug, "search: board not attached")
        }
    }
    
    // MARK: Connect / Disconnect
    
    /// Opens `device`, consumes events, runs init. `.connected` once the first dump arrives.
    func connect(to device: DGTSerialDevice) async {
        await connect(to: device, failureStyle: .announced)
    }
    
    /// Launch path (M7.2, one-board form): if enabled and `onlyBoardPath` is attached, connect
    /// silently. Failures are `.quiet` — no red linger for a board that isn't plugged in.
    /// Does not set `attachedBoard`: it enumerates for the decision only.
    func autoConnectAtLaunch() async {
        // Absent reads as true — matches the `@AppStorage` default in Settings (documented twin).
        let enabled = defaults.object(forKey: StorageKeys.autoConnectOnLaunch) as? Bool ?? true

        guard let target = DGTAutoConnectPolicy.launchTarget(
            enabled: enabled,
            boardPath: Self.onlyBoardPath,
            among: enumerateDevices()
        ) else {
            Self.logger?.info("Auto-connect at launch: the board is not attached")
            return
        }
        // Paranoia more than necessity — nothing else connects this early.
        guard case .disconnected = status else { return }

        Self.logger?.info("Auto-connecting to the board at \(target.path, privacy: .public)")
        sessionLog?.capture(.info, "Auto-connecting to \(target.name) [\(target.path)]")
        await connect(to: target, failureStyle: .quiet)
    }
    
    /// Shared connect body. `.announced` (dialog) shows the `.failed` banner; `.quiet` (launch) goes
    /// straight to `.disconnected`.
    private func connect(to device: DGTSerialDevice, failureStyle: FailureStyle) async {
        cancelReconnect()  // a fresh connect supersedes any retry loop
        cancelErrorClear()
        await teardownPort()
        
        status = .connecting(device)
        boardInfo = BoardInfo()
        // Direct assignment bypasses `onBoardChanged`: clearing the mirror must not fire a spurious settle.
        physicalBoard = .empty
        Self.logger?.info("Connecting to \(device.path, privacy: .public)")
        sessionLog?.capture(.info, "Connecting to \(device.name) [\(device.path)]")
        
        if let failure = await openPortAndRunInit(to: device) {
            fail(failure, style: failureStyle)
        }
    }
    
    /// Disconnects and resets to `.disconnected`.
    func disconnect() async {
        Self.logger?.info("Disconnecting")
        sessionLog?.capture(.info, "Disconnecting")
        cancelReconnect()
        await teardownPort()
        status = .disconnected
        physicalBoard = .empty
    }
    
    // MARK: Port Bring-Up
    
    /// Opens the port, starts event consumption, sends init. Touches no `status` — each caller owns
    /// its own state story. Success is only confirmed later, by the first dump.
    private func openPortAndRunInit(to device: DGTSerialDevice) async -> String? {
        let events: AsyncStream<DGTEvent>
        do {
            events = try await port.open(path: device.path)
        } catch {
            return "Could not open \(device.name): \(error)"
        }
        
        // F3: cancelled while `open` was in flight → a newer flow owns the port; close what this opened
        // and stand down quietly (nil — nobody paints a banner for being superseded).
        guard !Task.isCancelled else {
            await port.close()
            return nil
        }
        
        readTask = Task { [weak self] in
            for await event in events {
                self?.handle(event)
            }
            // The stream finishes when the port closes: our own teardown (task already cancelled) or the
            // device vanished (F1). Only the latter is news.
            if !Task.isCancelled {
                self?.handleStreamEnd()
            }
        }
        
        return await runInitSequence()
    }
    
    // MARK: Init Sequence
    
    /// DGT startup commands, staggered. Reset first (stops prior streaming), update-board last
    /// (starts field updates). Returns a failure description or nil; the caller decides how loudly.
    private func runInitSequence() async -> String? {
        let sequence: [DGTCommand] = [
            .sendReset,
            .returnLongSerialNumber,
            .returnSerialNumber,
            .sendTrademark,
            .sendVersion,
            .sendHardwareVersion,
            .sendBoard,        // one full dump → flips us to .connected
            .sendUpdateBoard,  // begin field-update streaming
        ]
        
        for command in sequence {
            // F3: after cancellation stop driving the port immediately — the old `try?` swallowed the
            // sleep's `CancellationError` and kept sending into a port a newer flow owned.
            guard !Task.isCancelled else { return nil }
            do {
                try await port.send(command)
            } catch {
                return "Init command 0x\(String(command.rawValue, radix: 16)) failed: \(error)"
            }
            do {
                try await Task.sleep(for: initCommandStagger)
            } catch {
                return nil  // cancelled mid-stagger — stand down quietly
            }
        }
        Self.logger?.info("Init sequence sent")
        sessionLog?.capture(.debug, "Init sequence sent")
        return nil
    }
    
    // MARK: Event Handling
    
    private func handle(_ event: DGTEvent) {
        switch event {
        case .boardDump(let position):
            physicalBoard = position
            publishBoardChange()
            // First dump confirms a live, talking board — window connect and reconnect lap alike.
            switch status {
            case .connecting(let device), .reconnecting(let device):
                status = .connected(device)
                Self.logger?.info("Connected: first board dump received")
                sessionLog?.capture(.info, "Connected: first board dump received from \(device.name)")
            default:
                break
            }
            
        case .fieldUpdate(let square, let piece):
            physicalBoard[square] = piece
            publishBoardChange()
            
        case .serialNumber(let value):
            boardInfo.serialNumber = value
            noteBoardInfo("Board serial", value)
            
        case .longSerialNumber(let value):
            boardInfo.longSerialNumber = value
            noteBoardInfo("Board long serial", value)
            
        case .trademark(let value):
            boardInfo.trademark = value
            noteBoardInfo("Board trademark", value)
            
        case .version(let major, let minor):
            let value = "\(major).\(minor)"
            boardInfo.version = value
            noteBoardInfo("Board version", value)
            
        case .hardwareVersion(let major, let minor):
            let value = "\(major).\(minor)"
            boardInfo.hardwareVersion = value
            noteBoardInfo("Board hardware version", value)
        }
    }
    
    /// The fan-out every board change owes: session quiescence, then the recorder. The *mutation*
    /// stays at the call site — it's the fan-out that must not diverge.
    private func publishBoardChange() {
        onBoardChanged?(physicalBoard)
        recorder?.record(physicalBoard)
    }
    
    /// One board-identity line, Console and buffer from one call. `privacy: .public` is explicit —
    /// interpolated `String`s are redacted by default.
    private func noteBoardInfo(_ label: String, _ value: String) {
        Self.logger?.info("\(label): \(value, privacy: .public)")
        sessionLog?.capture(.debug, "\(label): \(value)")
    }
    
    private func handleStreamEnd() {
        // Stale-stream guard: only a stream backing `.connected`/`.connecting` is news. `.reconnecting`
        // laps own their failures; the other states mean a newer flow already tore this down.
        switch status {
        case .connected, .connecting:
            break
        case .reconnecting, .disconnected, .searching, .failed:
            return
        }
        
        Self.logger?.error("Serial stream ended unexpectedly")
        
        // M7.3 — mid-game vanish begins the reconnect loop instead of the banner. Convergence after
        // replug needs no session changes: the fresh dump flows through settle.
        if let device = connectedDevice, shouldAutoReconnect?() == true {
            beginReconnect(to: device)
        } else {
            fail("The board was disconnected.")
        }
    }
    
    /// The device behind a `.connected` status, if any.
    private var connectedDevice: DGTSerialDevice? {
        if case .connected(let device) = status { return device }
        return nil
    }
    
    // MARK: Auto-Reconnect (M7.3)
    
    /// Enters `.reconnecting`, starts the retry loop. Target read from `status` — `onlyBoardPath` by
    /// construction.
    private func beginReconnect(to device: DGTSerialDevice) {
        Self.logger?.error("Board vanished mid-game, auto-reconnecting to \(device.path, privacy: .public)")
        sessionLog?.capture(.error, "Board vanished mid-game, auto-reconnecting to \(device.name)")
        
        // Truthful mirror: nothing is detected while unplugged. Direct assignment — no spurious settle.
        physicalBoard = .empty
        status = .reconnecting(device)
        
        lastReconnectFailureLogged = nil
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            await self?.runReconnectLoop(to: device)
        }
    }
    
    /// One lap per interval: stand down if the game went away, attempt when the path reappeared,
    /// else sleep. Status stays `.reconnecting` across failed laps; cancellation checked after every
    /// await so a zombie lap can't fight a newer flow.
    private func runReconnectLoop(to device: DGTSerialDevice) async {
        while !Task.isCancelled {
            switch DGTAutoConnectPolicy.reconnectLap(
                gameActive: shouldAutoReconnect?() == true,
                targetPath: device.path,
                among: enumerateDevices()
            ) {
            case .stop:
                // The discard/idle exit: quiet, nothing left to reconnect for.
                Self.logger?.info("Auto-reconnect stopped: no active game")
                sessionLog?.capture(.info, "Auto-reconnect stopped, no active game")
                await teardownPort()
                if !Task.isCancelled { status = .disconnected }
                return
                
            case .wait:
                break  // device not back yet — just sleep below
                
            case .attempt:
                Self.logger?.info("Auto-reconnect: device reappeared, attempting")
                await teardownPort()  // close any half-open port from a prior lap
                guard !Task.isCancelled else { return }
                boardInfo = BoardInfo()
                if let failure = await openPortAndRunInit(to: device) {
                    // Dedupe present-but-unopenable (B4): first occurrence and each distinct failure, not per lap.
                    if failure != lastReconnectFailureLogged {
                        Self.logger?.error("Reconnect attempt failed: \(failure, privacy: .public)")
                        sessionLog?.capture(.error, "Reconnect attempt failed: \(failure)")
                        lastReconnectFailureLogged = failure
                    }
                }
            }
            
            // The first dump can land during the attempt itself — don't sleep a full interval on a live connection.
            if isConnected { return }
            try? await Task.sleep(for: reconnectRetryInterval)
            guard !Task.isCancelled else { return }
            if isConnected { return }
        }
    }
    
    /// "Stop Trying". Ends `.disconnected`, never `.failed` — being asked to stop is not an error.
    func stopReconnecting() async {
        guard case .reconnecting = status else { return }
        Self.logger?.info("Auto-reconnect cancelled by user")
        sessionLog?.capture(.info, "Auto-reconnect cancelled by user")
        cancelReconnect()
        await teardownPort()
        status = .disconnected
    }
    
    private func cancelReconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    // MARK: Session Recording
    
    /// Begins capturing board changes for offline replay; replaces any in-progress recording.
    func startRecording() {
        let recorder = DGTSessionRecorder()
        recorder.record(physicalBoard)
        self.recorder = recorder
        Self.logger?.info("Board session recording started")
        sessionLog?.capture(.info, "Board session recording started")
    }
    
    /// Stops and returns the recording, stamped with the board identity; nil if none active.
    @discardableResult
    func stopRecording() -> DGTSessionRecording? {
        guard let recorder else { return nil }
        recorder.identity = .init(
            serialNumber: boardInfo.serialNumber,
            version: boardInfo.version,
            trademark: boardInfo.trademark
        )
        let recording = recorder.finish()
        self.recorder = nil
        Self.logger?.info("Board session recording stopped: snapshots=\(recording.entries.count)")
        sessionLog?.capture(.info, "Board session recording stopped, \(recording.entries.count) snapshots")
        return recording
    }
    
    // MARK: Failure / Teardown
    
    /// How an open/init failure surfaces (M7.2).
    private enum FailureStyle {
        /// `.failed` + five-second linger — user-initiated attempts, where the player is watching.
        case announced
        /// Straight to `.disconnected`, log line only — an unplugged board at launch is unremarkable.
        case quiet
    }
    
    private func fail(_ message: String, style: FailureStyle = .announced) {
        Self.logger?.error("\(message, privacy: .public)")
        sessionLog?.capture(.error, "Connection failure: \(message)")
        physicalBoard = .empty
        switch style {
        case .announced:
            status = .failed(message)
            scheduleErrorClear()
        case .quiet:
            status = .disconnected
        }
    }
    
    /// Auto-clears `.failed` → `.disconnected` so a transient failure doesn't strand the UI.
    private func scheduleErrorClear() {
        cancelErrorClear()
        errorClearTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.errorLingerDuration)
            guard !Task.isCancelled else { return }
            if case .failed = self.status {
                self.status = .disconnected
            }
        }
    }
    
    private func cancelErrorClear() {
        errorClearTask?.cancel()
        errorClearTask = nil
    }
    
    private func teardownPort() async {
        readTask?.cancel()
        readTask = nil
        await port.close()
    }
}
