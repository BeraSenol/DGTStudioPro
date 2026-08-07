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

/// M-ux.2 (D14′, gated by D25′, widened by D66′): holds one `ProcessInfo`
/// activity while something the user started is still running and they haven't
/// opted out of keeping it alive.
///
/// **Two causes, two gates, paired** (D66′). A live game or board recording
/// needs the *serial link* to survive a think; a batch analysis needs the
/// *engine* to survive a drain that can run for hours. They are independent
/// preferences because they are independent situations — see
/// `activityReason(playing:analyzing:allowsPlay:allowsAnalysis:)`, which is
/// where the pairing lives and is the one part of this type worth testing.
/// The play cause's `||` still covers both readings of "recording" (live SAN
/// capture and the M8.3 board-stream recorder), so that trigger needs no
/// disambiguation.
///
/// Deliberate non-goals:
/// - **Display sleep is not inhibited**, under either cause. Long think-times
///   with the player away from the Mac; the physical board is truth and the
///   mirror a glance. An overnight batch wants the panel dark even more than a
///   game does, so D66′ inherits this rather than reopening it. Structural
///   rather than commented — it would take naming a second `ProcessInfo`
///   option to break.
/// - **Logout/shutdown is not vetoed.** A user-initiated logout proceeds; the
///   draft sidecar plus archive-first already make one mid-game safe, and a
///   half-finished batch re-runs.
///
/// D25′ — a preference is an observable property *here*, not an `@AppStorage`
/// read: a gate must participate in the tracking loop so switching it off
/// mid-run releases the assertion on that edge rather than on the next
/// unrelated change. Settings binds to these same properties, so each "absent
/// reads as true" default lives exactly once, in the initializer.
///
/// Rejected: KVO / `UserDefaults.didChangeNotification` (re-deriving what
/// Observation already does); raw IOKit `IOPMAssertionCreateWithName` (no
/// Swift-native lifecycle); a permanent assertion (drains power idling at the
/// Library).
///
/// Waived in part: the token is transport. **The predicate is no longer part
/// of the waiver** — D14′'s was one gate over two causes and had nothing to
/// extract; this one is two gates that must each pair with the *right* cause,
/// which is a wiring that can be crossed silently, so it is a pure function
/// with a truth table behind it. The preferences' defaults and persistence are
/// pinned by `SleepInhibitorPreferenceTests`. `pmset -g assertions` shows the
/// held activity by its reason string, which is why that string names the
/// cause rather than being a constant.
@MainActor
@Observable
internal final class SleepInhibitor {

    // MARK: Static Constants
    @ObservationIgnored
    private static let logger = AppLog.logger(.power)

    /// The two halves of the reason string `pmset -g assertions` prints.
    /// Separate constants rather than one switch, because when both causes
    /// hold they are joined rather than replaced.
    @ObservationIgnored
    private static let playReason = "Live chess game or board recording in progress"

    @ObservationIgnored
    private static let analysisReason = "Engine analysis in progress"

    // MARK: Preferences

    /// The play gate. Observed, so Settings flipping it re-arms the loop
    /// below on the same turn; persisted on write, so the `?? true` in
    /// `init` is the only place the default is stated.
    ///
    /// Renamed from `isEnabled` by D66′. The bare name was right while there
    /// was one gate and became a question the moment there were two — the
    /// `ResultRefusal` → `FieldRefusal` move at D61′, where a second instance
    /// is what turns a name into an ambiguity. The *storage key* deliberately
    /// did not move: renaming that would silently reset every existing
    /// choice.
    internal var preventsSleepDuringPlay: Bool {
        didSet {
            defaults.set(preventsSleepDuringPlay, forKey: StorageKeys.preventSleepDuringPlay)
            Self.logger?.info(
                "Sleep inhibition during play: \(self.preventsSleepDuringPlay ? "on" : "off", privacy: .public)"
            )
        }
    }

    /// The analysis gate (D66′). Same shape, same default, separate value —
    /// a person who wants a batch to finish overnight and a person who wants
    /// the Mac to sleep the moment they walk away from the board are the same
    /// person on different evenings.
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

