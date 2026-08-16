import Testing
@testable import DGTStudioPro

/// The opening classifier. Two halves, deliberately separated: the pure
/// walk over a five-row fixture (no bundle, nonisolated, the `Glicko1` /
/// `TagRule` shape), and a handful of spot checks against the real bundled
/// table guarded against vacuity - a missing resource must fail loudly here
/// rather than let the app quietly classify nothing, which is exactly the
/// failure mode "no opening found" is indistinguishable from in the UI.
@Suite("ECO - Classification")
struct ECOClassifierTests {

    // MARK: Fixture

    /// Deliberately shaped like the real table: a bare family, two depths of
    /// the same line, and a transposition into one of them.
    private static let fixture = ECOClassifier([
        (["e4", "e5"], ECOOpening(code: "C20", name: "King's Pawn Game")),
        (["e4", "e5", "Nf3", "Nc6"], ECOOpening(code: "C44", name: "King's Pawn Game: Knight Opening")),
        (["e4", "e5", "Nf3", "Nc6", "Bb5"], ECOOpening(code: "C60", name: "Ruy Lopez")),
        (["e4", "e5", "Nf3", "Nc6", "Bb5", "a6"], ECOOpening(code: "C68", name: "Ruy Lopez: Morphy Defense")),
        // The transposition shape the source adds duplicate rows for.
        (["Nf3", "Nc6", "e4", "e5"], ECOOpening(code: "C44", name: "King's Pawn Game: Knight Opening")),
        (["d4"], ECOOpening(code: "A40", name: "Queen's Pawn Game")),
        (["b4"], ECOOpening(code: "A00", name: "Polish Opening")),
    ])

    // MARK: The Walk

    @Test("The deepest matching line wins, not the first")
    func longestPrefixWins() {
        let ruy = Self.fixture.opening(for: ["e4", "e5", "Nf3", "Nc6", "Bb5"])
        #expect(ruy?.family == "Ruy Lopez")
        #expect(ruy?.code == "C60")
    }

    @Test("The match carries the book depth in plies")
    func matchCarriesTheMatchedLength() {
        let match = Self.fixture.match(
            for: ["e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "Ba4", "Nf6"]
        )
        #expect(match?.opening.code == "C68")
        // Six of the eight plies are book - the analysis skip starts at the seventh.
        #expect(match?.plies == 6)
    }

    @Test("A one-ply match reports depth one, not zero")
    func shallowMatchReportsItsOwnDepth() {
        let match = Self.fixture.match(for: ["d4", "d5"])
        #expect(match?.opening.code == "A40")
        #expect(match?.plies == 1)
    }

    @Test("A game deeper than the table keeps the deepest line it reached")
    func gameDeeperThanTableFallsBackToDeepestMatch() {
        let opening = Self.fixture.opening(
            for: ["e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "Ba4", "Nf6", "O-O", "Be7"]
        )
        #expect(opening?.variation == "Morphy Defense")
    }

    @Test("A prefix shorter than the deepest line still classifies")
    func shorterGameMatchesShorterLine() {
        #expect(Self.fixture.opening(for: ["e4", "e5"])?.code == "C20")
    }

    @Test("A transposed move order reaches the same name")
    func transpositionClassifies() {
        let direct = Self.fixture.opening(for: ["e4", "e5", "Nf3", "Nc6"])
        let transposed = Self.fixture.opening(for: ["Nf3", "Nc6", "e4", "e5"])
        #expect(direct == transposed)
    }

    @Test("An unplayed game and an unnamed first move classify as nothing")
    func noMatchClassifiesNil() {
        #expect(Self.fixture.opening(for: []) == nil)
        #expect(Self.fixture.opening(for: ["h4"]) == nil)
    }

    @Test("A duplicate line resolves first-wins rather than trapping")
    func duplicateLineTakesTheFirstEntry() {
        let classifier = ECOClassifier([
            (["e4"], ECOOpening(code: "B00", name: "King's Pawn Opening")),
            (["e4"], ECOOpening(code: "ZZZ", name: "Later Duplicate")),
        ])
        #expect(classifier.opening(for: ["e4"])?.code == "B00")
    }

    // MARK: The Fold

    @Test(
        "Check, mate and annotation suffixes fold on both sides",
        arguments: ["Bb5", "Bb5+", "Bb5!", "Bb5?", "Bb5+!", "Bb5#", "Bb5#!"]
    )
    func suffixesFoldOnBothSides(spelling: String) {
        let opening = Self.fixture.opening(for: ["e4", "e5", "Nf3", "Nc6", spelling])
        #expect(opening?.code == "C60")
    }

    /// The find this fold exists for: `GameState.parseSAN` accepts `0-0` and
    /// import stores SAN verbatim, so a game from a zero-writing producer
    /// would silently never classify past its castling move.
    @Test("Zero-form castling matches the table's letter form")
    func zeroFormCastlingFolds() {
        let classifier = ECOClassifier([
            (["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5", "O-O"], ECOOpening(code: "C50", name: "Italian Game")),
            (["d4", "d5", "Nc3", "Nf6", "Bf4", "e6", "Qd2", "Be7", "O-O-O"], ECOOpening(code: "D00", name: "Queen's Pawn: Long Castle")),
        ])
        #expect(
            classifier.opening(for: ["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5", "0-0"])?.code == "C50"
        )
        #expect(
            classifier.opening(
                for: ["d4", "d5", "Nc3", "Nf6", "Bf4", "e6", "Qd2", "Be7", "0-0-0"]
            )?.code == "D00"
        )
    }

