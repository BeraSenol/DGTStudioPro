//
//  DGTAutoConnectPolicyTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 07/07/2026.
//

import Testing
@testable import DGTStudioPro

/// Coverage for `DGTAutoConnectPolicy` — the pure half of the connection
/// quality of life, pinned without hardware. Rewritten 2 Aug 2026 with the
/// one-board decree: the remembered-device cases died with the device
/// picker. The two contracts worth guarding now:
///
///   1. Only the exact `boardPath` ever wins — `isLikelyBoard` and every
///      other attached device are never consulted, which is no longer a
///      nuance but the entire feature.
///   2. `stop` outranks `attempt` in the reconnect lap — a discarded game
///      ends the loop even in the same lap the device came back.
///
/// Not `@MainActor`: the type is a stateless namespace over `Sendable`
/// values, matching every other pure-value suite in the module.
@Suite("DGT Auto-Connect Policy")
struct DGTAutoConnectPolicyTests {

    // MARK: Fixtures

    /// The board, on the production path (`DGTConnection.onlyBoardPath`) —
    /// asserted below so the fixture can't drift from the constant it
    /// stands in for.
    private let board = DGTSerialDevice(
        path: DGTConnection.onlyBoardPath,
        name: "usbmodem01"
    )

    /// Some other attached serial device — likely-looking on purpose.
    private let stranger = DGTSerialDevice(
        path: "/dev/cu.usbserial-DGT01",
        name: "usbserial-DGT01"
    )

    @Test func fixtureMatchesTheProductionConstant() {
        #expect(board.path == "/dev/cu.usbmodem01")
    }

    // MARK: Launch Target (M7.2, one-board form)

    /// The happy path: enabled + attached → connect to it.
    @Test func launchConnectsWhenTheBoardIsAttached() {
        let target = DGTAutoConnectPolicy.launchTarget(
            enabled: true,
            boardPath: board.path,
            among: [stranger, board]
        )
        #expect(target == board)
    }

    /// The Settings toggle wins over everything else.
    @Test func launchDoesNothingWhenDisabled() {
        let target = DGTAutoConnectPolicy.launchTarget(
            enabled: false,
            boardPath: board.path,
            among: [board]
        )
        #expect(target == nil)
    }

    /// The board absent produces no attempt at all — no matter what else
    /// is attached, however board-like it looks (contract 1).
    @Test func launchNeverSettlesForAnotherDevice() {
        let target = DGTAutoConnectPolicy.launchTarget(
            enabled: true,
            boardPath: board.path,
            among: [stranger]
        )
        #expect(target == nil)
    }

    /// Matching is by `path` — the stable identity — so a device whose
    /// display name drifted between sessions is still recognized.
    @Test func launchMatchesByPathNotName() {
        let renamed = DGTSerialDevice(path: board.path, name: "renamed-by-driver")
        let target = DGTAutoConnectPolicy.launchTarget(
            enabled: true,
            boardPath: board.path,
            among: [renamed]
        )
        #expect(target == renamed)
    }

    // MARK: Reconnect Lap (M7.3)

    /// Device absent, game still running → keep waiting.
    @Test func lapWaitsWhileDeviceIsAbsent() {
        #expect(DGTAutoConnectPolicy.reconnectLap(
            gameActive: true, targetPath: board.path, among: []
        ) == .wait)
        #expect(DGTAutoConnectPolicy.reconnectLap(
            gameActive: true, targetPath: board.path, among: [stranger]
        ) == .wait)
    }

    /// Device back, game still running → attempt.
    @Test func lapAttemptsWhenDeviceReappears() {
        let lap = DGTAutoConnectPolicy.reconnectLap(
            gameActive: true,
            targetPath: board.path,
            among: [stranger, board]
        )
        #expect(lap == .attempt)
    }

    /// Game gone, device absent → stand down.
    @Test func lapStopsWhenNoGameIsActive() {
        let lap = DGTAutoConnectPolicy.reconnectLap(
            gameActive: false,
            targetPath: board.path,
            among: []
        )
        #expect(lap == .stop)
    }

    /// Contract 2: `stop` outranks `attempt` — the game being discarded
    /// ends the loop even in the very lap the device came back.
    @Test func stopOutranksAttempt() {
        let lap = DGTAutoConnectPolicy.reconnectLap(
            gameActive: false,
            targetPath: board.path,
            among: [board]
        )
        #expect(lap == .stop)
    }
}
