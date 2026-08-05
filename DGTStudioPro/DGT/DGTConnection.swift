//
//  DGTConnection.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 25/05/2026.
//

import Foundation
import os

/// App-global connection to a single DGT e-Board.
///
/// One board per app, so this is one app-wide `@Observable` created on
/// `DGTStudioProApp` and injected into every tab via `.environment(_:)` — the
/// same lifetime/sharing pattern as the shared `ModelContainer` and
/// `OpenGamesRegistry`.
///
/// It orchestrates the connection lifecycle:
/// 1. `search()` enumerates serial devices (IOKit) for the connect dialog.
/// 2. `connect(to:)` opens the port, then runs the staggered init sequence
///    (reset → info queries → board dump → update-board) the DGT spec
///    prescribes, logging which messages the board answers.
/// 3. The decoded `DGTEvent` stream from the background `DGTSerialPort` actor
///    is consumed here on the `@MainActor`, updating `boardInfo` and the live
///    `physicalBoard` mirror.
///
/// What D2 owns: the byte pipe, the connection state machine, and the live
/// physical-board snapshot. What it deliberately does *not* own yet: rendering
/// (D3), move reconstruction (D4), or any chess logic — `physicalBoard` is a
/// raw mirror of detected pieces, nothing more.
///
/// Connection quality of life (M7): every successful connect remembers the
/// device (M7.1); launch can silently reconnect to it behind a Settings
/// toggle, failing *quietly* when it can't (M7.2, `autoConnectAtLaunch()`);
/// and a board that vanishes mid-game enters `.reconnecting` — a timed retry
/// loop that ends only in success, the game going away, or the player
/// standing it down (M7.3). The decisions are pure (`DGTAutoConnectPolicy`)
/// so they test without hardware; the machinery here around them does not.
///
/// Diagnostics: lifecycle milestones (connect, board identity, disconnect,
/// failures, stream end) are mirrored into the optional `sessionLog`
/// (`DGTSessionLog`) so the transport story sits in the same exportable
/// timeline as the live-session events — when a desync is captured, the board
/// identity and connection history that preceded it are right there above it.
/// Existing Console logging is untouched; recorder writes use `capture`
/// (buffer-only) to avoid double Console output.
///
/// It can also opt into recording the live board stream (`startRecording()`)
/// into a `DGTSessionRecording` for offline, hardware-free replay of
/// reconstruction / recovery — see that type.
@Observable
@MainActor
internal final class DGTConnection {
    
    // MARK: Logging
    
    private static let logger = AppLog.logger(.dgt)
    
    // MARK: Status
    
    internal enum Status: Equatable {
        case disconnected
        case searching
        case connecting(DGTSerialDevice)
        case connected(DGTSerialDevice)
        /// M7.3 — the board vanished mid-game and the timed retry loop is
        /// working to get it back. A first-class case, not a side flag: the
        /// status enum is this object's single mode, the same discipline as
        /// the session's private `Mode` — flags derived from one machine can
        /// never contradict each other.
        case reconnecting(DGTSerialDevice)
        case failed(String)
    }
    
    /// Identifying strings the board reports during the init handshake.
    internal struct BoardInfo: Equatable, Sendable {
        internal var serialNumber: String?
        internal var longSerialNumber: String?
        internal var trademark: String?
        internal var version: String?
        internal var hardwareVersion: String?

        /// The `[Board "…"]` tag value for games played on this board
        /// (D28′): `"DGT "` + the long serial, matching the DGT reference
        /// exports byte for byte (`DGT 3000448278` — ten digits, the *long*
        /// serial; the short one is five characters). Falls back to the
        /// short serial when only that answered — a truthful identity beats
        /// a `?` — and nil until the handshake supplies either, which is
        /// also why `connect(to:)` resetting `boardInfo` makes a mid-game
        /// reconnect window read nil: exactly the case `Roster.board`'s
        /// capture-at-start exists to survive. On the value type, not the
        /// connection, so the composition is testable without a port.
        internal var identityTag: String? {
            guard let serial = longSerialNumber ?? serialNumber else { return nil }
            return "DGT \(serial)"
        }
    }
    
    // MARK: Observable State
    