    /// The reason the current token was opened with, so a *change* of cause
    /// while inhibition is continuously held can be noticed. Without it the
    /// idempotence guard would compare only held-versus-not and leave a token
    /// opened for "live game" still claiming that after the game archived and
    /// only the batch remained — a lie told to the one diagnostic surface this
    /// type has.
    @ObservationIgnored private var heldReason: String?

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
        self.preventsSleepDuringPlay = defaults.object(
            forKey: StorageKeys.preventSleepDuringPlay
        ) as? Bool ?? true
        // Same default for the same reason, and stated here rather than
        // shared with the line above: two preferences that agree today are
        // still two preferences, and folding them into one expression is how
        // changing one later changes both.
        self.preventsSleepDuringAnalysis = defaults.object(
            forKey: StorageKeys.preventSleepDuringAnalysis
        ) as? Bool ?? true
    }

    // MARK: The predicate

    /// The whole decision, as a pure function: which reason to hold an
    /// activity for, or `nil` to hold none.
    ///
    /// **Extracted because two gates over two causes is a crossable wiring.**
    /// `allowsPlay && analyzing` compiles, reads plausibly, and means the
    /// analysis preference is guarding the board — a defect with no symptom
    /// until someone turns one toggle off and watches the wrong thing happen
    /// hours later. D14′'s single-gate predicate genuinely had nothing to
    /// extract; this one has a truth table, so it gets one.
    ///
    /// Returning the *reason* rather than a `Bool` folds two questions into
    /// one answer, and it is the honest shape: the reason string is not
    /// decoration, it is what `pmset -g assertions` prints, so a caller that
    /// knew "yes, inhibit" without knowing why would have to re-derive the
    /// cause it just computed.
    ///
    /// Joined rather than prioritised when both hold — an activity held for
    /// two reasons that names one of them is the same lie in a smaller font.
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

    /// Evaluates the predicate under Observation tracking and re-arms on
    /// every change — the standard self-rescheduling loop. `onChange` fires
    /// at *willSet*; the re-armed pass runs as a queued main-actor task,
    /// i.e. after the mutation completed, so `setInhibited` always reads
    /// settled state.
    ///
    /// Strong captures, deliberately: `onChange` is `@Sendable`, and every
    /// captured type is a `@MainActor` class (hence implicitly `Sendable`).
    /// They cost nothing — the observation registrar holds this closure,
    /// not `self`, so there is no cycle, and the App owns all of them for the
    /// process lifetime anyway. (This sentence counted "all three" until D66′
    /// made it four; the count is gone rather than corrected, which is the
    /// only spelling that survives the next parameter.)
    ///
    /// `analysis` is app-global (controller decision 2, reversed from per-tab
    /// on 6 Aug 2026) — which is what makes this a parameter rather than a
    /// registry lookup. Against the per-tab controller this feature would have
    /// needed a way to ask "is *any* tab analyzing", and there was deliberately
    /// no such door.
    ///
    /// The loop reads `analysis.queue`, which is **not** `@ObservationIgnored`
    /// — checked rather than assumed, because this is D14′'s recorded trap
    /// arriving at a second site: `DGTConnection.recorder` had to stay observed
    /// for `isRecording` to register, and `queue.isActive` has the same
    /// requirement one level down. An `@ObservationIgnored` on that property
    /// would leave a batch running with the Mac asleep and nothing to see.
    internal func observe(
        session: DGTLiveSession,
        connection: DGTConnection,
        analysis: AnalysisQueueController
    ) {
        guard !isObserving else { return }
        isObserving = true
        track(session: session, connection: connection, analysis: analysis)
    }

    /// The re-arm target: `onChange` recurses here, past the entry guard,
    /// so the loop keeps rescheduling itself while a second external
    /// `observe` still bounces off `isObserving`.
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

    /// Idempotent on the reason — re-evaluations that reach the same answer
    /// are no-ops, so the loop can re-run freely. Release is the `nil`
    /// assignment: `ActivityToken.deinit` ends the activity.
    ///
    /// **The new token is constructed before the old one is released**, which
    /// matters only in the case this method exists to handle: a cause changing
    /// while inhibition stays held. `token = reason.map { … }` evaluates the
    /// right-hand side — opening the new activity — and releases the previous
    /// value on assignment, so the process never sits un-inhibited between two
    /// reasons. Reversing it into an explicit `token = nil` first would open a
    /// window where the Mac could sleep during a handover from a finished game
    /// to a still-draining batch.
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