    /// SAN is case-significant, so the fold must not reach for `lowercased()`
    /// the way the string fold does. This is the tripwire for that.
    @Test("Case is not folded - a bishop move and a b-pawn move stay distinct")
    func caseIsNotFolded() {
        let classifier = ECOClassifier([
            (["b4"], ECOOpening(code: "A00", name: "Polish Opening")),
        ])
        #expect(classifier.opening(for: ["B4"]) == nil)
    }

    // MARK: Name Splitting

    @Test("A name splits at its first colon")
    func nameSplitsAtFirstColon() {
        let opening = ECOOpening(
            code: "C18",
            name: "French Defense: Winawer Variation, Poisoned Pawn Variation"
        )
        #expect(opening.family == "French Defense")
        #expect(opening.variation == "Winawer Variation, Poisoned Pawn Variation")
    }

    @Test("A bare family name has no variation, and nil is the only spelling")
    func bareFamilyHasNilVariation() {
        #expect(ECOOpening(code: "C25", name: "Vienna Game").variation == nil)
        // A trailing colon must fold to nil too, not to "".
        #expect(ECOOpening(code: "C25", name: "Vienna Game:").variation == nil)
    }

    @Test("fullName is the inverse of the split")
    func fullNameRoundTrips() {
        for name in [
            "Vienna Game",
            "French Defense: Winawer Variation",
            "King's Gambit Accepted: Bishop's Gambit, Cozio Defense",
        ] {
            #expect(ECOOpening(code: "X00", name: name).fullName == name)
        }
    }
}

// MARK: - The Bundled Table

/// Spot checks against the real asset. Every expectation here is a line read
/// off the source file's own bytes, never inferred from a neighbour - the
/// standing rule about guessing an API name, applied to data.
@Suite("ECO - Bundled Table")
struct ECOTableTests {

    /// The vacuity guard. Without it every expectation below would pass
    /// trivially against an empty table if the resource ever fell out of the
    /// bundle - the M1 lesson, in the shape this feature can fail.
    private func loadedTable() throws -> ECOClassifier {
        let table = ECOTable.bundled
        // Probed with `1. e4 e6`, a row read off the source file's bytes -
        // not `1. e4` alone, whose presence would be an assumption about a
        // line nobody has looked at.
        try #require(
            table.opening(for: ["e4", "e6"]) != nil,
            """
            The bundled ECO table classifies nothing - the eco-a…eco-e.tsv \
            resources are missing from the app bundle, and every classification \
            expectation below would pass vacuously against it.
            """
        )
        return table
    }

    @Test("Known families classify from the real table")
    func knownFamiliesClassify() throws {
        let table = try loadedTable()

        let french = table.opening(for: ["e4", "e6"])
        #expect(french?.code == "C00")
        #expect(french?.family == "French Defense")

        let kingsGambit = table.opening(for: ["e4", "e5", "f4"])
        #expect(kingsGambit?.code == "C30")
        #expect(kingsGambit?.family == "King's Gambit")

        let vienna = table.opening(for: ["e4", "e5", "Nc3"])
        #expect(vienna?.code == "C25")
        #expect(vienna?.family == "Vienna Game")
    }

    @Test("A variation splits out of the real table's name")
    func realTableNameSplits() throws {
        let berlin = try loadedTable().opening(for: ["e4", "e5", "Bc4", "Nf6"])
        #expect(berlin?.code == "C24")
        #expect(berlin?.family == "Bishop's Opening")
        #expect(berlin?.variation == "Berlin Defense")
    }

    /// Longest-prefix against real data: both lines are in the table, and the
    /// deeper game must not stop at the shallower name.
    @Test("Longest prefix holds on the real table")
    func realTableLongestPrefix() throws {
        let table = try loadedTable()
        let gambit = table.opening(for: ["e4", "e5", "Nc3", "Nf6", "f4"])
        #expect(gambit?.variation == "Vienna Gambit")

        let mainLine = table.opening(for: ["e4", "e5", "Nc3", "Nf6", "f4", "d5"])
        #expect(mainLine?.variation == "Vienna Gambit, Main Line")
    }

    @Test("The Ruy Lopez classifies - the milestone's own gate sentence")
    func ruyLopezClassifies() throws {
        let ruy = try loadedTable().opening(for: ["e4", "e5", "Nf3", "Nc6", "Bb5"])
        #expect(ruy?.code == "C60")
        #expect(ruy?.family == "Ruy Lopez")
        #expect(ruy?.variation == nil)
    }

    /// One row per volume, because the single probe in ``loadedTable()``
    /// cannot tell a fully bundled table from one where only `eco-c.tsv`
    /// made it into Resources - the C-volume expectations above would all
    /// still pass, and every English, Sicilian, Slav and Nimzo-Indian in the
    /// Library would quietly classify as nothing.
    @Test(
        "All five volumes are bundled",
        arguments: [
            (["c4"], "A10", "English Opening"),
            (["e4", "c5"], "B20", "Sicilian Defense"),
            (["e4", "e6"], "C00", "French Defense"),
            (["d4", "d5", "c4"], "D06", "Queen's Gambit"),
            (["d4", "Nf6", "c4", "e6", "Nc3", "Bb4"], "E20", "Nimzo-Indian Defense"),
        ]
    )
    func everyVolumeLoads(moves: [String], code: String, family: String) throws {
        let opening = try loadedTable().opening(for: moves)
        #expect(opening?.code == code)
        #expect(opening?.family == family)
    }
}
