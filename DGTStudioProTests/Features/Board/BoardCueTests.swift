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
/// The naming half rides along at the bottom: which `.wav` each cue asks the bundle for, now that
/// `BoardSoundSet` is gone and a cue names its own file. The stored/preference half is in
/// `BoardSoundPreferenceTests`, which is `@MainActor` because `BoardSounds` is.
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
    /// and `everyMoveCueIsProducible` (`SpecialCheckmateTests`' arrangement; this citation
    /// dropped the "Move" for two weeks - caught by the 26 Aug sweep's dead-name scan).
    /// The black king sits on e3 in the castle and promotion fixtures rather than on e8, which
    /// looks arbitrary and is not: a queen appearing on a8 or a rook landing on f1 checks a king
    /// on e8 down an empty rank or file, and the fixture would then be testing `check` while
    /// claiming to test promotion.
    private static let fixtures: [(cue: BoardCue, fen: String, from: String, to: String)] = [
        (.move,
         "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", "e2", "e4"),
        (.capture,
         "4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1", "e4", "d5"),
        (.castle,
         "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1", "e1", "g1"),
        (.promote,
         "8/P7/8/8/8/4k3/8/4K3 w - - 0 1", "a7", "a8"),
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

    /// **Every move cue can actually be produced by a legal move**, run through the classifier
    /// rather than read off the fixture labels - a table asserting its own contents proves nothing.
    /// A cue added without a fixture is a sound nothing shows reachable, and a sound nothing shows
    /// reachable is a sample nobody has heard.
    ///
    /// Scoped to the move family, and the complement is asserted alongside it rather than left
    /// implied. `cue(for:landing:)` returning an event would be a real defect - `illegal` fired by
    /// a legal move is the app calling a legitimate move a mistake - and it is exactly the kind of
    /// thing a careless `default:` arm would introduce.
    @Test("Every move cue is produced by some position, and no event cue is")
    func everyMoveCueIsProducible() throws {
        var produced: Set<BoardCue> = []
        for fixture in Self.fixtures {
            produced.insert(try Self.cue(fixture.fen, fixture.from, fixture.to))
        }

        let moveCues = Set(BoardCue.allCases.filter { $0.family == .move })
        #expect(produced == moveCues)
        #expect(produced.allSatisfy { $0.family == .move })
        #expect(produced.isDisjoint(with: Set(BoardCue.allCases.filter { $0.family == .event })))
    }

    /// The families partition the enum - no cue in both, none in neither. Cheap, and it is the
    /// assertion that fails when a case is added to the enum and forgotten in `family`.
    @Test("Families partition the cues")
    func familiesPartitionTheCues() {
        let moves = BoardCue.allCases.filter { $0.family == .move }
        let events = BoardCue.allCases.filter { $0.family == .event }
        #expect(moves.count + events.count == BoardCue.allCases.count)
        #expect(Set(moves).isDisjoint(with: Set(events)))
        #expect(events == [.illegal, .gameStart, .gameEnd])
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

    /// bxa8=Q takes a rook *and* promotes. The new queen is the fact worth hearing: captures are
    /// ordinary and promotions are not, so a promoting capture that played `capture` would bury
    /// the rarer event under the commoner one.
    @Test("A capture that promotes is a promotion, not a capture")
    func promotionOutranksCapture() throws {
        #expect(try Self.cue("r7/1P6/8/8/8/4k3/8/4K3 w - - 0 1", "b7", "a8") == .promote)
    }

    /// A promotion that also checks is a check, which keeps the check tests above unconditional:
    /// nothing outranks check except mate. Here the queen lands on a8 with the king back on e8,
    /// the arrangement the fixtures deliberately avoid.
    @Test("A promotion that checks is a check")
    func checkOutranksPromotion() throws {
        #expect(try Self.cue("4k3/P7/8/8/8/8/8/4K3 w - - 0 1", "a7", "a8") == .check)
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
        #expect(BoardCue.castle.rawValue == "castle")
        #expect(BoardCue.promote.rawValue == "promote")
        #expect(BoardCue.check.rawValue == "check")
        #expect(BoardCue.checkmate.rawValue == "checkmate")
        #expect(BoardCue.illegal.rawValue == "illegal")

        // Explicit raw values, not the case names: `gameStart` would put a capital in a filename,
        // and the matrix test below rejects those.
        #expect(BoardCue.gameStart.rawValue == "game-start")
        #expect(BoardCue.gameEnd.rawValue == "game-end")

    }

    /// Every filename a cue can ask the bundle for. **This is the list of `.wav` files that must
    /// exist**, and it is deliberately shorter than the cue list: nine cues, seven samples.
    ///
    /// Pinned on literals for the reason the raw values above are - these strings name files, so
    /// nothing in the app notices when one drifts. The symptom is silence, and silence is what an
    /// off toggle looks like too.
    @Test("The cues ask for exactly the seven samples that ship")
    func resourcesAreTheShippedSamples() {
        let required = Set(BoardCue.allCases.flatMap(\.resources))
        #expect(required == [
            "move", "capture", "castle", "check", "illegal", "game-start", "game-end",
        ])

        // Each name is a filename stem, so the same lexical rules apply as when they were half of
        // one: a capital or a space here is a missing file with a green build.
        for name in required {
            #expect(name == name.lowercased())
            #expect(!name.contains("_"))
            #expect(!name.contains(" "))
            #expect(!name.contains("."))
        }
    }

    /// The two composed cues, pinned because they are the whole reason `resources` is a list.
    ///
    /// `checkmate` layers the move and the game ending - a mate is both - and `promote` borrows
    /// the move sample outright. Asserted against other cases' `resources` rather than against
    /// string literals, so this keeps holding if the underlying files are ever renamed.
    @Test("Checkmate layers move and game-end; promotion borrows the move")
    func composedCuesAreSpelledOffTheirParts() {
        #expect(BoardCue.checkmate.resources == BoardCue.move.resources + BoardCue.gameEnd.resources)
        #expect(BoardCue.promote.resources == BoardCue.move.resources)

        // Everything else is exactly one sample named after itself. Written as the complement of
        // the two above so a third composed cue cannot be added without failing here first.
        for cue in BoardCue.allCases where cue != .checkmate && cue != .promote {
            #expect(cue.resources == [cue.rawValue], "\(cue) is no longer self-named")
        }
    }

    /// No cue is silent. A cue with an empty resource list compiles, renders a working toggle in
    /// Settings, and makes no sound - the exact failure that made a silent checkmate possible.
    @Test("Every cue names at least one sample", arguments: BoardCue.allCases)
    func noCueIsSilent(_ cue: BoardCue) {
        #expect(!cue.resources.isEmpty, "\(cue) would play nothing")
    }

    /// The cue order is a UI contract too: `SettingsView` lists its toggles in this order so the
    /// list teaches the precedence rule the footer states. Alphabetical would put Capture above
    /// Castle and Checkmate above Check, and the section would stop explaining itself.
    @Test("Cues are declared in precedence order, move family first")
    func cuesAreOrderedByPrecedence() {
        #expect(BoardCue.allCases == [
            .move, .capture, .castle, .promote, .check, .checkmate,
            .illegal, .gameStart, .gameEnd,
        ])
    }
}
