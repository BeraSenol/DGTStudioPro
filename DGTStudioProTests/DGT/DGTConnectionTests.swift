//
//  DGTConnectionTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 16/07/2026.
//

import Testing
import Foundation
@testable import DGTStudioPro

/// Hermetic coverage for `DGTConnection` — the class had zero automated
/// tests because every seam was hard-bound to hardware (F9). Three
/// injected seams make it testable without a board:
///
/// - `port` (a `DGTPortProviding` fake) scripts the event stream, records
///   sent commands, and can end the stream *without* `close()` — which is
///   exactly what a yanked USB cable looks like from the connection's side
///   (F1: the real port closes itself on EOF and finishes the stream; the
///   stream finishing is the contract, so the fake finishes the stream).
/// - `enumerateDevices` scripts discovery, so the reconnect lap's "is it
///   back yet?" probe is deterministic instead of walking the dev
///   machine's real IORegistry.
/// - `defaults` gets a throwaway suite, so `rememberDevice` never writes
///   the developer's real preferences from the ⌘U host.
///
/// Together with zeroed `initCommandStagger` and a milliseconds
/// `reconnectRetryInterval`, the full unplug → reconnect loop runs in
/// hundredths of a second. What these tests *can't* prove — termios
/// configuration, EOF detection on a real fd — stays on the M7 hardware
/// checklist, deliberately.
@MainActor
@Suite("DGT Connection — Fake Port")
struct DGTConnectionTests {

    // MARK: Fake Port

    /// Scripted `DGTPortProviding`. `emit` yields events in call order;
    /// `vanish` finishes the stream without `close()`, simulating the
    /// device disappearing out from under an open port. With `setAutoDump`,
    /// the fake answers `.sendBoard` with a full dump — the one real-board
    /// behavior the reconnect loop's convergence leans on (each attempt
    /// lap re-runs the init sequence, so each lap re-solicits the dump).
    private actor FakePort: DGTPortProviding {
        private(set) var openedPaths: [String] = []
        private(set) var sentCommands: [DGTCommand] = []
        private(set) var closeCount = 0
        private var continuation: AsyncStream<DGTEvent>.Continuation?
        private var failNextOpen = false
        private var autoDumpPosition: Position?

        struct OpenFailure: Error {}

        func open(path: String) throws -> AsyncStream<DGTEvent> {
            openedPaths.append(path)
            if failNextOpen {
                failNextOpen = false
                throw OpenFailure()
            }
            let (stream, continuation) = AsyncStream.makeStream(of: DGTEvent.self)
            self.continuation = continuation
            return stream
        }

        func close() {
            closeCount += 1
            continuation?.finish()
            continuation = nil
        }

        func send(_ command: DGTCommand) throws {
            sentCommands.append(command)
            // The real board answers `sendBoard` with a dump. Tests that
            // exercise loops (where the *connection*, not the test, decides
            // when a port reopens) need this fidelity: a manually emitted
            // dump races the lap cadence — a retry can tear the port down
            // between the test observing the open and the emit landing.
            if command == .sendBoard, let autoDumpPosition {
                continuation?.yield(.boardDump(autoDumpPosition))
            }
        }

        // Test drivers

        func emit(_ event: DGTEvent) {
            continuation?.yield(event)
        }

        /// The unplug: the stream ends, but nobody called `close()`.
        func vanish() {
            continuation?.finish()
            continuation = nil
        }

        func setFailNextOpen() {
            failNextOpen = true
        }

        /// From now on, `.sendBoard` is answered with a dump of `position`.
        func setAutoDump(_ position: Position?) {
            autoDumpPosition = position
        }
    }

    // MARK: Helpers

    private static let device = DGTSerialDevice(path: "/dev/cu.fake", name: "Fake Board")

