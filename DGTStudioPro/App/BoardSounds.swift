import AVFoundation
import Foundation
import Observation
import os

/// Plays the board cues and owns the nine preferences that gate them.
///
/// Values, not `@AppStorage`: the toggles have two readers — Settings binds them, this type
/// consults them — and a twin default is exactly the arrangement where both sides agree perfectly
/// on a value neither can produce. Every default is stated once, in `init`; nobody spells `?? true`
/// anywhere else.
///
/// One voice, nine cues, seven samples. Every cue is a sample at app volume, the illegal-move cue
/// included: a rejected position is feedback about the board, not a system warning, so it does not
/// ride the user's alert volume the way `NSSound.beep()` did.
@MainActor
@Observable
final class BoardSounds {
    
    // MARK: Static Constants
    
    @ObservationIgnored
    private static let logger = AppLog.logger(.sound)
    
    // MARK: Policy
    
    /// Whether this process makes any sound. Silent under the test host: one `@Test` walking a
    /// game fires a cue per ply, and a suite that plays audio is one nobody runs in headphones.
    ///
    /// No `DGT_LOG` twin, deliberately — a suppressed *diagnostic* can hide a defect, a suppressed
    /// *click* cannot. Re-armed by constructing with `audible: true`, which is what previews do.
    static let isAudible: Bool = isAudible(in: ProcessInfo.processInfo.environment)
    
    /// The testable twin: the constant above is `false` in every process a suite runs in, so the
    /// arm a real launch takes is unreachable without this seam.
    static func isAudible(in environment: [String: String]) -> Bool {
        TestHost.isActive(in: environment) == false
    }
    
    // MARK: Preferences
    
    /// Absent reads **true** for all nine — opt-out, rather than a feature that arrives off and
    /// has to be discovered.
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
    
    /// Loaded samples, filled on first use and kept for the life of the process. An **array**
    /// because a cue can layer samples — `checkmate` is the move plus the game ending. An empty
    /// array is a meaningful, remembered outcome: every load failed, and remembering it is what
    /// stops a missing file logging an error on every ply.
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
    
    /// Which toggle governs which cue, as a pure function. Nine cues over nine flags is crossable
    /// wiring: a `check` that reads the capture toggle compiles, renders, and is caught only by ear.
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
    /// long, and overlapping clicks are noise where one click per keypress is feedback. A cue that
    /// *layers* samples is a separate question: `checkmate` plays two files at once, started
    /// together, and each restarts independently.
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
    
    /// Loads on first use and caches the outcome, including an empty one.
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
    
    /// The instance previews inject: scratch defaults, so a canvas never reads the developer's own
    /// toggles (S4), and **inaudible**, so a re-render on every keystroke does not click.
    static var preview: BoardSounds {
        let name = "preview"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return BoardSounds(defaults: defaults, audible: false)
    }
}
