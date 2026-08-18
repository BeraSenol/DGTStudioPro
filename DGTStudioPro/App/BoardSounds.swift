import AVFoundation
import Foundation
import Observation
import os

/// Plays the board cues and owns the nine preferences that gate them.
///
/// The owned-value shape rather than `@AppStorage`: the toggles have two readers - Settings
/// binds them, this type consults them - and a twin default is exactly the arrangement that
/// agreed perfectly on a value neither side could produce. Every default is stated once,
/// in `init`; nobody else spells `?? true`.
///
/// **There is one set of sounds.** Selectable sound sets were removed along with `BoardSoundSet`:
/// the app ships one voice, and the only choice offered is which cues are on. That deletes the
/// cache-invalidation problem the picker created (samples belonged to a set, so changing it had to
/// empty the cache) and the audition it needed - a picker over sounds you cannot hear while
/// picking is a list of adjectives, and with no picker there is nothing to audition.
///
/// Every cue is a sample at app volume, including the illegal-move cue, which used to be
/// `NSSound.beep()` at the user's **alert** volume. That split is gone deliberately: a rejected
/// position is feedback about the board, the same category as a move landing, and the system beep
/// made it sound like the machine objecting rather than like this app.
@MainActor
@Observable
final class BoardSounds {

    // MARK: Static Constants

    @ObservationIgnored
    private static let logger = AppLog.logger(.sound)

    // MARK: Policy

    /// Whether this process makes any sound at all. Silent under the test host, for the reason
    /// one layer over: a single `@Test` that walks a game would fire a cue per ply, and a suite
    /// that plays audio is a suite nobody runs with headphones on.
    ///
    /// No `DGT_LOG` twin - logging needs an escape hatch because a suppressed *diagnostic* can
    /// hide a defect, and a suppressed *click* cannot. Re-armable by constructing with
    /// `audible: true`, which is what the previews do.
    static let isAudible: Bool = isAudible(in: ProcessInfo.processInfo.environment)

    /// The policy as a pure function of an environment - `AppLog.isEnabled(in:)`'s reason, which
    /// is the only one that matters here: the constant above is `false` in every process a test
    /// runs in, so the arm a real launch takes is unreachable from a suite without this seam.
    static func isAudible(in environment: [String: String]) -> Bool {
        TestHost.isActive(in: environment) == false
    }

    // MARK: Preferences

    /// Absent reads **true** for all nine - the feature is opt-out rather than arriving switched
    /// off and needing to be discovered.
    var playsMove: Bool {
        didSet { persist(playsMove, forKey: StorageKeys.moveSoundEnabled, describing: "move") }
    }

    var playsCapture: Bool {
        didSet { persist(playsCapture, forKey: StorageKeys.captureSoundEnabled, describing: "capture") }
    }

    var playsCastle: Bool {
        didSet { persist(playsCastle, forKey: StorageKeys.castleSoundEnabled, describing: "castle") }
    }

    var playsPromote: Bool {
        didSet { persist(playsPromote, forKey: StorageKeys.promoteSoundEnabled, describing: "promote") }
    }

    var playsCheck: Bool {
        didSet { persist(playsCheck, forKey: StorageKeys.checkSoundEnabled, describing: "check") }
    }

    var playsCheckmate: Bool {
        didSet { persist(playsCheckmate, forKey: StorageKeys.checkmateSoundEnabled, describing: "checkmate") }
    }

    /// The illegal-move cue, which used to be `NSSound.beep()` fired from the App's `onDesync`
    /// closure. The change is audible and was made deliberately, so the old argument is preserved
    /// here rather than deleted: a beep rides the user's **alert** volume, which suited a warning.
    ///
    /// It is now a sample at app volume like the rest. Two reasons. The beep was the system's, so
    /// it sounded like the *machine* objecting rather than like this board - and it is not a
    /// warning, it is feedback about a position, which is the same category as every other cue
    /// here. It stays the quietest cue in each set, which is where the caution belongs.
    var playsIllegal: Bool {
        didSet { persist(playsIllegal, forKey: StorageKeys.illegalMoveSoundEnabled, describing: "illegal") }
    }

    var playsGameStart: Bool {
        didSet { persist(playsGameStart, forKey: StorageKeys.gameStartSoundEnabled, describing: "game start") }
    }

    var playsGameEnd: Bool {
        didSet { persist(playsGameEnd, forKey: StorageKeys.gameEndSoundEnabled, describing: "game end") }
    }

    // MARK: Private Properties

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let audible: Bool

    /// Loaded samples, one array per cue, filled on first use and kept for the life of the
    /// process. There is a single set of sounds now, so nothing ever invalidates this.
    ///
    /// An **array** because a cue can layer more than one sample - see `BoardCue.resources`, where
    /// `checkmate` is the move plus the game ending. An empty array is a meaningful, remembered
    /// outcome: it means every load failed, and remembering it is what stops a missing file
    /// logging an error on every ply. A channel that is always noisy is a channel being read past.
    ///
    /// The old `[BoardCue: AVAudioPlayer?]` shape used the optional for the same purpose; the
    /// array subsumes it, since "no players" and "load failed" are the same state here.
    @ObservationIgnored private var players: [BoardCue: [AVAudioPlayer]] = [:]

