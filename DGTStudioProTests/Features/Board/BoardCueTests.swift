import Testing
@testable import DGTStudioPro

/// Which sound a landed move earns. Pure and nonisolated: `BoardCue` is a value question
/// over `Move` + `GameState`, so the suite matches its subject's isolation rather than the
/// player's.
///
/// The precedence rule is the whole point of testing this at all. Every arm of it is a *silent*
/// defect in production - a capture that plays the move click, or a mate that plays the check
/// chime, compiles, renders, and is caught only by someone noticing the wrong sound while looking
/// at the board. Nothing else in the app is positioned to disagree.
/// `BoardSoundSet`'s pure half rides along at the bottom rather than in its own file: the thing
/// worth testing about a set is the **set × cue** filename matrix, which is not a fact about
/// either type alone. Its stored/preference half is in `BoardSoundPreferenceTests`, which is
/// `@MainActor` because `BoardSounds` is.
@Suite("Board Cue - Classification and Naming")
struct BoardCueTests {

    // MARK: Helpers

    /// Plays `from`→`to` out of `fen` and returns the move with the position it lands in - the
    /// exact pair both call sites hand the classifier (`DGTLiveSession`'s settle arm and `Game`'s
    /// step). Resolving through `legalMoves()` rather than constructing a `Move` by hand is
    /// deliberate: a hand-built move can carry flags movegen would never set, and the en-passant
    /// case below is precisely a question about a flag movegen sets.
    private static func play(
        _ fen: String,
        _ from: String,
        _ to: String
    ) throws -> (move: Move, landing: GameState) {
        let state = try GameState(FEN(parsing: fen))
        let move = try #require(
            state.legalMoves().first {
                $0.from.algebraicNotation == from && $0.to.algebraicNotation == to
            },
            "\(from)\(to) is not legal in \(fen) - the fixture is wrong, not the classifier"
        )
        return (move, state.applying(move))
    }

    private static func cue(_ fen: String, _ from: String, _ to: String) throws -> BoardCue {
        let (move, landing) = try play(fen, from, to)
        return BoardCue.cue(for: move, landing: landing)
    }

    // MARK: Fixtures

    /// One position per cue, kept in one place because two tests read it: the per-cue expectations
    /// and `everyCueIsProducible` (`SpecialCheckmateTests`' arrangement).
    private static let fixtures: [(cue: BoardCue, fen: String, from: String, to: String)] = [
        (.move,
         "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", "e2", "e4"),
        (.capture,
         "4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1", "e4", "d5"),
        (.check,
         "4k3/8/8/8/8/8/8/R3K3 w - - 0 1", "a1", "a8"),
        (.checkmate,
         "6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1", "a1", "a8"),
    ]

    // MARK: Per-cue

    @Test("Each cue's own position produces it", arguments: fixtures)
    func fixtureProducesItsCue(
        _ fixture: (cue: BoardCue, fen: String, from: String, to: String)
    ) throws {
        #expect(try Self.cue(fixture.fen, fixture.from, fixture.to) == fixture.cue)
    }

    /// **Every cue can actually be produced by a legal move**, run through the classifier rather
    /// than read off the fixture labels - a table asserting its own contents proves nothing. A cue
    /// added without a fixture is a sound nothing shows reachable, and a sound nothing shows
    /// reachable is a sample nobody has heard.
    @Test("Every cue is produced by some position")
    func everyCueIsProducible() throws {
        var produced: Set<BoardCue> = []
        for fixture in Self.fixtures {
            produced.insert(try Self.cue(fixture.fen, fixture.from, fixture.to))
        }
        #expect(produced == Set(BoardCue.allCases))
    }

    // MARK: Precedence - the reason this suite exists

    /// A capture that gives check is **one** sound, and it is the check. Rxd8+ takes a rook and
    /// checks along the eighth; the losing spelling plays `capture` and is indistinguishable from
    /// a quiet exchange by ear.
    @Test("A capture that checks is a check, not a capture")
    func checkOutranksCapture() throws {
        #expect(try Self.cue("3rk3/8/8/8/8/8/8/3RK3 w - - 0 1", "d1", "d8") == .check)
    }

    /// Rxb8# takes a rook *and* checks *and* mates. Only the mate is heard - the rule the Settings
    /// footer states, pinned at its sharpest case, where all three arms are simultaneously true.
    @Test("A capture that mates is a checkmate, not a check or a capture")
    func checkmateOutranksEverything() throws {
        #expect(try Self.cue("1r4k1/5ppp/8/8/8/8/8/1R4K1 w - - 0 1", "b1", "b8") == .checkmate)
    }

    // MARK: The two edges

    /// En passant is the one capture whose destination square is empty, so a classifier reading the
    /// board rather than the move would call it quiet. `Move.isCapture` is a bit test over the
    /// captured-type field, which movegen stamps `.pawn` for en passant - this pins that it does.
    @Test("En passant is a capture")
    func enPassantIsACapture() throws {
        #expect(try Self.cue("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1", "e5", "d6") == .capture)
    }

    /// Stalemate has no cue and deliberately falls through to the ordinary move: the position is
    /// drawn, but the *move* was quiet, and there is no sample for it. Documented as a decision at
    /// `BoardCue.cue`; this is the test that would fail if someone "fixed" it into a mate sound,
    /// which is the tempting wrong answer - no legal replies looks like the end of a game.
    @Test("Stalemate is not a checkmate")
    func stalemateFallsThroughToMove() throws {
        #expect(try Self.cue("7k/8/6K1/8/8/8/5Q2/8 w - - 0 1", "f2", "f7") == .move)
    }

    // MARK: Bundle contract

    // MARK: Bundle contract

    /// Both halves of every filename. Pinned on literals, which is rare and correct here for
    /// `AppLog`'s category reason: these strings name files in the app bundle, so nothing in the
    /// app would notice if one drifted - the symptom is silence, and silence is what an off toggle
    /// looks like too. Bundle *presence* is a manual check; a missing file logs to `sound`.
    @Test("Raw values are half of a filename each")
    func rawValuesArePinned() {
        #expect(BoardCue.move.rawValue == "move")
        #expect(BoardCue.capture.rawValue == "capture")
        #expect(BoardCue.check.rawValue == "check")
        #expect(BoardCue.checkmate.rawValue == "checkmate")

        #expect(BoardSoundSet.felt.rawValue == "felt")
        #expect(BoardSoundSet.wood.rawValue == "wood")
        #expect(BoardSoundSet.marble.rawValue == "marble")
    }

    /// The whole set × cue matrix, which is what actually has to exist on disk.
    ///
    /// Distinctness is the property a rename breaks silently: two entries colliding is one cue
    /// playing another's sound with every string still spelled correctly. Asserted over the full
    /// product rather than per set, because a collision *across* sets - `wood-check` reachable as
    /// marble's - is the one no per-set test could see.
    @Test("Every set × cue names a distinct resource")
    func resourceNameMatrixIsComplete() {
        var names: [String] = []
        for set in BoardSoundSet.allCases {
            for cue in BoardCue.allCases {
                names.append(set.resourceName(for: cue))
            }
        }

        #expect(names.count == BoardSoundSet.allCases.count * BoardCue.allCases.count)
        #expect(Set(names).count == names.count)
        #expect(names.contains("wood-move"))
        #expect(names.contains("felt-checkmate"))
        #expect(names.contains("marble-capture"))

        // No separator drift: the generator writes `<set>-<cue>.wav`, and an underscore or a
        // capital here is twelve missing files with a green build.
        for name in names {
            #expect(name == name.lowercased())
            #expect(name.filter { $0 == "-" }.count == 1)
        }
    }

    /// Written out rather than `rawValue.capitalized`, which works for all three today - the
    /// tripwire for the first set whose name is two words or carries an accent.
    @Test("Display names are written out")
    func displayNamesAreWrittenOut() {
        #expect(BoardSoundSet.felt.displayName == "Felt")
        #expect(BoardSoundSet.wood.displayName == "Wood")
        #expect(BoardSoundSet.marble.displayName == "Marble")
    }

    /// Soft → hard, which is what makes the picker read as a scale. A reordering is a UI change
    /// and should be a deliberate one.
    @Test("Sets are offered soft to hard")
    func setsAreOrderedByHardness() {
        #expect(BoardSoundSet.allCases == [.felt, .wood, .marble])
    }
}
