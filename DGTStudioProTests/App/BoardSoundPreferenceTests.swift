import Foundation
import Testing

@testable import DGTStudioPro

/// The four cue gates. `SleepInhibitorPreferenceTests`' subject one size up, and the reason
/// it is pinned rather than waived is the same argument sharpened: two gates over two causes can
/// be crossed, and **four** toggles over four cues can be crossed in twelve ways. A `check` that
/// reads the capture flag compiles, renders a correct-looking Settings pane, and is caught only by
/// turning one toggle off and noticing the wrong sound stopped.
///
/// The playback half stays waived - `AVAudioPlayer` over a bundled file is transport, and the
/// audible manual check is its witness. What is tested is every decision made before a sample is
/// asked for.
@MainActor
@Suite("Board sound preferences")
struct BoardSoundPreferenceTests {

    /// A throwaway suite per test - `.standard` would edit the developer's own settings and a
    /// fixed name would race under parallel execution.
    private func withScratchDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let name = "com.berasenol.dgtstudiopro.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    /// Always inaudible: a suite that reached a speaker would be the console noise with a worse
    /// failure mode. The `audible:` seam exists for exactly this.
    ///
    /// Named `makeSounds` rather than `sounds` deliberately - every caller below binds `let sounds
    /// = …`, and a local shadowing a same-named method on its own initialising line is a
    /// use-before-declaration error, not a shadow.
    private func makeSounds(_ defaults: UserDefaults) -> BoardSounds {
        BoardSounds(defaults: defaults, audible: false)
    }

    /// The property → key mapping, restated **independently** of production. That is deliberate
    /// duplication rather than an oversight: a test that asked `BoardSounds` which key it uses
    /// would agree with any answer it gave, including a crossed one. This is the second opinion.
    private static func key(for cue: BoardCue) -> String {
        switch cue {
        case .move:      StorageKeys.moveSoundEnabled
        case .capture:   StorageKeys.captureSoundEnabled
        case .castle:    StorageKeys.castleSoundEnabled
        case .promote:   StorageKeys.promoteSoundEnabled
        case .check:     StorageKeys.checkSoundEnabled
        case .checkmate: StorageKeys.checkmateSoundEnabled
        // Not `illegalSoundEnabled`. The key predates the cue - it was the beep's - and is kept
        // under its old name so an install that had turned the beep off does not get it back as
        // a sample. Restated here independently, which is this table's whole job.
        case .illegal:   StorageKeys.illegalMoveSoundEnabled
        case .gameStart: StorageKeys.gameStartSoundEnabled
        case .gameEnd:   StorageKeys.gameEndSoundEnabled
        }
    }

    private func set(_ cue: BoardCue, to value: Bool, on sounds: BoardSounds) {
        switch cue {
        case .move:      sounds.playsMove = value
        case .capture:   sounds.playsCapture = value
        case .castle:    sounds.playsCastle = value
        case .promote:   sounds.playsPromote = value
        case .check:     sounds.playsCheck = value
        case .checkmate: sounds.playsCheckmate = value
        case .illegal:   sounds.playsIllegal = value
        case .gameStart: sounds.playsGameStart = value
        case .gameEnd:   sounds.playsGameEnd = value
        }
    }

    // MARK: Defaults

    /// Driven off `allCases` rather than written out, which is the one place in this suite where
    /// deriving beats restating: the property under test is "**every** cue defaults to on", and a
    /// hand-written list silently stops testing a cue the day one is added.
    @Test("An untouched preference reads as enabled", arguments: BoardCue.allCases)
    func absentKeysReadAsEnabled(_ cue: BoardCue) throws {
        try withScratchDefaults { defaults in
            #expect(makeSounds(defaults).isEnabled(cue), "\(cue) did not default to on")
        }
    }

    // The six sound-set tests that lived here are gone with `BoardSoundSet`: the default, the
    // stored round trip, the unknown-value fallback, the write-through, the read-writes-nothing
    // twin, and the independence of set and toggles. The app ships one set of sounds, so there is
    // no selection to store, honour or fall back from - `StorageKeys.boardSoundSet` is retired.

    // MARK: Cue toggles

    /// All nine off at once. Kept, and **known to be the weaker half**: every input agrees, so it
    /// passes even if two properties read each other's key. `eachCueReadsItsOwnKey` is the version
    /// that could fail - this one only proves nothing is ignored outright.
    @Test("A stored false is honoured")
    func storedFalseIsHonoured() throws {
        try withScratchDefaults { defaults in
            for cue in BoardCue.allCases {
                defaults.set(false, forKey: Self.key(for: cue))
            }

            let sounds = makeSounds(defaults)
            for cue in BoardCue.allCases {
                #expect(sounds.isEnabled(cue) == false, "\(cue) ignored a stored false")
            }
        }
    }

