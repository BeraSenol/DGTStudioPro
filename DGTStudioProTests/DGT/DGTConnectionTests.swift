import Testing
import Foundation
@testable import DGTStudioPro

/// Hermetic `DGTConnection` coverage via three injected seams (F9): scripted port, scripted
/// discovery, throwaway defaults. What these cannot prove - termios, EOF on a real fd - stays
/// on the hardware checklist.
@MainActor
@Suite("DGT Connection - Fake Port")
struct DGTConnectionTests {

    // MARK: Fake Port

    /// Scripted port: `emit` yields in order; `vanish` finishes the stream without `close()` -
    /// the device disappearing under an open port.
    private actor FakePort: DGTPortProviding {
        private(set) var openedPaths: [String] = []
        private(set) var sentCommands: [DGTCommand] = []
        private(set) var closeCount = 0
        /// Whether a port is *currently* held - the semantic question a close count can't answer,
        /// since `connect` closes once on entry before it opens anything.
        private(set) var isOpen = false
        private var continuation: AsyncStream<DGTEvent>.Continuation?
        private var failNextOpen = false
        private var failSends = false
        private var autoDumpPosition: Position?

        struct OpenFailure: Error {}
        struct SendFailure: Error {}

        func open(path: String) throws -> AsyncStream<DGTEvent> {
            openedPaths.append(path)
            if failNextOpen {
                failNextOpen = false
                throw OpenFailure()
            }
            let (stream, continuation) = AsyncStream.makeStream(of: DGTEvent.self)
            self.continuation = continuation
            isOpen = true
            return stream
        }

        func close() {
            closeCount += 1
            isOpen = false
            continuation?.finish()
            continuation = nil
        }

        func send(_ command: DGTCommand) throws {
            sentCommands.append(command)
            if failSends { throw SendFailure() }
            // The real board answers `sendBoard` with a dump - loop tests need that fidelity.
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

        /// Every `send` throws from now on - the init sequence failing *after* a successful open.
        func setFailSends() {
            failSends = true
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

    /// Polls until the condition holds; async predicate so tests can read the fake port actor.
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
        // Still only connecting - no dump yet.
        #expect(connection.isConnected == false)

        await port.emit(.boardDump(.starting))
        try await poll { connection.isConnected }

        #expect(connection.physicalBoard == .starting)
    }

    /// Field updates flow through to `physicalBoard` and `onBoardChanged`
    /// in emission order - the connection-level half of the F2 ordering
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
        let held = await port.isOpen
        #expect(held == false)
    }

    /// The other failure: `open` succeeded and an init command threw. `fail` is synchronous and
    /// cannot close, so `connect` owes the teardown - otherwise the port stays held under
    /// `.failed`, its read loop still publishing board changes to a session that thinks it is
    /// disconnected, and nothing reclaims the device until the next connect.
    @Test func initFailureClosesThePortItOpened() async throws {
        let port = FakePort()
        await port.setFailSends()
        let connection = makeConnection(port: port)

        await connection.connect(to: Self.device)

        guard case .failed = connection.status else {
            Issue.record("Expected .failed, got \(connection.status)")
            return
        }
        let opened = await port.openedPaths
        let held = await port.isOpen
        #expect(opened == [Self.device.path], "the port must have opened first")
        #expect(held == false, "an opened port must not survive an init failure")
    }

    /// The third derived status flag. Varying one input: the dump moves `isConnecting` false and
    /// `isConnected` true together, so neither can be reading the other's case.
    @Test func isConnectingHoldsBetweenTheOpenAndTheFirstDump() async throws {
        let port = FakePort()
        let connection = makeConnection(port: port)
        #expect(connection.isConnecting == false)

        await connection.connect(to: Self.device)
        #expect(connection.isConnecting == true)
        #expect(connection.isConnected == false)

        await port.emit(.boardDump(.starting))
        try await poll { connection.isConnected }
        #expect(connection.isConnecting == false)
    }

    // MARK: Stream End Routing (F1 consumer side)

    /// Unplug with no game active: `shouldAutoReconnect` is unwired, so the
    /// stream ending routes to the failure banner and clears the mirror -
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

    /// The loop stands itself down when the game goes away between laps -
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

    /// The full M7.3 round trip: unplug mid-game, loop parks, device returns via scripted
    /// discovery, the lap reopens and re-solicits the dump.
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

    // MARK: Board Identity Tag (M2)

    /// `BoardInfo.identityTag` composes the `[Board "…"]` value the DGT
    /// reference exports carry: "DGT " + long serial ("DGT 3000448278"),
    /// short serial as fallback, nil when the handshake reported neither.
    /// On the value type precisely so this pins without a port.
    @Test func identityTagPrefersLongSerialAndFallsBack() {
        var info = DGTConnection.BoardInfo()
        #expect(info.identityTag == nil)

        info.serialNumber = "12345"
        #expect(info.identityTag == "DGT 12345")

        info.longSerialNumber = "3000448278"
        #expect(info.identityTag == "DGT 3000448278")
    }
}
