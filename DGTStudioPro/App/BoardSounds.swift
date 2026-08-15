import AVFoundation
import Foundation
import Observation
import os

/// Plays the board cues and owns the four preferences that gate them (D81′).
///
/// D25′'s owned-value shape rather than `@AppStorage`: the toggles have two readers — Settings
/// binds them, this type consults them — and a twin default is exactly the arrangement that
/// agreed perfectly on a value neither side could produce (D40′). Every default is stated once,
/// in `init`; nobody else spells `?? true`.
///
/// Separate from D13′'s illegal-move beep on purpose, and the split is audible rather than
/// architectural: that one is `NSSound.beep()`, which rides the user's **alert** volume because it
/// is an alert. These are samples at app volume, because a move landing is feedback, not a warning.
@MainActor
@Observable
final class BoardSounds {

    // MARK: Static Constants

    @ObservationIgnored
    private static let logger = AppLog.logger(.sound)

    // MARK: Policy

    /// Whether this process makes any sound at all. Silent under the test host, for D63′'s reason
    /// one layer over: a single `@Test` that walks a game would fire a cue per ply, and a suite
    /// that plays audio is a suite nobody runs with headphones on.
    ///
    /// No `DGT_LOG` twin — logging needs an escape hatch because a suppressed *diagnostic* can
    /// hide a defect, and a suppressed *click* cannot. Re-armable by constructing with
    /// `audible: true`, which is what the previews do.
    static let isAudible: Bool = isAudible(in: ProcessInfo.processInfo.environment)

    /// The policy as a pure function of an environment — `AppLog.isEnabled(in:)`'s reason, which
    /// is the only one that matters here: the constant above is `false` in every process a test
    /// runs in, so the arm a real launch takes is unreachable from a suite without this seam.
    static func isAudible(in environment: [String: String]) -> Bool {
        TestHost.isActive(in: environment) == false
    }

    // MARK: Preferences

    /// Which material the cues are made of (D82′). Absent reads `.wood`, the set that shipped
    /// first, so an existing install hears exactly what it heard yesterday.
    ///
    /// Changing it does three things in one place, which is the argument for `didSet` over a
    /// view's `onChange`: it persists, it drops the loaded samples (they belong to the old set),
    /// and it **auditions**. A picker over sounds that you cannot hear while picking is a list of
    /// adjectives.
    var soundSet: BoardSoundSet {
        didSet {
            // SwiftUI may re-assign an unchanged selection; without this a re-render would clear
            // the cache and click at the reader.
            guard soundSet != oldValue else { return }

            defaults.set(soundSet.rawValue, forKey: StorageKeys.boardSoundSet)
            players.removeAll()
            Self.logger?.info("Board sound set: \(self.soundSet.rawValue, privacy: .public)")
            audition()
        }
    }

    /// Absent reads **true** for all four — the feature is opt-out, matching D13′'s illegal-move
    /// cue rather than arriving switched off and needing to be discovered.
    var playsMove: Bool {
        didSet { persist(playsMove, forKey: StorageKeys.moveSoundEnabled, describing: "move") }
    }

    var playsCapture: Bool {
        didSet { persist(playsCapture, forKey: StorageKeys.captureSoundEnabled, describing: "capture") }
    }

    var playsCheck: Bool {
        didSet { persist(playsCheck, forKey: StorageKeys.checkSoundEnabled, describing: "check") }
    }

    var playsCheckmate: Bool {
        didSet { persist(playsCheckmate, forKey: StorageKeys.checkmateSoundEnabled, describing: "checkmate") }
    }

    // MARK: Private Properties

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let audible: Bool

    /// Loaded samples for the **current set**, kept until the set changes. The value is itself
    /// optional so a *failed* load is remembered: without that, a missing resource logs an error
    /// on every ply, and a channel that is always noisy is a channel being read past (D63′'s UCI
    /// finding).
    ///
    /// Keyed on the cue alone rather than on `(set, cue)` because `soundSet`'s `didSet` empties it
    /// — one dictionary that is always about one set, instead of a compound key that would hold
    /// every set a reader ever auditioned for the life of the process.
    @ObservationIgnored private var players: [BoardCue: AVAudioPlayer?] = [:]

    // MARK: Init