    // MARK: Init

    /// Both seams injectable for the same reason: the production values are fixed in any given
    /// process, so a suite standing in that process can only ever confirm the arm it is standing in.
    init(defaults: UserDefaults = .standard, audible: Bool = BoardSounds.isAudible) {
        self.defaults = defaults
        self.audible = audible
        // Assignment in `init` does not fire `didSet`, so a first launch reads without writing back.
        self.playsMove = defaults.object(forKey: StorageKeys.moveSoundEnabled) as? Bool ?? true
        self.playsCapture = defaults.object(forKey: StorageKeys.captureSoundEnabled) as? Bool ?? true
        self.playsCastle = defaults.object(forKey: StorageKeys.castleSoundEnabled) as? Bool ?? true
        self.playsPromote = defaults.object(forKey: StorageKeys.promoteSoundEnabled) as? Bool ?? true
        self.playsCheck = defaults.object(forKey: StorageKeys.checkSoundEnabled) as? Bool ?? true
        self.playsCheckmate = defaults.object(forKey: StorageKeys.checkmateSoundEnabled) as? Bool ?? true
        self.playsIllegal = defaults.object(forKey: StorageKeys.illegalMoveSoundEnabled) as? Bool ?? true
        self.playsGameStart = defaults.object(forKey: StorageKeys.gameStartSoundEnabled) as? Bool ?? true
        self.playsGameEnd = defaults.object(forKey: StorageKeys.gameEndSoundEnabled) as? Bool ?? true
    }

    // MARK: The gate

    /// Which toggle governs which cue, as a pure function - `SleepInhibitor.activityReason`'s
    /// shape and its argument, sharpened: four cues over four flags is a crossable wiring, and a
    /// `check` that reads the capture toggle compiles, renders, and is caught only by ear.
    static func isEnabled(
        _ cue: BoardCue,
        moves: Bool,
        captures: Bool,
        castles: Bool,
        promotions: Bool,
        checks: Bool,
        checkmates: Bool,
        illegals: Bool,
        gameStarts: Bool,
        gameEnds: Bool
    ) -> Bool {
        switch cue {
        case .move:      moves
        case .capture:   captures
        case .castle:    castles
        case .promote:   promotions
        case .check:     checks
        case .checkmate: checkmates
        case .illegal:   illegals
        case .gameStart: gameStarts
        case .gameEnd:   gameEnds
        }
    }

    /// The instance's own answer, so no caller re-spells the mapping.
    func isEnabled(_ cue: BoardCue) -> Bool {
        Self.isEnabled(
            cue,
            moves: playsMove,
            captures: playsCapture,
            castles: playsCastle,
            promotions: playsPromote,
            checks: playsCheck,
            checkmates: playsCheckmate,
            illegals: playsIllegal,
            gameStarts: playsGameStart,
            gameEnds: playsGameEnd
        )
    }

    // MARK: Playback

    /// Fires `cue` if this process is audible and the cue's toggle is on.
    ///
    /// **Restarts rather than stacking, per sample.** Holding → walks plies faster than a sample is
    /// long, and eight overlapping clicks is noise where one click per keypress is feedback. Note
    /// this is a different question from a cue *layering* several samples: `checkmate` plays two
    /// files at once by design, and each of those two independently restarts if the cue re-fires.
    ///
    /// The layers start together rather than in sequence. For `checkmate` that means the move and
    /// the game ending land on the same instant, which is the literal reading of "a mate is both".
    /// If it turns out to sound cluttered, staggering them is a delay on the second player here,
    /// not a change to `BoardCue`.
    func play(_ cue: BoardCue) {
        guard audible else { return }
        guard isEnabled(cue) else { return }
        for player in players(for: cue) {
            player.currentTime = 0
            player.play()
        }
    }

    // MARK: Private Methods

    private func persist(_ value: Bool, forKey key: String, describing cue: String) {
        defaults.set(value, forKey: key)
        Self.logger?.info(
            "Board cue '\(cue, privacy: .public)': \(value ? "on" : "off", privacy: .public)"
        )
    }

    /// Loads on first use and caches the outcome, including an empty one. `prepareToPlay()` does
    /// the buffer allocation now rather than inside the first move of a game.
    private func players(for cue: BoardCue) -> [AVAudioPlayer] {
        if let cached = players[cue] { return cached }

        // `compactMap`, so one missing layer does not silence the rest: a `checkmate` whose
        // game-end file is gone should still thump, and the error below says which half is absent.
        let loaded = cue.resources.compactMap(load)
        players[cue] = loaded
        return loaded
    }

    private func load(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            Self.logger?.error(
                """
                Board sample '\(name, privacy: .public).wav' missing from the app bundle - \
                every cue that uses it stays silent until it is restored
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
                Board sample '\(name, privacy: .public).wav' unreadable: \
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
