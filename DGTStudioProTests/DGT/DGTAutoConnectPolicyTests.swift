//
//  DGTAutoConnectPolicyTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 07/07/2026.
//

import Testing
@testable import DGTStudioPro

/// Coverage for `DGTAutoConnectPolicy` — the pure half of M7's connection
/// quality of life, extracted from `DGTConnection` precisely so these
/// decisions can be pinned without hardware. The two contracts worth
/// guarding:
///
///   1. `isLikelyBoard` is sort-only, **never** auto-connect criteria — a
///      remembered device wins on its path even when it doesn't look like
///      a board, and a likely-looking stranger never wins (Decision #7's
///      confirm-before-connect contract).
///   2. `stop` outranks `attempt` in the reconnect lap — a discarded game
///      ends the loop even in the same lap the device came back.
///
/// Not `@MainActor`: the type is a stateless namespace over `Sendable`
/// values, matching every other pure-value suite in the module.
@Suite("DGT Auto-Connect Policy")
struct DGTAutoConnectPolicyTests {
    
    // MARK: Fixtures
    
    /// A remembered board on a likely-looking path.
    private let board = DGTSerialDevice(
        path: "/dev/cu.usbserial-DGT01",
        name: "usbserial-DGT01"
    )
    
    /// Some other attached serial device (also likely-looking — irrelevant).
    private let other = DGTSerialDevice(
        path: "/dev/cu.usbmodem-ARDUINO1",
        name: "usbmodem-ARDUINO1"
    )
    
    // MARK: Launch Target (M7.2)
    
    /// The happy path: enabled + remembered + attached → connect to it.
    @Test func launchConnectsToRememberedDeviceWhenAttached() {
        let target = DGTAutoConnectPolicy.launchTarget(
            enabled: true,
            rememberedPath: board.path,
            among: [other, board]
        )
        #expect(target == board)
    }
    
    /// The Settings toggle wins over everything else.
    @Test func launchDoesNothingWhenDisabled() {
        let target = DGTAutoConnectPolicy.launchTarget(
            enabled: false,
            rememberedPath: board.path,
            among: [board]
        )
        #expect(target == nil)
    }
    
    /// No remembered device — nil or empty — means no launch connect, no
    /// matter what is attached. First run behaves exactly like pre-M7.
    @Test func launchDoesNothingWithoutARememberedDevice() {
        #expect(DGTAutoConnectPolicy.launchTarget(
            enabled: true, rememberedPath: nil, among: [board]
        ) == nil)
        #expect(DGTAutoConnectPolicy.launchTarget(
            enabled: true, rememberedPath: "", among: [board]
        ) == nil)
    }
    
    /// A remembered board that isn't plugged in produces no attempt at all
    /// (quieter even than the quiet-failure path — nothing is opened).
    @Test func launchDoesNothingWhenRememberedDeviceIsAbsent() {
        let target = DGTAutoConnectPolicy.launchTarget(
            enabled: true,
            rememberedPath: board.path,
            among: [other]
        )
        #expect(target == nil)
    }
    
    /// Matching is by `path` — the stable identity — so a device whose
    /// display name drifted between sessions is still recognized.
    @Test func launchMatchesByPathNotName() {
        let renamed = DGTSerialDevice(path: board.path, name: "renamed-by-driver")
        let target = DGTAutoConnectPolicy.launchTarget(
            enabled: true,
            rememberedPath: board.path,
            among: [renamed]
        )
        #expect(target == renamed)
    }
    
    /// Contract 1: `isLikelyBoard` is never consulted. A remembered device
    /// that doesn't look like a board still wins over an attached device
    /// that does.
    @Test func launchIgnoresIsLikelyBoardEntirely() {
        let unlikelyButRemembered = DGTSerialDevice(
            path: "/dev/cu.PL2303-0001",
            name: "PL2303-0001"
        )
        // Fixture sanity: the heuristic really would have sorted this last.
        #expect(unlikelyButRemembered.isLikelyBoard == false)
        
        let target = DGTAutoConnectPolicy.launchTarget(
            enabled: true,
            rememberedPath: unlikelyButRemembered.path,
            among: [board, unlikelyButRemembered]  // `board` looks likelier
        )
        #expect(target == unlikelyButRemembered)
    }
    
    // MARK: Reconnect Lap (M7.3)
    
    /// Device absent, game still running → keep waiting.
    @Test func lapWaitsWhileDeviceIsAbsent() {
        #expect(DGTAutoConnectPolicy.reconnectLap(
            gameActive: true, targetPath: board.path, among: []
        ) == .wait)
        #expect(DGTAutoConnectPolicy.reconnectLap(
            gameActive: true, targetPath: board.path, among: [other]
        ) == .wait)
    }
    
    /// Device back, game still running → attempt.
    @Test func lapAttemptsWhenDeviceReappears() {
        let lap = DGTAutoConnectPolicy.reconnectLap(
            gameActive: true,
            targetPath: board.path,
            among: [other, board]
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