    /// The one board this app will ever open (user decree, 2 Aug 2026):
    /// the literal callout path, matched exactly — "never ever anything
    /// else". Enumeration-number drift is an accepted failure mode by
    /// choice: if macOS ever renames the port, Connect shows the error
    /// window until the board is back on this path. This constant retired
    /// the remembered-device machinery (M7.1) — a hardcoded identity needs
    /// no memory — and the connect dialog's device picker with it.
    ///
    /// `nonisolated` because it is an immutable `String`, and nothing about a
    /// hardcoded device path is main-actor work. Without it the constant
    /// inherits this class's isolation, which makes it unreadable from the
    /// initializer of a stored property in any nonisolated type — and the
    /// first thing that wanted to read it that way was
    /// `DGTAutoConnectPolicyTests`, whose whole point is that a pure-value
    /// suite stays nonisolated. Isolating a constant to reach it from a test
    /// would have been the tail wagging the dog; the constant was simply
    /// over-isolated by inheritance.
    nonisolated internal static let onlyBoardPath = "/dev/cu.usbmodem01"

    private(set) internal var status: Status = .disconnected

    /// The board, if the last enumeration found it attached — nil if it
    /// didn't, and nil before anything has looked.
    ///
    /// Was `availableDevices: [DGTSerialDevice]`, the whole enumeration, until
    /// 3 Aug 2026. That array was picker-shaped state: its one reader
    /// immediately reduced it to `first { $0.path == onlyBoardPath }`, so the
    /// property advertised a choice the app stopped offering with the
    /// one-board decree. Resolving it here rather than at the reader puts the
    /// rule beside the constant it tests against, and leaves the view holding
    /// a board or nothing — which is the only distinction its panels draw.
    ///
    /// Still the full enumeration underneath: `enumerateDevices` walks
    /// everything IOKit reports, because IOKit has no match-one-path query.
    /// What changed is that the strangers are dropped at the door instead of
    /// being carried into observable state that renders none of them.
    private(set) internal var attachedBoard: DGTSerialDevice?
    private(set) internal var boardInfo = BoardInfo()
    
    /// Live snapshot of the pieces the board currently detects, in app
    /// coordinates. Updated wholesale by board dumps and per-square by field
    /// updates. This is what D3's mirror view renders.
    private(set) internal var physicalBoard: Position = .empty
    
    internal var isConnected: Bool {
        if case .connected = status { return true }
        return false
    }

