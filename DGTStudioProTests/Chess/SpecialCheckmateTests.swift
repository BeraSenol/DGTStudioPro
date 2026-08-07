import Testing
@testable import DGTStudioPro

/// The D19′ checkmate-type classifier, widened to ten motifs by D65′. Pure
/// over `GameState` — nonisolated, one FEN fixture per pattern.
///
/// **Every fixture below was checked against an independent move generator
/// before it landed here**, for legality and for actually being mate. A
/// hand-made mate position is the easiest thing in this domain to get subtly
/// wrong — a king that can still run, a "mate" the defender can block — and an
/// illegal or non-mate fixture makes a test meaningless rather than failing
/// loudly, since `classify` guards on `isCheckmate` and would return `nil` for
/// an honest reason.
@Suite("Special Checkmate — Classification")
struct SpecialCheckmateTests {

    private static func state(_ fen: String) throws -> GameState {
        try GameState(FEN(parsing: fen))
    }

    /// One fixture per motif, kept in one place because two tests read it: the
    /// per-motif expectations below, and `everyCaseIsProducible`.
    private static let fixtures: [(motif: SpecialCheckmate, fen: String)] = [
        (.smothered, "6rk/5Npp/8/8/8/8/8/6K1 b - - 0 1"),
        (.backRank,  "4R1k1/5ppp/8/8/8/8/8/6K1 b - - 0 1"),
        (.anastasia, "8/4N1pk/8/7R/8/8/8/K7 b - - 0 1"),
        (.arabian,   "7k/7R/5N2/8/8/8/8/K7 b - - 0 1"),
        (.opera,     "1n1Rkb1r/p4ppp/4q3/4p1B1/4P3/8/PPP2PPP/2K5 b k - 1 17"),
        (.boden,     "2kr4/3p4/B7/8/5B2/8/8/4K3 b - - 0 1"),
        (.epaulette, "3rkr2/8/4Q3/8/8/8/8/7K b - - 0 1"),
        (.gueridon,  "8/8/2r1r3/3k4/3Q4/3K4/8/8 b - - 0 1"),
        (.dovetail,  "8/8/3p4/2pk4/4Q3/5K2/8/8 b - - 0 1"),
        (.hook,      "8/7r/6Rk/8/5N2/6P1/8/K7 b - - 0 1"),
    ]

    // MARK: Display

    /// The tripwire for "simplify this to `rawValue.capitalized`", which would
    /// quietly rename `backRank` to "Backrank" and strip the accents off the
    /// two French names.
    @Test func displayNamesAreWrittenOut() {
        #expect(SpecialCheckmate.smothered.displayName == "Smothered")
        #expect(SpecialCheckmate.backRank.displayName  == "Back Rank")
        #expect(SpecialCheckmate.anastasia.displayName == "Anastasia's")
        #expect(SpecialCheckmate.arabian.displayName   == "Arabian")
        #expect(SpecialCheckmate.opera.displayName     == "Opera")
        #expect(SpecialCheckmate.boden.displayName     == "Boden's")
        #expect(SpecialCheckmate.epaulette.displayName == "Épaulette")
        #expect(SpecialCheckmate.gueridon.displayName  == "Guéridon")
        #expect(SpecialCheckmate.dovetail.displayName  == "Dovetail")
        #expect(SpecialCheckmate.hook.displayName      == "Hook")
    }

    /// Raw values ride `PGN.specialCheckmate` and every saved smart tag's rule
    /// blob, so a rename is a silent data migration (the D36′ trap). Asserted
    /// on literals, which is rare and correct here: nothing else in the app
    /// would notice if one moved, and the symptom would be a stored motif
    /// quietly failing to decode.
    @Test func rawValuesAreStoredState() {
        #expect(SpecialCheckmate.smothered.rawValue == "smothered")
        #expect(SpecialCheckmate.backRank.rawValue  == "backRank")
        #expect(SpecialCheckmate.anastasia.rawValue == "anastasia")
        #expect(SpecialCheckmate.arabian.rawValue   == "arabian")
        #expect(SpecialCheckmate.opera.rawValue     == "opera")
        #expect(SpecialCheckmate.boden.rawValue     == "boden")
        #expect(SpecialCheckmate.epaulette.rawValue == "epaulette")
        #expect(SpecialCheckmate.gueridon.rawValue  == "gueridon")
        #expect(SpecialCheckmate.dovetail.rawValue  == "dovetail")
        #expect(SpecialCheckmate.hook.rawValue      == "hook")
    }

    // MARK: Producibility

