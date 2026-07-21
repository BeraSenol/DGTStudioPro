//
//  SleepInhibitor.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 21/07/2026.
//

import Foundation
import Observation
import os

/// M-ux.2 (D14′): holds one `ProcessInfo` activity token while a live game
/// or an active board recording is in progress —
/// `(dgtSession.liveGame != nil) || dgtConnection.isRecording` — preventing
/// *idle system sleep* from dropping the serial link mid-think, plus sudden
/// termination while busy. The union deliberately covers both readings of
/// "recording" (live SAN capture and the M8.3 board-stream recorder), so
/// the trigger needs no disambiguation.
///
/// The deliberate non-goals, recorded with the decision:
/// - **Display sleep is not inhibited.** A game has long think-times with
///   the player away from the Mac; the physical board is truth and the
///   mirror a glance — letting the panel dim is correct, and avoids hours
///   of a static board on-screen.
/// - **Logout/shutdown is not vetoed.** A user-initiated logout proceeds
///   (macOS neither wants nor reliably lets an app veto it); the draft
///   sidecar plus archive-first already make a mid-game logout safe.
///
/// Rejected: raw IOKit `IOPMAssertionCreateWithName` (lower-level, no
/// Swift-native lifecycle, unnecessary once `beginActivity` covers idle
/// sleep + termination) and a permanent assertion (drains power idling at
/// the Library).
///
/// Waived whole, per the register: the predicate is a bare `||` with no
/// branching to extract, and the token is transport. The M10 hardware
/// checklist is the witness (system stays awake across a long think; a
/// recording survives an idle window) — `pmset -g assertions` shows the
/// held activity by its reason string during verification.
@MainActor
internal final class SleepInhibitor {
    
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "power"
    )
    
    /// The one activity token — non-nil exactly while inhibition is held.
    private var token: NSObjectProtocol?
    
    /// Evaluates the predicate under Observation tracking and re-arms on
    /// every change — the standard self-rescheduling
    /// `withObservationTracking` loop. `onChange` fires at *willSet*; the
    /// re-armed pass runs as a queued main-actor task, i.e. after the
    /// mutation completed, so `setInhibited` always reads settled state.
    ///
    /// Strong captures, deliberately: `onChange` is `@Sendable`, and a
    /// `weak` capture is a mutable binding — Swift 6 rejects referencing
    /// captured vars from concurrently-executing code (that exact
    /// diagnostic). Strong `let` captures are legal because all three
    /// types are `@MainActor` classes, hence implicitly `Sendable`; and
    /// they cost nothing: the observation registrar holds this closure —
    /// not `self` — so there is no cycle, and the App owns all three
    /// objects for the process lifetime anyway, so the pending closure
    /// extends no lifetime in practice.
    internal func observe(session: DGTLiveSession, connection: DGTConnection) {
        withObservationTracking {
            setInhibited(session.liveGame != nil || connection.isRecording)
        } onChange: {
            Task { @MainActor in
                self.observe(session: session, connection: connection)
            }
        }
    }
    
    /// Idempotent on the edges: begin only on false→true, end only on
    /// true→false — re-evaluations of an unchanged predicate are no-ops,
    /// so the loop can re-run freely.
    private func setInhibited(_ inhibited: Bool) {
        if inhibited, token == nil {
            token = ProcessInfo.processInfo.beginActivity(
                options: [.idleSystemSleepDisabled, .automaticTerminationDisabled],
                reason: "Live chess game or board recording in progress"
            )
            Self.logger.info("Idle-sleep inhibition began")
        } else if !inhibited, let token {
            ProcessInfo.processInfo.endActivity(token)
            self.token = nil
            Self.logger.info("Idle-sleep inhibition ended")
        }
    }
}
