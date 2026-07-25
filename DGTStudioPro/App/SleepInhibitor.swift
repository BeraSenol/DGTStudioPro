//
//  SleepInhibitor.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 21/07/2026.
//

import Foundation
import Observation
import os

/// Owns exactly one `ProcessInfo` activity for its own lifetime, so the
/// begin/end pairing is a fact about object graph shape rather than two
/// call sites that must agree. Releasing is `token = nil`; a teardown that
/// forgets to end the activity is not expressible.
private final class ActivityToken {

    private let token: NSObjectProtocol

    fileprivate init(reason: String) {
        // `.userInitiated` is the named composite for exactly this
        // situation — idle *system* sleep disabled, plus sudden and
        // automatic termination disabled. It deliberately does NOT include
        // `.idleDisplaySleepDisabled` (a separate, far higher bit), so
        // D14′'s "let the panel dim" non-goal is preserved by construction:
        // breaking it would require naming a second option, not editing a
        // comment. Rejected: the hand-assembled
        // `[.idleSystemSleepDisabled, .automaticTerminationDisabled]` this
        // replaces — it omitted `SuddenTerminationDisabled`, which the
        // decision's prose claimed it had.
        token = ProcessInfo.processInfo.beginActivity(
            options: .userInitiated,
            reason: reason
        )
    }

    deinit { ProcessInfo.processInfo.endActivity(token) }
}

/// M-ux.2 (D14′, gated by D25′): holds one `ProcessInfo` activity while a
/// live game or an active board recording is in progress *and* the user
/// hasn't opted out — `isEnabled && (liveGame != nil || isRecording)` —
/// preventing idle system sleep from dropping the serial link mid-think.
/// The `||` deliberately covers both readings of "recording" (live SAN
/// capture and the M8.3 board-stream recorder), so the trigger needs no
/// disambiguation.
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
/// D25′ — the preference is an observable property *here*, not an
/// `@AppStorage` read: the gate has to participate in the tracking loop so
/// that switching it off mid-game releases the assertion on that edge
/// rather than on the next unrelated change. Settings binds to this same
/// property, so the "absent reads as true" default lives exactly once (the
/// initializer) — the first preference in the app with no twin read site.
/// Rejected: KVO or `UserDefaults.didChangeNotification` (machinery to
/// re-derive what Observation already does).
///
/// Rejected for the token itself: raw IOKit `IOPMAssertionCreateWithName`
/// (lower-level, no Swift-native lifecycle) and a permanent assertion
/// (drains power idling at the Library).
///
/// Waived in part, per the register: the token is transport and the
/// predicate is a bare `&&`/`||` with nothing to extract. The preference's
/// default and persistence are *not* waived — `SleepInhibitorPreferenceTests`
/// pins them. The hardware checklist remains the witness for inhibition
/// itself; `pmset -g assertions` shows the held activity by its reason.
@MainActor
@Observable
internal final class SleepInhibitor {

    // MARK: Static Constants
    @ObservationIgnored
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "power"
    )

    @ObservationIgnored
    private static let activityReason = "Live chess game or board recording in progress"

    // MARK: Preference

    /// The user gate. Observed, so Settings flipping it re-arms the loop
    /// below on the same turn; persisted on write, so the `?? true` in
    /// `init` is the only place the default is stated.
    internal var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: StorageKeys.preventSleepDuringPlay)
            Self.logger.info(
                "Sleep inhibition preference: \(self.isEnabled ? "on" : "off", privacy: .public)"
            )
        }
    }

    // MARK: Private Properties
    @ObservationIgnored private let defaults: UserDefaults

    /// Non-nil exactly while inhibition is held.
    @ObservationIgnored private var token: ActivityToken?

    // MARK: Init

    /// `defaults` is injectable so the preference contract can be pinned
    /// against a scratch suite without touching the developer's own
    /// settings.
    internal init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Absent reads as **true** — the `autoConnectOnLaunch` semantics,
        // preserving D14′'s pre-toggle behaviour for every existing user.
        // Assignment in `init` doesn't fire `didSet`, so a first launch
        // reads the default without writing it back.
        self.isEnabled = defaults.object(
            forKey: StorageKeys.preventSleepDuringPlay
        ) as? Bool ?? true
    }

    // MARK: Internal Methods

    /// Evaluates the predicate under Observation tracking and re-arms on
    /// every change — the standard self-rescheduling loop. `onChange` fires
    /// at *willSet*; the re-armed pass runs as a queued main-actor task,
    /// i.e. after the mutation completed, so `setInhibited` always reads
    /// settled state.
    ///
    /// Strong captures, deliberately: `onChange` is `@Sendable`, and all
    /// three types are `@MainActor` classes (hence implicitly `Sendable`).
    /// They cost nothing — the observation registrar holds this closure,
    /// not `self`, so there is no cycle, and the App owns all three objects
    /// for the process lifetime anyway.
    internal func observe(session: DGTLiveSession, connection: DGTConnection) {
        withObservationTracking {
            setInhibited(
                isEnabled && (session.liveGame != nil || connection.isRecording)
            )
        } onChange: {
            Task { @MainActor in
                self.observe(session: session, connection: connection)
            }
        }
    }

    // MARK: Private Methods

    /// Idempotent on the edges — re-evaluations of an unchanged predicate
    /// are no-ops, so the loop can re-run freely. Release is the `nil`
    /// assignment: `ActivityToken.deinit` ends the activity.
    private func setInhibited(_ inhibited: Bool) {
        guard inhibited != (token != nil) else { return }
        token = inhibited ? ActivityToken(reason: Self.activityReason) : nil
        Self.logger.info(
            "Idle-sleep inhibition \(inhibited ? "began" : "ended", privacy: .public)"
        )
    }
}
