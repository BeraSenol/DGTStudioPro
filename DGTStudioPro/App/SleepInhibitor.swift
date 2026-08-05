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
/// Deliberate non-goals:
/// - **Display sleep is not inhibited.** Long think-times with the player away
///   from the Mac; the physical board is truth and the mirror a glance, so
///   letting the panel dim is correct. Structural rather than commented — it
///   would take naming a second `ProcessInfo` option to break.
/// - **Logout/shutdown is not vetoed.** A user-initiated logout proceeds; the
///   draft sidecar plus archive-first already make one mid-game safe.
///
/// D25′ — the preference is an observable property *here*, not an `@AppStorage`
/// read: the gate must participate in the tracking loop so switching it off
/// mid-game releases the assertion on that edge rather than on the next
/// unrelated change. Settings binds to this same property, so the "absent reads
/// as true" default lives exactly once, in the initializer — the first
/// preference in the app with no twin read site.
///
/// Rejected: KVO / `UserDefaults.didChangeNotification` (re-deriving what
/// Observation already does); raw IOKit `IOPMAssertionCreateWithName` (no
/// Swift-native lifecycle); a permanent assertion (drains power idling at the
/// Library).
///
/// Waived in part: the token is transport and the predicate has nothing to
/// extract. The preference's default and persistence are *not* waived —
/// `SleepInhibitorPreferenceTests` pins them. `pmset -g assertions` shows the
/// held activity by its reason string.
@MainActor
@Observable
internal final class SleepInhibitor {

    // MARK: Static Constants
    @ObservationIgnored
    private static let logger = AppLog.logger(.power)

    @ObservationIgnored
    private static let activityReason = "Live chess game or board recording in progress"

    // MARK: Preference

    /// The user gate. Observed, so Settings flipping it re-arms the loop
    /// below on the same turn; persisted on write, so the `?? true` in
    /// `init` is the only place the default is stated.
    internal var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: StorageKeys.preventSleepDuringPlay)
            Self.logger?.info(
                "Sleep inhibition preference: \(self.isEnabled ? "on" : "off", privacy: .public)"
            )
        }
    }

    // MARK: Private Properties
    @ObservationIgnored private let defaults: UserDefaults

    /// Non-nil exactly while inhibition is held.
    @ObservationIgnored private var token: ActivityToken?

    /// Guards `observe` against a second external call: each call would arm
    /// an independent self-rescheduling loop, and every predicate change
    /// would then fan out into one queued re-arm per loop, forever —
    /// harmless through `setInhibited`'s idempotence, but permanent
    /// duplicate work (30 July audit). `App.init()` calls once; the guard
    /// makes that a fact about this type rather than about its one caller.
    @ObservationIgnored private var isObserving = false

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
        guard !isObserving else { return }
        isObserving = true
        track(session: session, connection: connection)
    }

    /// The re-arm target: `onChange` recurses here, past the entry guard,
    /// so the loop keeps rescheduling itself while a second external
    /// `observe` still bounces off `isObserving`.
    private func track(session: DGTLiveSession, connection: DGTConnection) {
        withObservationTracking {
            setInhibited(
                isEnabled && (session.liveGame != nil || connection.isRecording)
            )
        } onChange: {
            Task { @MainActor in
                self.track(session: session, connection: connection)
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
        Self.logger?.info(
            "Idle-sleep inhibition \(inhibited ? "began" : "ended", privacy: .public)"
        )
    }
}

// MARK: Previews

extension SleepInhibitor {

    /// The instance canvas previews inject — `InspectorSectionCollapse.preview`'s
    /// exact shape, adopted 4 Aug 2026 when the 1 Aug review's S4 finding turned
    /// out to have a sibling: `SettingsView`'s preview built this inline with the
    /// force-unwrap but **without the wipe**, so the Energy toggle's last state
    /// leaked between canvas sessions through the named suite's real plist. Same
    /// suite name as the collapse preview on purpose — previews share one scratch
    /// domain, and whichever accessor runs first wipes it whole.
    ///
    /// `!` over a `?? .standard` fallback, for the recorded reason: the init only
    /// fails for a nil or system-reserved suite name, and the fallback's failure
    /// mode is a canvas silently editing the developer's own defaults.
    internal static var preview: SleepInhibitor {
        let name = "preview"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return SleepInhibitor(defaults: defaults)
    }
}