    /// D49′ — one full-board dump on demand, the session's `.unresolved`
    /// pre-flight. `sendBoard` does not change the board's mode, so the
    /// `UPDATE_BOARD` field stream continues untouched and the dump simply
    /// replaces `physicalBoard` wholesale through the existing `.boardDump`
    /// handling — which is what makes the resync strategy free. Fire-and-
    /// forget by design: the *answer* arrives as a published board change
    /// and settles like any other; a send failure is logged, and the
    /// session's next unresolved settle escalates to recovery regardless,
    /// so a dead port cannot strand the one-shot gate.
    internal func requestBoardResync() {
        guard isConnected else {
            Self.logger?.info("Board resync requested while disconnected — ignored")
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
    
    /// True while the M7.3 auto-reconnect loop is running. The sidebar's
    /// session panel reads this to say "reconnecting…" instead of showing no
    /// card at all, and the connect dialog to avoid tearing the loop down on
    /// open.
    internal var isReconnecting: Bool {
        if case .reconnecting = status { return true }
        return false
    }
    
    // MARK: Diagnostics
    
    /// Optional exportable diagnostic timeline, shared with `DGTLiveSession`.
    /// Wired by the app (`connection.sessionLog = log`); nil-safe.
    @ObservationIgnored internal var sessionLog: DGTSessionLog?
    
    /// Opt-in capture of the live board stream for offline replay/regression
    /// (see `DGTSessionRecording`). Nil unless `startRecording()` is active.
    ///
    /// Observed — not `@ObservationIgnored` — since M-ux.2 (D14′): the
    /// sleep inhibitor's tracking loop reads `isRecording`, so the flip in
    /// `startRecording`/`stopRecording` must register (it also makes
    /// `DiagnosticsCommands`' menu-title tracking true by construction).
    /// Costs nothing on the hot path: board snapshots *call into* the
    /// recorder (`recorder?.record(_:)`); only start/stop mutate the
    /// property itself.
    private var recorder: DGTSessionRecorder?
    
    internal var isRecording: Bool { recorder != nil }
    
    // MARK: Private State
    
    /// The transport (F9-injectable). Production wires the real serial port
    /// via the default `init`; tests inject a scripted `DGTPortProviding`
    /// fake so connect, event routing, stream-end, and reconnect logic run
    /// without hardware. The contract both share: the event stream finishing
    /// is the single "port is gone" signal (see `DGTPortProviding`).
    @ObservationIgnored private let port: any DGTPortProviding
    
    /// Called after every physical-board change (dump or field update) with the
    /// new board. `DGTLiveSession` sets this to drive its quiescence timer and
    /// move reconstruction. Kept out of observation — it's a wiring hook, not
    /// UI state.
    @ObservationIgnored internal var onBoardChanged: ((Position) -> Void)?
    
    /// M7.3 — asked whether a vanished board is worth auto-reconnecting to:
    /// once when the stream ends, then again on every retry lap (so the loop
    /// stands down when the game is discarded or the session returns to
    /// idle). The app wires this exactly once in `App.init()` to "the
    /// session is in any game-bearing mode". Nil (headless unit tests) means
    /// never — the pre-M7 red-banner behavior is preserved by construction,
    /// the same nil-hook pattern as `sessionLog` and `draftStore`.
    @ObservationIgnored internal var shouldAutoReconnect: (() -> Bool)?
    
    /// Device-enumeration seam (F9): defaults to the real IOKit walk; tests
    /// inject a scripted list so `search()`, the launch auto-connect check,
    /// and the reconnect lap's "is it back yet?" probe run hermetically
    /// instead of walking the test host's IORegistry. The same settable-hook
    /// pattern as `sessionLog` and `shouldAutoReconnect`; production never
    /// writes it.
    @ObservationIgnored internal var enumerateDevices: () -> [DGTSerialDevice] = {
        DGTDeviceDiscovery.availableDevices()
    }
    
    /// UserDefaults seam (F9): tests inject a throwaway suite so the launch
    /// auto-connect's enabled-flag read never touches the developer's real
    /// preferences from the ⌘U host. (The remembered-device *write* this
    /// seam also isolated retired with the picker — the flag read is what
    /// remains.) Production never writes it.
    @ObservationIgnored internal var defaults: UserDefaults = .standard
    
    @ObservationIgnored private var readTask: Task<Void, Never>?
    @ObservationIgnored private var errorClearTask: Task<Void, Never>?
    
    /// M7.3 — the retry loop, alive only while `status` is `.reconnecting`.
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    
    /// M7.3 / checklist B4 — the last reconnect-attempt failure message
    /// logged this episode, so a board that stays *present but unopenable*
    /// (another process holding the port) logs once per distinct failure
    /// rather than ~1 200×/h. Reset when a fresh reconnect episode begins.
    @ObservationIgnored private var lastReconnectFailureLogged: String?
    
    /// Spacing between init commands so a board with a shallow input buffer
    /// isn't overrun, and so the log clearly attributes each response.
    /// Internal-settable so fake-port tests zero it (F9); production never
    /// writes it.
    @ObservationIgnored internal var initCommandStagger: Duration = .milliseconds(75)
    
    /// How long a `.failed` status lingers before auto-clearing to
    /// `.disconnected`.
    @ObservationIgnored private let errorLingerDuration: Duration = .seconds(5)
    
    /// M7.3 — spacing between auto-reconnect laps. Timed retry over IOKit
    /// arrival notifications is a deliberate v1 simplification; the
    /// notification alternative is parked in the roadmap's parking lot.
    /// Internal-settable so tests shrink laps to milliseconds (F9);
    /// production never writes it.
    @ObservationIgnored internal var reconnectRetryInterval: Duration = .seconds(3)
    
    /// Production callers take the default (the real serial port); tests
    /// pass a `DGTPortProviding` fake (F9).
    internal init(port: any DGTPortProviding = DGTSerialPort()) {
        self.port = port
    }
    
    // MARK: Discovery
    
    /// Enumerates attached serial devices for the connect dialog. Synchronous
    /// and cheap; the "progress bar while searching" UX is the dialog's, since
    /// IOKit enumeration returns immediately.
    /// Precondition: not currently connected. `search()` demotes `status` to
    /// `.searching` without tearing the port down, and `handle(_:)` only
    /// promotes to `.connected` from `.connecting` / `.reconnecting` — so
    /// calling this on a live board strands the UI in `.searching` while the
    /// session keeps committing moves off a port nobody thinks is open. The
    /// connect dialog upholds this today (`onAppear` guards on `isConnected`,
    /// and Rescan only exists in the disconnected footers); the assertion puts
    /// the invariant on the object that owns the status rather than on a view.
    internal func search() {
        assert(!isConnected, "search() while connected strands status in .searching")
        cancelReconnect()
        cancelErrorClear()
        status = .searching
        // Through the policy, not a local `first { $0.path == … }`: that
        // predicate is the one rule for what counts as the board, and it is
        // suited there. Restating it here would have made this the third
        // spelling in two files.
        attachedBoard = DGTAutoConnectPolicy.board(
            at: Self.onlyBoardPath,
            among: enumerateDevices()
        )
        // The board's presence, not a device count. The count was the picker's
        // question ("what can I choose from?"); this one's is the only question
        // left, and it is the one worth reading in Console at launch.
        if let attachedBoard {
            Self.logger?.info("Board found at \(attachedBoard.path, privacy: .public)")
            sessionLog?.capture(.debug, "search: board attached [\(attachedBoard.name)]")
        } else {
            Self.logger?.info("No board attached")
            sessionLog?.capture(.debug, "search: board not attached")
        }
    }
    
    // MARK: Connect / Disconnect
    
    /// Opens `device`, begins consuming events, and runs the init sequence.
    /// Status advances to `.connected` once the board's first dump arrives.
    internal func connect(to device: DGTSerialDevice) async {
        await connect(to: device, failureStyle: .announced)
    }
    
    /// M7.2 — the launch path, in its one-board form (2 Aug 2026): if the
    /// feature is enabled and `onlyBoardPath` is currently attached,
    /// connect to it silently. Failures here are `.quiet` — straight to
    /// `.disconnected` with a Console line, no five-second red linger for
    /// a board that simply isn't plugged in. (A board that isn't even
    /// enumerated never opens anything at all — see
    /// `DGTAutoConnectPolicy.launchTarget`.)
    ///
    /// The old confirm-before-connect contract is discharged by the decree
    /// itself: with exactly one lawful path, the constant *is* the standing
    /// confirmation. The policy's tests still pin that a likely-looking
    /// stranger never wins, and since 3 Aug 2026 there is no heuristic left
    /// for one to win *with* — `path` equality is the only criterion in the
    /// codebase.
    ///
    /// This does not set `attachedBoard`: it enumerates for the decision and
    /// discards, because a silent launch attempt has no panel to inform.
    /// `search()` is what publishes presence, and the connect window calls it
    /// on the way in.
    internal func autoConnectAtLaunch() async {
        // Absent reads as true — matches the `@AppStorage` default in
        // Settings ("Connect to board automatically", default on).
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
    
    /// The shared connect body. `failureStyle` decides how an open/init
    /// failure surfaces: `.announced` (the dialog path) shows the `.failed`
    /// banner with its auto-clear; `.quiet` (the launch auto path) goes
    /// straight to `.disconnected` — the roadmap's quiet failure variant.
    private func connect(to device: DGTSerialDevice, failureStyle: FailureStyle) async {
        cancelReconnect()  // a fresh connect supersedes any retry loop
        cancelErrorClear()
        await teardownPort()
        
        status = .connecting(device)
        boardInfo = BoardInfo()
        // Direct assignment deliberately bypasses `onBoardChanged`: clearing
        // the mirror must not fire a spurious settle into the session. M7.3
        // reconnection leans on this same property.
        physicalBoard = .empty
        Self.logger?.info("Connecting to \(device.path, privacy: .public)")
        sessionLog?.capture(.info, "Connecting to \(device.name) [\(device.path)]")
        
        if let failure = await openPortAndRunInit(to: device) {
            fail(failure, style: failureStyle)
        }
    }
    
    /// Disconnects and resets to `.disconnected`.
    internal func disconnect() async {
        Self.logger?.info("Disconnecting")
        sessionLog?.capture(.info, "Disconnecting")
        cancelReconnect()
        await teardownPort()
        status = .disconnected
        physicalBoard = .empty
    }
    
    // MARK: Port Bring-Up
    
    /// Opens the port, starts the event-consuming task, and sends the init
    /// sequence. Touches no `status` — each caller (dialog connect, launch
    /// auto-connect, mid-game reconnect lap) owns its own state story around
    /// it. Returns a failure description, or nil when everything was sent;
    /// *success* is only confirmed later, by the first board dump landing in
    /// `handle(_:)`.
    private func openPortAndRunInit(to device: DGTSerialDevice) async -> String? {
        let events: AsyncStream<DGTEvent>
        do {
            events = try await port.open(path: device.path)
        } catch {
            return "Could not open \(device.name): \(error)"
        }
        
        // F3: a reconnect lap (or any connect flow) cancelled while `open`
        // was in flight must not install a read task or start the handshake
        // — a newer flow owns the port now. Close what this call just opened
        // and stand down quietly (nil, not a failure string: nobody paints a
        // banner for being superseded).
        guard !Task.isCancelled else {
            await port.close()
            return nil
        }
        
        readTask = Task { [weak self] in
            for await event in events {
                self?.handle(event)
            }
            // The stream finishes when the port closes — because we tore it
            // down (this task is already cancelled then) or because the
            // device vanished and the port closed itself (F1). Only the
            // latter is news.
            if !Task.isCancelled {
                self?.handleStreamEnd()
            }
        }
        
        return await runInitSequence()
    }
    
    // MARK: Init Sequence
    
    /// Sends the DGT-prescribed startup commands, staggered. Reset comes first
    /// (it stops any prior update streaming); update-board comes last (it
    /// starts field-update streaming). Responses arrive asynchronously via the
    /// event stream. Returns a failure description or nil — the caller decides
    /// how loudly to fail (M7.2's quiet path never shows the red banner).
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
            // F3: once the surrounding task is cancelled, a superseded flow
            // must stop driving the port immediately — the old `try?` here
            // swallowed the sleep's `CancellationError` and kept sending the
            // remaining commands back-to-back into a port a newer flow now
            // owned. Cancellation ends the sequence quietly (nil: the
            // canceller already owns the status story).
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
            // First dump confirms a live, talking board — whether this was a
            // window connect or an M7.3 reconnect lap. (This transition used
            // to also persist the device for launch auto-connect; the
            // remembered-device machinery retired with `onlyBoardPath`.)
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
    
    /// The fan-out every physical-board change owes: the session's quiescence
    /// timer, then the optional recorder. The *mutation* stays at the call site
    /// — a dump replaces the board, a field update patches one square — because
    /// it's the fan-out, not the write, that must not diverge between them.
    private func publishBoardChange() {
        onBoardChanged?(physicalBoard)
        recorder?.record(physicalBoard)
    }
    
    /// One board-identity milestone, Console and buffer from a single call, so
    /// the two strings can't drift. `privacy: .public` is explicit because a
    /// `String` interpolation is redacted by default — the previous per-case
    /// lines relied on that annotation being remembered six times.
    private func noteBoardInfo(_ label: String, _ value: String) {
        Self.logger?.info("\(label): \(value, privacy: .public)")
        sessionLog?.capture(.debug, "\(label): \(value)")
    }
    
    private func handleStreamEnd() {
        // Stale-stream guard. Only a stream backing a live `.connected` /
        // `.connecting` status is news: `.reconnecting` laps own their own
        // failures (a bouncing half-seated cable must not escalate to the
        // red banner), and `.disconnected` / `.searching` / `.failed` mean a
        // newer flow already tore this stream's connection down — a zombie
        // read task reporting in late must not repaint the UI.
        switch status {
        case .connected, .connecting:
            break
        case .reconnecting, .disconnected, .searching, .failed:
            return
        }
        
        Self.logger?.error("Serial stream ended unexpectedly")
        
        // M7.3 — while a game is on the board, a vanished device begins the
        // auto-reconnect loop instead of the failure banner. Convergence
        // after replug needs no session changes: the fresh board dump flows
        // through settle — matching board → noChange (seamless), moved board
        // → a legal single move commits or recovery takes over, both correct.
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
    
    /// Enters `.reconnecting` and starts the timed retry loop. The target is
    /// the device we were just connected to, read from `status` — which is
    /// `onlyBoardPath` by construction, since nothing else can ever connect.
    private func beginReconnect(to device: DGTSerialDevice) {
        Self.logger?.error("Board vanished mid-game — auto-reconnecting to \(device.path, privacy: .public)")
        sessionLog?.capture(.error, "Board vanished mid-game — auto-reconnecting to \(device.name)")
        
        // Truthful mirror: nothing is detected while unplugged. Direct
        // assignment bypasses `onBoardChanged`, so no spurious settle fires.
        physicalBoard = .empty
        status = .reconnecting(device)
        
        lastReconnectFailureLogged = nil
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            await self?.runReconnectLoop(to: device)
        }
    }
    
    /// One lap every `reconnectRetryInterval`: stand down if the game went
    /// away, attempt when the device path has reappeared, otherwise sleep.
    /// `status` stays `.reconnecting` across failed laps — no red flash every
    /// three seconds — and flips to `.connected` in `handle(_:)` when an
    /// attempt's first dump lands. Cancellation (a manual connect, search,
    /// disconnect, or Stop Trying) is checked after every await so a zombie
    /// lap can't fight a newer flow for the port.
    private func runReconnectLoop(to device: DGTSerialDevice) async {
        while !Task.isCancelled {
            switch DGTAutoConnectPolicy.reconnectLap(
                gameActive: shouldAutoReconnect?() == true,
                targetPath: device.path,
                among: enumerateDevices()
            ) {
            case .stop:
                // Success, discard, or idle are the loop's only exits (plus
                // cancellation) — this is the discard/idle one: quiet, no
                // banner, nothing left to reconnect for.
                Self.logger?.info("Auto-reconnect stopped: no active game")
                sessionLog?.capture(.info, "Auto-reconnect stopped — no active game")
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
                    // Dedupe the present-but-unopenable case (checklist B4):
                    // log the first occurrence and each *distinct* failure, not
                    // one line per 3 s lap. The next attempt's `teardownPort`
                    // still cleans up whatever this lap left behind.
                    if failure != lastReconnectFailureLogged {
                        Self.logger?.error("Reconnect attempt failed: \(failure, privacy: .public)")
                        sessionLog?.capture(.error, "Reconnect attempt failed: \(failure)")
                        lastReconnectFailureLogged = failure
                    }
                }
            }
            
            // The first dump can land during the attempt itself (the init
            // sequence's staggers are suspension points) — don't sleep a full
            // interval on a connection that's already live.
            if isConnected { return }
            try? await Task.sleep(for: reconnectRetryInterval)
            guard !Task.isCancelled else { return }
            if isConnected { return }
        }
    }
    
    /// M7.3 — the player standing the retry loop down (the dialog's "Stop
    /// Trying"). Ends in `.disconnected`, never `.failed`: being asked to
    /// stop is not an error.
    internal func stopReconnecting() async {
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
    
    // (The Remembered Device section (M7.1) lived here until 2 Aug 2026 —
    // `rememberDevice(_:)`, written on the `.connected` transition, read by
    // launch auto-connect. Retired with the device picker: `onlyBoardPath`
    // is a constant, and a constant needs no memory. The stored defaults
    // linger unread, the `rankingsViewMode` stance.)

    // MARK: Session Recording
    
    /// Begins capturing every physical-board change into a `DGTSessionRecording`
    /// for offline replay. A new recording replaces any already in progress; the
    /// current board is captured as the first snapshot.
    internal func startRecording() {
        let recorder = DGTSessionRecorder()
        recorder.record(physicalBoard)
        self.recorder = recorder
        Self.logger?.info("Board session recording started")
        sessionLog?.capture(.info, "Board session recording started")
    }
    
    /// Stops capturing and returns the recording, stamped with the current board
    /// identity, or nil if none was active.
    @discardableResult
    internal func stopRecording() -> DGTSessionRecording? {
        guard let recorder else { return nil }
        recorder.identity = .init(
            serialNumber: boardInfo.serialNumber,
            version: boardInfo.version,
            trademark: boardInfo.trademark
        )
        let recording = recorder.finish()
        self.recorder = nil
        Self.logger?.info("Board session recording stopped: snapshots=\(recording.entries.count)")
        sessionLog?.capture(.info, "Board session recording stopped — \(recording.entries.count) snapshots")
        return recording
    }
    
    // MARK: Failure / Teardown
    
    /// How an open/init failure surfaces (M7.2).
    private enum FailureStyle {
        /// `.failed` plus the five-second linger — user-initiated attempts,
        /// where the player is watching and deserves the explanation.
        case announced
        /// Straight to `.disconnected`, Console/log line only — the launch
        /// auto path, where a board that isn't plugged in is unremarkable.
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
    
    /// Auto-clears a `.failed` status back to `.disconnected` after a delay so
    /// a transient failure doesn't strand the UI in an error state.
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