    /// **Every case can actually be classified.** The compiler already refuses
    /// a case with no recogniser (`matches` switches exhaustively) but has
    /// nothing to say about one missing from `precedence`, which would simply
    /// never fire.
    ///
    /// This is the D40′ rule pointed at an enum rather than at a `disabled(_:)`
    /// guard: a case nothing can produce is a stored value that can never
    /// appear, and it costs nothing at runtime, fails no build, and reads as
    /// considered. Adding a case without adding its fixture turns this red.
    @Test func everyCaseIsProducible() throws {
        var produced: Set<SpecialCheckmate> = []
        for fixture in Self.fixtures {
            produced.insert(try #require(SpecialCheckmate.classify(Self.state(fixture.fen))))
        }
        #expect(produced == Set(SpecialCheckmate.allCases))
    }

    @Test(arguments: fixtures)
    func fixtureClassifiesAsItsMotif(_ fixture: (motif: SpecialCheckmate, fen: String)) throws {
        #expect(SpecialCheckmate.classify(try Self.state(fixture.fen)) == fixture.motif)
    }

    // MARK: Smothered

    @Test func centralSmotheredMate() throws {
        // Ke4 walled on all eight sides by its own pawns; Nd6#. The corner
        // form is in `fixtures` — this one has no board edge helping.
        let state = try Self.state("8/8/3N4/3ppp2/3pkp2/3ppp2/8/K7 b - - 0 1")
        #expect(SpecialCheckmate.classify(state) == .smothered)
    }

    // MARK: Back rank

    @Test func queenBackRankMate() throws {
        // The `fixtures` entry is the rook; the same wall delivered along the
        // rank by a queen must read identically.
        let state = try Self.state("4Q1k1/5ppp/8/8/8/8/8/6K1 b - - 0 1")
        #expect(SpecialCheckmate.classify(state) == .backRank)
    }

    // MARK: Precedence — the overlapping pairs

    /// A corner rook mate whose knight is *also* pawn-defended satisfies both
    /// `arabian` and `hook`, and neither is a subset of the other. The corner
    /// wins, on the tie-break recorded at `precedence`.
    ///
    /// **This is the test to change if that call ever changes** — it is the
    /// only place the choice is observable, and it will fail loudly rather
    /// than the label quietly moving on games already in the Library.
    @Test func aCornerHookIsCalledArabian() throws {
        // Kh8, Rh7 defended by Nf6, which the g5 pawn defends in turn.
        let state = try Self.state("7k/6pR/5N2/6P1/8/8/8/K7 b - - 0 1")
        #expect(SpecialCheckmate.classify(state) == .arabian)
    }

    /// A bishop-supported rook beside the king on the back rank, with the king
    /// *also* walled by its own pawns — `opera` and `backRank` both hold, and
    /// the narrower name wins.
    @Test func aWalledOperaMateIsCalledOpera() throws {
        // Kg8 behind f7/g7/h7; Rf8 adjacent on the rank, defended by Bc5.
        let state = try Self.state("5Rk1/5ppp/8/2B5/8/8/8/K7 b - - 0 1")
        #expect(SpecialCheckmate.classify(state) == .opera)
    }

    /// The `gueridon`/`epaulette` boundary, which is one square wide. Ke8
    /// flanked by its own rooks *and* checked by an adjacent defended queen —
    /// so `gueridon` is tested first and asks for the two squares diagonally
    /// behind the king, which here are off the board. A wall is not a tail.
    @Test func aFlankedKingWithAnAdjacentQueenIsEpaulette() throws {
        let state = try Self.state("3rkr2/4Q3/8/8/8/8/8/4R2K b - - 0 1")
        #expect(SpecialCheckmate.classify(state) == .epaulette)
    }

    // MARK: Ordinary mates and non-mates

    /// The plain king-and-queen ending, which is the commonest mate there is
    /// and deliberately carries no motif. Qg7 is adjacent and defended — one
    /// condition short of a Dovetail — but the king has no men of its own
    /// behind it, and the tail is the pattern.
    ///
    /// Worth pinning because it is what stops the Players "Special Mates"
    /// count from becoming a count of decided games.
    @Test func theBasicQueenMateIsNotSpecial() throws {
        let state = try Self.state("7k/6Q1/6K1/8/8/8/8/8 b - - 0 1")
        #expect(SpecialCheckmate.classify(state) == nil)
    }

    @Test func foolsMateIsNotSpecial() throws {
        // A diagonal queen mate — not a knight (so not smothered), not along
        // the king's rank (so not back-rank), and the checker is a queen
        // rather than a bishop (so not Boden's).
        let state = try GameState.starting.replay(["f3", "e5", "g4", "Qh4#"])
        #expect(SpecialCheckmate.classify(state) == nil)
    }

    @Test func startingPositionIsNotAMate() {
        #expect(SpecialCheckmate.classify(.starting) == nil)
    }

    @Test func backRankShapeThatIsNotMateIsNil() throws {
        // Re8 checks, but with h7 empty the king escapes to h7 — not mate, so
        // no classification despite the back-rank shape (the `isCheckmate`
        // guard earns its keep).
        let state = try Self.state("4R1k1/5pp1/8/8/8/8/8/6K1 b - - 0 1")
        #expect(SpecialCheckmate.classify(state) == nil)
    }

    /// An edge-file king, a rook down the file, its own pawn beside it — an
    /// Anastasia's in every respect but the knight, which is the discriminant.
    /// Bf7 covers g8 and g6 exactly as Ne7 would, so the mate stands and the
    /// motif does not.
    @Test func aFileMateWithoutTheKnightIsNotAnastasia() throws {
        let state = try Self.state("8/5Bpk/8/7R/8/8/8/K7 b - - 0 1")
        #expect(SpecialCheckmate.classify(state) == nil)
    }
}