    /// Both seams injectable for the same reason: the production values are fixed in any given
    /// process, so a suite standing in that process can only ever confirm the arm it is standing in.
    init(defaults: UserDefaults = .standard, audible: Bool = BoardSounds.isAudible) {
        self.defaults = defaults
        self.audible = audible
        // Assignment in `init` does not fire `didSet`, so a first launch reads without writing
        // back — and, for the set, without auditioning at launch, which would make every start of
        // the app click at you.
        self.soundSet = (defaults.string(forKey: StorageKeys.boardSoundSet)
            .flatMap(BoardSoundSet.init(rawValue:))) ?? .wood
        self.playsMove = defaults.object(forKey: StorageKeys.moveSoundEnabled) as? Bool ?? true
        self.playsCapture = defaults.object(forKey: StorageKeys.captureSoundEnabled) as? Bool ?? true
        self.playsCheck = defaults.object(forKey: StorageKeys.checkSoundEnabled) as? Bool ?? true
        self.playsCheckmate = defaults.object(forKey: StorageKeys.checkmateSoundEnabled) as? Bool ?? true
    }

    // MARK: The gate

    /// Which toggle governs which cue, as a pure function — `SleepInhibitor.activityReason`'s
    /// shape and its argument, sharpened: four cues over four flags is a crossable wiring, and a
    /// `check` that reads the capture toggle compiles, renders, and is caught only by ear.
    static func isEnabled(
        _ cue: BoardCue,
        moves: Bool,
        captures: Bool,
        checks: Bool,
        checkmates: Bool
    ) -> Bool {
        switch cue {
        case .move:      moves
        case .capture:   captures
        case .check:     checks
        case .checkmate: checkmates
        }
    }

    /// The instance's own answer, so no caller re-spells the mapping.
    func isEnabled(_ cue: BoardCue) -> Bool {
        Self.isEnabled(
            cue,
            moves: playsMove,
            captures: playsCapture,
            checks: playsCheck,
            checkmates: playsCheckmate
        )
    }

    // MARK: Playback

    /// Fires `cue` if this process is audible and the cue's toggle is on. Restarts rather than
    /// layering: holding → walks plies faster than a sample is long, and eight overlapping clicks
    /// is noise where one click per keypress is feedback.
    ///
    /// `ignoringPreference` exists for the audition and nothing else — see `audition()`. Audibility
    /// is **not** overridable by it: that flag is about the process, not about the reader's taste.
    func play(_ cue: BoardCue, ignoringPreference: Bool = false) {
        guard audible else { return }
        guard ignoringPreference || isEnabled(cue) else { return }
        guard let player = player(for: cue) else { return }
        player.currentTime = 0
        player.play()
    }

    // MARK: Private Methods

    /// Plays the new set's move cue when the reader picks it.
    ///
    /// Deliberately past the per-cue gate: you are auditioning the **set**, not the move cue, so a
    /// reader who has turned Move off would otherwise pick in silence and reasonably conclude the
    /// picker was broken. `.move` is the one to play because it is the cue you hear a hundred times
    /// an evening — the set should be chosen on its most frequent sound, not its most dramatic.
    private func audition() {
        play(.move, ignoringPreference: true)
    }

    private func persist(_ value: Bool, forKey key: String, describing cue: String) {
        defaults.set(value, forKey: key)
        Self.logger?.info(
            "Board cue '\(cue, privacy: .public)': \(value ? "on" : "off", privacy: .public)"
        )
    }

    /// Loads on first use and caches both outcomes. `prepareToPlay()` does the buffer allocation
    /// now rather than inside the first move of a game.
    private func player(for cue: BoardCue) -> AVAudioPlayer? {
        if let cached = players[cue] { return cached }

        let loaded = load(cue)
        players[cue] = loaded
        return loaded
    }

    private func load(_ cue: BoardCue) -> AVAudioPlayer? {
        let name = soundSet.resourceName(for: cue)
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            Self.logger?.error(
                """
                Board cue '\(name, privacy: .public).wav' missing from the app bundle — \
                that cue stays silent until it is restored
                """
            )
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            Self.logger?.error(
                """
                Board cue '\(name, privacy: .public).wav' unreadable: \
                \(error.localizedDescription, privacy: .public)
                """
            )
            return nil
        }
    }
}

// MARK: Previews

extension BoardSounds {

    /// The instance previews inject. Scratch defaults for `SleepInhibitor.preview`'s reason (a
    /// canvas reading the developer's real toggles leaks last state, S4), and **inaudible**: a
    /// preview that re-renders on every keystroke would click at the canvas.
    static var preview: BoardSounds {
        let name = "preview"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return BoardSounds(defaults: defaults, audible: false)
    }
}