    /// Reading must not write: a first launch that persisted its own defaults would make "never
    /// touched" and "deliberately left on" indistinguishable, and a future change of default would
    /// then silently not apply to anyone who had ever opened the app.
    @Test("Construction writes nothing")
    func constructionDoesNotPersist() throws {
        try withScratchDefaults { defaults in
            _ = makeSounds(defaults)
            for cue in BoardCue.allCases {
                #expect(
                    defaults.object(forKey: Self.key(for: cue)) == nil,
                    "constructing wrote \(cue)'s key"
                )
            }
        }
    }

    // MARK: Round trip, one key at a time - the crossable half

    /// **Read side.** Store `false` for exactly one cue and confirm exactly that cue reads off.
    /// This is what `storedFalseIsHonoured` cannot do: with all four keys set to the same value, a
    /// property reading its neighbour's key produces an identical, passing result. Here the
    /// expected answer differs per property, so a crossed read has somewhere to show.
    @Test("Each cue reads its own key", arguments: BoardCue.allCases)
    func eachCueReadsItsOwnKey(_ cue: BoardCue) throws {
        try withScratchDefaults { defaults in
            defaults.set(false, forKey: Self.key(for: cue))
            let sounds = makeSounds(defaults)

            for candidate in BoardCue.allCases {
                #expect(
                    sounds.isEnabled(candidate) == (candidate != cue),
                    "storing false for \(cue) left \(candidate) reading \(sounds.isEnabled(candidate))"
                )
            }
        }
    }

    /// **Write side**, the mirror. Flip one property and confirm exactly one key appears. A
    /// `didSet` persisting under a neighbour's key is silent in the running app - the value looks
    /// saved, and comes back wrong on the *next launch*, which is the worst place to discover it.
    @Test("Each cue writes its own key", arguments: BoardCue.allCases)
    func eachCueWritesItsOwnKey(_ cue: BoardCue) throws {
        try withScratchDefaults { defaults in
            let sounds = makeSounds(defaults)
            set(cue, to: false, on: sounds)

            for candidate in BoardCue.allCases {
                let expected: Bool? = (candidate == cue) ? false : nil
                #expect(
                    defaults.object(forKey: Self.key(for: candidate)) as? Bool == expected,
                    "flipping \(cue) wrote the wrong key - \(candidate)'s changed too"
                )
            }
        }
    }

    /// The full loop through a *fresh instance*, which is what a relaunch actually is. The two
    /// halves above compose to this, but only if they agree about the key - so this asserts the
    /// property the reader cares about ("it was still off this morning") without going through
    /// `StorageKeys` at all.
    @Test("A flip survives a relaunch", arguments: BoardCue.allCases)
    func aFlipSurvivesARelaunch(_ cue: BoardCue) throws {
        try withScratchDefaults { defaults in
            let first = makeSounds(defaults)
            set(cue, to: false, on: first)

            let relaunched = makeSounds(defaults)
            for candidate in BoardCue.allCases {
                #expect(relaunched.isEnabled(candidate) == (candidate != cue))
            }
        }
    }

    // MARK: The gate - the crossable wiring

    /// Exactly one flag governs each cue. Driven off `allCases` so a tenth cue arriving without a
    /// flag fails here rather than shipping permanently silent, and asserted in both directions:
    /// the cue's own flag enables it, and no other flag does.
    ///
    /// Nine cues over nine flags is seventy-two ways to cross a wire, which is why this is the
    /// test the suite exists for. The gate is called with one flag on at a time, so a `check` that
    /// reads the capture flag shows up as a specific, named failure rather than as a wrong sound
    /// somebody eventually notices.
    @Test("Each cue is governed by its own toggle and no other", arguments: BoardCue.allCases)
    func eachCueReadsItsOwnFlag(_ cue: BoardCue) {
        for candidate in BoardCue.allCases {
            // Only `candidate`'s flag is on; every other flag is off.
            let enabled = BoardSounds.isEnabled(
                cue,
                moves:      candidate == .move,
                captures:   candidate == .capture,
                castles:    candidate == .castle,
                promotions: candidate == .promote,
                checks:     candidate == .check,
                checkmates: candidate == .checkmate,
                illegals:   candidate == .illegal,
                gameStarts: candidate == .gameStart,
                gameEnds:   candidate == .gameEnd
            )
            #expect(
                enabled == (candidate == cue),
                "\(cue) answered \(enabled) while only the \(candidate) toggle was on"
            )
        }
    }

    /// The instance's answer must be the static one - otherwise the tested mapping and the shipped
    /// mapping are two mappings, which is the twin-read-site pattern wearing a method call.
    @Test("The instance agrees with the pure gate", arguments: BoardCue.allCases)
    func instanceAgreesWithTheStaticGate(_ cue: BoardCue) throws {
        try withScratchDefaults { defaults in
            let sounds = makeSounds(defaults)
            for other in BoardCue.allCases {
                set(other, to: false, on: sounds)
            }
            #expect(sounds.isEnabled(cue) == false)

            set(cue, to: true, on: sounds)
            #expect(sounds.isEnabled(cue))
        }
    }

    // MARK: Audibility policy

    /// Both arms, which is the only reason the `in:` seam exists: `BoardSounds.isAudible` is
    /// `false` in every process this suite can run in, so a test asserting the constant would
    /// confirm nothing but the room it is standing in.
    @Test("A real launch is audible; a test host is not")
    func audibilityFollowsTheTestHost() {
        #expect(BoardSounds.isAudible(in: [:]))
        #expect(BoardSounds.isAudible(in: ["PATH": "/usr/bin"]))
        #expect(BoardSounds.isAudible(in: ["XCTestConfigurationFilePath": "/tmp/x.xctestconfiguration"]) == false)
        #expect(BoardSounds.isAudible(in: ["XCTestSessionIdentifier": "abc"]) == false)
    }

    /// An inaudible player still answers the gate honestly - the two are independent, and folding
    /// them would make "the toggle is off" and "this process is silent" the same state.
    @Test("Silence does not disable the preferences")
    func inaudibleStillReportsItsGates() throws {
        try withScratchDefaults { defaults in
            let sounds = makeSounds(defaults)
            #expect(sounds.isEnabled(.move))
            sounds.play(.move)  // no-op, and must not trap on a resource it never loads
            #expect(sounds.isEnabled(.move))
        }
    }
}