    /// A connection wired to a fresh fake port, zero command stagger,
    /// millisecond reconnect laps, and a throwaway defaults suite.
    private func makeConnection(port: FakePort) -> DGTConnection {
        let connection = DGTConnection(port: port)
        connection.initCommandStagger = .zero
        connection.reconnectRetryInterval = .milliseconds(20)
        let suite = "DGTConnectionTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        connection.defaults = defaults
        return connection
    }

    /// Polls `condition` until it holds or `timeout` elapses. The async
    /// condition lets tests read the fake port actor inside the predicate.
    /// 5 s / 25 ms matches the session suites' load calibration: under a
    /// full ⌘U the main actor is contended enough that shorter ceilings
    /// miss (see `DGTLiveSessionTests.poll`).
    private func poll(
        timeout: Duration = .seconds(5),
        until condition: () async -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(await condition(), "Timed out after \(timeout) waiting for condition")
    }

    // MARK: Connect Flow

    /// The happy path: `connect` opens the port, runs the init sequence,
    /// and the first board dump flips the status to connected and paints
    /// the mirror.
    @Test func connectFlipsToConnectedOnTheFirstDump() async throws {
        let port = FakePort()
        let connection = makeConnection(port: port)

        await connection.connect(to: Self.device)
        #expect(await port.openedPaths == ["/dev/cu.fake"])
        // The init sequence went out: reset first, then the dump request
        // and update-mode subscription among the follow-ups.
        let sent = await port.sentCommands
        #expect(sent.first == .sendReset)
        #expect(sent.contains(.sendBoard))
        #expect(sent.contains(.sendUpdateBoard))
        // Still only connecting — no dump yet.
        #expect(connection.isConnected == false)

        await port.emit(.boardDump(.starting))
        try await poll { connection.isConnected }

        #expect(connection.physicalBoard == .starting)
    }

    /// Field updates flow through to `physicalBoard` and `onBoardChanged`
    /// in emission order — the connection-level half of the F2 ordering
    /// fix (the handler-queue half lives in `DGTSerialPort`'s pipeline
    /// design and on the hardware checklist).
    @Test func fieldUpdatesFlowToTheBoardHookInOrder() async throws {
        let port = FakePort()
        let connection = makeConnection(port: port)
        var observed: [Position] = []
        connection.onBoardChanged = { observed.append($0) }

        await connection.connect(to: Self.device)
        await port.emit(.boardDump(.starting))
        // A physical 1.e4: lift off e2, place on e4.
        await port.emit(.fieldUpdate(square: Squares.e2, piece: .empty))
        await port.emit(.fieldUpdate(square: Squares.e4, piece: .whitePawn))
        try await poll { observed.count == 3 }

        #expect(observed[0] == .starting)
        #expect(observed[1][Squares.e2] == .empty)
        #expect(observed[1][Squares.e4] == .empty)     // lift seen before place
        #expect(observed[2][Squares.e4] == .whitePawn)
        #expect(connection.physicalBoard == observed[2])
    }

    /// A failed `open` surfaces as a failed status, not a hang.
    @Test func openFailureShowsAFailedStatus() async throws {
        let port = FakePort()
        await port.setFailNextOpen()
        let connection = makeConnection(port: port)

        await connection.connect(to: Self.device)

        guard case .failed = connection.status else {
            Issue.record("Expected .failed, got \(connection.status)")
            return
        }
    }

    // MARK: Stream End Routing (F1 consumer side)

    /// Unplug with no game active: `shouldAutoReconnect` is unwired, so the
    /// stream ending routes to the failure banner and clears the mirror —
    /// stale squares must not masquerade as a live board.
    @Test func streamEndWithoutAGameShowsFailureAndClearsTheMirror() async throws {
        let port = FakePort()
        let connection = makeConnection(port: port)
        await connection.connect(to: Self.device)
        await port.emit(.boardDump(.starting))
        try await poll { connection.isConnected }

        await port.vanish()
        try await poll {
            if case .failed = connection.status { return true }
            return false
        }

        #expect(connection.physicalBoard == .empty)
    }

