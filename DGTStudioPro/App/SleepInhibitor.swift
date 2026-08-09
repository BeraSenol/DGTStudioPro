import Foundation
import Observation
import os

/// RAII: owns exactly one `ProcessInfo` activity for its lifetime; releasing is `token = nil`,
/// so a teardown that forgets to end the activity is not expressible.
private final class ActivityToken {

    private let token: NSObjectProtocol

    fileprivate init(reason: String) {
        // `.userInitiated` = idle system sleep + auto/sudden termination disabled. Deliberately NOT
        // `.idleDisplaySleepDisabled` — "let the panel dim" is preserved by construction (D14′).
        token = ProcessInfo.processInfo.beginActivity(
            options: .userInitiated,
            reason: reason
        )
    }

    deinit { ProcessInfo.processInfo.endActivity(token) }
}

/// Holds one `ProcessInfo` activity while user-started work runs (D14′, gated by D25′, widened
/// by D66′). Two causes, two independent gates: a live game/recording needs the serial link; a
/// batch needs the engine — see `activityReason`, the one testable part.
/// Non-goals: display sleep is never inhibited (structural — it would take naming a second
/// option); logout/shutdown is not vetoed (draft sidecar + archive-first make it safe).
/// D25′: a preference is an observable property here, not `@AppStorage` — the gate must
/// participate in the tracking loop so flipping it mid-run releases the token on that edge.
@MainActor
@Observable
internal final class SleepInhibitor {

    // MARK: Static Constants
    @ObservationIgnored
    private static let logger = AppLog.logger(.power)

    /// The two halves of the `pmset -g assertions` reason string — separate because when both causes
    /// hold they are joined, not replaced.
    @ObservationIgnored
    private static let playReason = "Live chess game or board recording in progress"

    @ObservationIgnored
    private static let analysisReason = "Engine analysis in progress"

    // MARK: Preferences

    /// The play gate. Observed, so Settings re-arms the loop; persisted on write — the `?? true` in
    /// `init` is the only place the default is stated. The storage key deliberately kept its old
    /// name: renaming would silently reset the preference.
    internal var preventsSleepDuringPlay: Bool {
        didSet {
            defaults.set(preventsSleepDuringPlay, forKey: StorageKeys.preventSleepDuringPlay)
            Self.logger?.info(
                "Sleep inhibition during play: \(self.preventsSleepDuringPlay ? "on" : "off", privacy: .public)"
            )
        }
    }

    /// The analysis gate (D66′). Same shape, separate value — overnight batches and instant sleep
    /// are the same person on different evenings.
    internal var preventsSleepDuringAnalysis: Bool {
        didSet {
            defaults.set(preventsSleepDuringAnalysis, forKey: StorageKeys.preventSleepDuringAnalysis)
            Self.logger?.info(
                "Sleep inhibition during analysis: \(self.preventsSleepDuringAnalysis ? "on" : "off", privacy: .public)"
            )
        }
    }

    // MARK: Private Properties
    @ObservationIgnored private let defaults: UserDefaults

    /// Non-nil exactly while inhibition is held.
    @ObservationIgnored private var token: ActivityToken?

    /// The reason the current token was opened with, so a change of *cause* while continuously held
    /// is noticed — otherwise the idempotence guard leaves a stale reason on the one diagnostic surface.
    @ObservationIgnored private var heldReason: String?

    /// Guards `observe` against a second call: each would arm an independent loop forever.
    /// `App.init()` calls once; the guard makes that a fact about this type.
    @ObservationIgnored private var isObserving = false

    // MARK: Init

    /// Injectable so the preference contract pins against a scratch suite.
    internal init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Absent reads **true** (pre-toggle behaviour preserved). Assignment in `init` doesn't fire
        // `didSet`, so a first launch reads without writing back.
        self.preventsSleepDuringPlay = defaults.object(
            forKey: StorageKeys.preventSleepDuringPlay
        ) as? Bool ?? true
        // Same default, stated separately: two preferences that agree today are still two preferences.
        self.preventsSleepDuringAnalysis = defaults.object(
            forKey: StorageKeys.preventSleepDuringAnalysis
        ) as? Bool ?? true
    }

    // MARK: The predicate

    /// The whole decision as a pure function: which reason to hold, or nil. Extracted because two
    /// gates over two causes is a crossable wiring — this is the one part worth testing.
    internal static func activityReason(
        playing: Bool,
        analyzing: Bool,
        allowsPlay: Bool,
        allowsAnalysis: Bool
    ) -> String? {
        let reasons = [
            (playing && allowsPlay) ? playReason : nil,
            (analyzing && allowsAnalysis) ? analysisReason : nil,
        ].compactMap { $0 }
        return reasons.isEmpty ? nil : reasons.joined(separator: "; ")
    }

    // MARK: Internal Methods

    /// Self-rescheduling Observation loop. `onChange` fires at *willSet*; the re-arm runs as a
    /// queued main-actor task, after the mutation, so `setInhibited` reads settled state.
    /// Strong captures, deliberately: the closures capture the observables, not `self` — no cycle,
    /// and the App owns everything for the process lifetime.
    internal func observe(
        session: DGTLiveSession,
        connection: DGTConnection,
        analysis: AnalysisQueueController
    ) {
        guard !isObserving else { return }
        isObserving = true
        track(session: session, connection: connection, analysis: analysis)
    }

    /// The re-arm target: `onChange` recurses here, past the entry guard, so the loop keeps
    /// rescheduling while a second external `observe` bounces off `isObserving`.
    private func track(
        session: DGTLiveSession,
        connection: DGTConnection,
        analysis: AnalysisQueueController
    ) {
        withObservationTracking {
            setInhibited(
                reason: Self.activityReason(
                    playing: session.liveGame != nil || connection.isRecording,
                    analyzing: analysis.queue.isActive,
                    allowsPlay: preventsSleepDuringPlay,
                    allowsAnalysis: preventsSleepDuringAnalysis
                )
            )
        } onChange: {
            Task { @MainActor in
                self.track(session: session, connection: connection, analysis: analysis)
            }
        }
    }

    // MARK: Private Methods

    /// Idempotent on the *reason* — same answer is a no-op; a changed cause swaps the token without
    /// a gap (new before old, so the process never sits un-inhibited between two holds).
    private func setInhibited(reason: String?) {
        guard reason != heldReason else { return }
        token = reason.map { ActivityToken(reason: $0) }
        heldReason = reason
        Self.logger?.info(
            "Idle-sleep inhibition: \(reason ?? "ended", privacy: .public)"
        )
    }
}

// MARK: Previews

extension SleepInhibitor {

    /// The instance previews inject — force-unwrap plus the wipe, because a preview reading the
    /// developer's real defaults leaks last state into the canvas (S4).
    internal static var preview: SleepInhibitor {
        let name = "preview"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return SleepInhibitor(defaults: defaults)
    }
}
