//
//  DGTConnection.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 25/05/2026.
//

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
    
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "dgt"
    )
    
    // MARK: Status
    
    internal enum Status: Equatable {
        case disconnected
        case searching
        case connecting(DGTSerialDevice)
        case connected(DGTSerialDevice)
        case failed(String)
    }
    
    /// Identifying strings the board reports during the init handshake.
    internal struct BoardInfo: Equatable, Sendable {
        internal var serialNumber: String?
        internal var longSerialNumber: String?
        internal var trademark: String?
        internal var version: String?
        internal var hardwareVersion: String?
    }
    
    // MARK: Observable State
    
    private(set) internal var status: Status = .disconnected
    private(set) internal var availableDevices: [DGTSerialDevice] = []
    private(set) internal var boardInfo = BoardInfo()
    
    /// Live snapshot of the pieces the board currently detects, in app
    /// coordinates. Updated wholesale by board dumps and per-square by field
    /// updates. This is what D3's mirror view renders.
    private(set) internal var physicalBoard: Position = .empty
    
    internal var isConnected: Bool {
        if case .connected = status { return true }
        return false
    }
    
    // MARK: Diagnostics
    
    /// Optional exportable diagnostic timeline, shared with `DGTLiveSession`.
    /// Wired by the app (`connection.sessionLog = log`); nil-safe.
    @ObservationIgnored internal var sessionLog: DGTSessionLog?
    
    /// Opt-in capture of the live board stream for offline replay/regression
    /// (see `DGTSessionRecording`). Nil unless `startRecording()` is active;
    /// diagnostic only, kept out of observation.
    @ObservationIgnored private var recorder: DGTSessionRecorder?
    
    internal var isRecording: Bool { recorder != nil }
    
    // MARK: Private State
    
    @ObservationIgnored private let port = DGTSerialPort()
    
    /// Called after every physical-board change (dump or field update) with the
    /// new board. `DGTLiveSession` sets this to drive its quiescence timer and
    /// move reconstruction. Kept out of observation — it's a wiring hook, not
    /// UI state.
    @ObservationIgnored internal var onBoardChanged: ((Position) -> Void)?
    @ObservationIgnored private var readTask: Task<Void, Never>?
    @ObservationIgnored private var errorClearTask: Task<Void, Never>?
    
    /// Spacing between init commands so a board with a shallow input buffer
    /// isn't overrun, and so the log clearly attributes each response.
    @ObservationIgnored private let initCommandStagger: Duration = .milliseconds(75)
    
    /// How long a `.failed` status lingers before auto-clearing to
    /// `.disconnected`.
    @ObservationIgnored private let errorLingerDuration: Duration = .seconds(5)
    
    internal init() {}
    
    // MARK: Discovery
    
    /// Enumerates attached serial devices for the connect dialog. Synchronous
    /// and cheap; the "progress bar while searching" UX is the dialog's, since
    /// IOKit enumeration returns immediately.
    internal func search() {
        cancelErrorClear()
        status = .searching
        availableDevices = DGTDeviceDiscovery.availableDevices()
        Self.logger.info("search() found \(self.availableDevices.count) device(s)")
        sessionLog?.capture(.debug, "search: \(availableDevices.count) device(s)")
    }
    
    // MARK: Connect / Disconnect
    
    /// Opens `device`, begins consuming events, and runs the init sequence.
    /// Status advances to `.connected` once the board's first dump arrives.
    internal func connect(to device: DGTSerialDevice) async {
        cancelErrorClear()
        await teardownPort()
        
        status = .connecting(device)
        boardInfo = BoardInfo()
        physicalBoard = .empty
        Self.logger.info("Connecting to \(device.path, privacy: .public)")
        sessionLog?.capture(.info, "Connecting to \(device.name) [\(device.path)]")
        
        let events: AsyncStream<DGTEvent>
        do {
            events = try await port.open(path: device.path)
        } catch {
            fail("Could not open \(device.name): \(error)")
            return
        }
        
        readTask = Task { [weak self] in
            for await event in events {
                self?.handle(event)
            }
            // The loop ends either because we closed the port (the task is
            // cancelled during teardown) or because the device vanished
            // mid-session. Only the latter is a failure.
            if !Task.isCancelled {
                self?.handleStreamEnd()
            }
        }
        
        await runInitSequence()
    }
    
    /// Disconnects and resets to `.disconnected`.
    internal func disconnect() async {
        Self.logger.info("Disconnecting")
        sessionLog?.capture(.info, "Disconnecting")
        await teardownPort()
        status = .disconnected
        physicalBoard = .empty
    }
    
    // MARK: Init Sequence
    
    /// Sends the DGT-prescribed startup commands, staggered. Reset comes first
    /// (it stops any prior update streaming); update-board comes last (it
    /// starts field-update streaming). Responses arrive asynchronously via the
    /// event stream.
    private func runInitSequence() async {
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
            do {
                try await port.send(command)
            } catch {
                fail("Init command 0x\(String(command.rawValue, radix: 16)) failed: \(error)")
                return
            }
            try? await Task.sleep(for: initCommandStagger)
        }
        Self.logger.info("Init sequence sent")
        sessionLog?.capture(.debug, "Init sequence sent")
    }
    
    // MARK: Event Handling
    
    private func handle(_ event: DGTEvent) {
        switch event {
        case .boardDump(let position):
            physicalBoard = position
            onBoardChanged?(position)
            recorder?.record(position)
            // First dump confirms a live, talking board.
            if case .connecting(let device) = status {
                status = .connected(device)
                Self.logger.info("Connected: first board dump received")
                sessionLog?.capture(.info, "Connected: first board dump received from \(device.name)")
            }
            
        case .fieldUpdate(let square, let piece):
            physicalBoard[square] = piece
            onBoardChanged?(physicalBoard)
            recorder?.record(physicalBoard)
            
        case .serialNumber(let value):
            boardInfo.serialNumber = value
            Self.logger.info("Board serial: \(value, privacy: .public)")
            sessionLog?.capture(.debug, "Board serial: \(value)")
            
        case .longSerialNumber(let value):
            boardInfo.longSerialNumber = value
            Self.logger.info("Board long serial: \(value, privacy: .public)")
            sessionLog?.capture(.debug, "Board long serial: \(value)")
            
        case .trademark(let value):
            boardInfo.trademark = value
            Self.logger.info("Board trademark: \(value, privacy: .public)")
            sessionLog?.capture(.debug, "Board trademark: \(value)")
            
        case .version(let major, let minor):
            boardInfo.version = "\(major).\(minor)"
            Self.logger.info("Board version: \(major).\(minor, privacy: .public)")
            sessionLog?.capture(.debug, "Board version: \(major).\(minor)")
            
        case .hardwareVersion(let major, let minor):
            boardInfo.hardwareVersion = "\(major).\(minor)"
            Self.logger.info("Board hardware version: \(major).\(minor, privacy: .public)")
            sessionLog?.capture(.debug, "Board hardware version: \(major).\(minor)")
        }
    }
    
    private func handleStreamEnd() {
        Self.logger.error("Serial stream ended unexpectedly")
        fail("The board was disconnected.")
    }
    
    // MARK: Session Recording
    
    /// Begins capturing every physical-board change into a `DGTSessionRecording`
    /// for offline replay. A new recording replaces any already in progress; the
    /// current board is captured as the first snapshot.
    internal func startRecording() {
        let recorder = DGTSessionRecorder()
        recorder.record(physicalBoard)
        self.recorder = recorder
        Self.logger.info("Board session recording started")
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
        Self.logger.info("Board session recording stopped (\(recording.entries.count) snapshots)")
        sessionLog?.capture(.info, "Board session recording stopped — \(recording.entries.count) snapshots")
        return recording
    }
    
    // MARK: Failure / Teardown
    
    private func fail(_ message: String) {
        Self.logger.error("\(message, privacy: .public)")
        sessionLog?.capture(.error, "Connection failure: \(message)")
        status = .failed(message)
        physicalBoard = .empty
        scheduleErrorClear()
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