    /// Unplug mid-game: `shouldAutoReconnect` says yes, so the stream
    /// ending routes into the M7.3 reconnect loop instead of the banner.
    /// With discovery scripted to "not back yet", the loop parks in
    /// `.reconnecting`; `stopReconnecting()` stands it down.
    @Test func streamEndWithAGameBeginsReconnectingAndStopStandsDown() async throws {
        let port = FakePort()
        let connection = makeConnection(port: port)
        connection.shouldAutoReconnect = { true }
        connection.enumerateDevices = { [] }
        await connection.connect(to: Self.device)
        await port.emit(.boardDump(.starting))
        try await poll { connection.isConnected }

        await port.vanish()
        try await poll { connection.isReconnecting }
        #expect(connection.physicalBoard == .empty)

        await connection.stopReconnecting()
        #expect(connection.status == .disconnected)
    }

    /// The loop stands itself down when the game goes away between laps —
    /// the policy's `.stop` verdict path.
    @Test func reconnectLoopStopsWhenTheGameGoesAway() async throws {
        let port = FakePort()
        let connection = makeConnection(port: port)
        var gameActive = true
        connection.shouldAutoReconnect = { gameActive }
        connection.enumerateDevices = { [] }
        await connection.connect(to: Self.device)
        await port.emit(.boardDump(.starting))
        try await poll { connection.isConnected }

        await port.vanish()
        try await poll { connection.isReconnecting }

        gameActive = false
        try await poll { connection.status == .disconnected }
    }

    /// The full M7.3 round trip: unplug mid-game, the loop parks, the
    /// device "returns" via scripted discovery, the next attempt lap
    /// reopens the port, and the lap's own init sequence re-solicits the
    /// dump that completes the reconnect.
    ///
    /// The fake answers `.sendBoard` with a dump (`setAutoDump`) because
    /// that is the contract the loop's convergence leans on. An earlier
    /// version emitted the dump manually after polling for the reopen —
    /// which raced the lap cadence: a 20 ms retry lap could tear down the
    /// just-observed port before the 25 ms poll's emit landed, so the dump
    /// died with the old stream and `openedPaths` sailed past the exact
    /// `== 2` check. With the fake speaking the device's half of the
    /// protocol, every lap converges on its own, no matter how the
    /// scheduler interleaves them.
    @Test func reconnectSucceedsWhenTheDeviceReturns() async throws {
        let port = FakePort()
        let connection = makeConnection(port: port)
        var available: [DGTSerialDevice] = []
        connection.shouldAutoReconnect = { true }
        connection.enumerateDevices = { available }
        await port.setAutoDump(.starting)   // the board answers sendBoard with a dump
        await connection.connect(to: Self.device)
        try await poll { connection.isConnected }

        await port.vanish()
        try await poll { connection.isReconnecting }

        available = [Self.device]           // it's back
        try await poll { connection.isConnected }

        #expect(connection.physicalBoard == .starting)
        // Usually exactly one reopen; a second lap under heavy scheduler
        // load is legitimate loop behavior (each lap re-solicits the dump),
        // so assert the floor rather than the exact count.
        #expect(await port.openedPaths.count >= 2)
    }

    /// A deliberate `disconnect()` must not be mistaken for an unplug:
    /// teardown cancels the read task before closing, so the stream's end
    /// is consumed silently and the status stays put.
    @Test func deliberateDisconnectDoesNotRouteToStreamEndHandling() async throws {
        let port = FakePort()
        let connection = makeConnection(port: port)
        connection.shouldAutoReconnect = { true }       // would reconnect if misrouted
        connection.enumerateDevices = { [] }
        await connection.connect(to: Self.device)
        await port.emit(.boardDump(.starting))
        try await poll { connection.isConnected }

        await connection.disconnect()

        #expect(connection.status == .disconnected)
        // Give any misrouted stream-end handling a beat to appear…
        try await Task.sleep(for: .milliseconds(100))
        #expect(connection.status == .disconnected)
        #expect(connection.isReconnecting == false)
    }
}
