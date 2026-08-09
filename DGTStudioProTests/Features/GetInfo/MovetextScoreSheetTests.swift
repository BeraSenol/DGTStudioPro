import Testing
@testable import DGTStudioPro

/// The score-sheet rendering. Nonisolated (compile-time witness it stays pure). The round trip
/// is asserted against the **real tokenizer**, not a literal — numbers and padding must be
/// decoration the validator never sees.
@Suite("Movetext score sheet")
struct MovetextScoreSheetTests {

    // MARK: Shape

    @Test func emptyMovetextRendersEmpty() {
        #expect(MovetextEditorView.scoreSheet([]) == "")
    }

    /// One line per full move, White then Black.
    @Test func pairsPliesOntoNumberedLines() {
        let sheet = MovetextEditorView.scoreSheet(["e4", "e5", "Nf3", "Nc6"])
        let lines = sheet.split(separator: "\n").map(String.init)

        #expect(lines.count == 2)
        #expect(lines[0].contains("1."))
        #expect(lines[0].contains("e4"))
        #expect(lines[0].contains("e5"))
        #expect(lines[1].contains("2."))
        #expect(lines[1].contains("Nc6"))
    }

    /// A game ending on White's move gets a white-only final line — the shape
    /// D24′ writes to disk, arrived at here independently because it is what a
    /// score sheet does.
    @Test func oddPlyCountEndsOnAWhiteOnlyLine() {
        let sheet = MovetextEditorView.scoreSheet(["e4", "e5", "Nf3"])
        let lines = sheet.split(separator: "\n").map(String.init)

        #expect(lines.count == 2)
        // `drop(while:)` rather than `trimmingCharacters(in:)`: that one is
        // Foundation, and this target enables `MemberImportVisibility`, so it
        // would not arrive through `Testing`.
        #expect(String(lines[1].drop(while: { $0 == " " })) == "2.  Nf3")
    }

    // MARK: Alignment

    /// Numbers right-align, so a game reaching move 10 does not shunt its first
    /// nine rows one column left.
    @Test func moveNumbersRightAlign() {
        let moves = [String](repeating: "e4", count: 20)   // 10 full moves
        let lines = MovetextEditorView.scoreSheet(moves)
            .split(separator: "\n").map(String.init)

        // The leading space on line 1 is the whole claim: without it, move 10
        // would shunt the first nine rows one column left.
        #expect(lines.first?.hasPrefix(" 1.") == true)
        #expect(lines.last?.hasPrefix("10.") == true)
        #expect(Set(lines.map(\.count)).count == 1, "every row is the same width")
    }

    /// The **widest** ply governs the column, so one long move does not knock
    /// its own row's Black move out of line with every other row's.
    @Test func theWidestPlyGovernsTheColumn() throws {
        let lines = MovetextEditorView.scoreSheet(["e4", "e5", "Qa1xd4#", "Nc6"])
            .split(separator: "\n").map(String.init)

        // `firstRange(of:)` is stdlib; `range(of:)` is Foundation's.
        let firstBlack = try #require(lines[0].firstRange(of: "e5"))
        let secondBlack = try #require(lines[1].firstRange(of: "Nc6"))
        #expect(
            lines[0].distance(from: lines[0].startIndex, to: firstBlack.lowerBound)
            == lines[1].distance(from: lines[1].startIndex, to: secondBlack.lowerBound)
        )
    }

    // MARK: The round trip — the claim the feature rests on

    /// Everything the sheet adds is invisible to the validator — if this fails, the editor seeds
    /// text its own Save would refuse.
    @Test func theRenderedSheetTokenizesBackToExactlyTheInputPlies() throws {
        let moves = ["e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "O-O", "Qa1xd4#"]

        let sheet = MovetextEditorView.scoreSheet(moves)
        let tokens = try MovetextEdit.tokenize(sheet)

        #expect(tokens == moves)
    }

    /// And the same for the odd-ply shape, which is the arm with a different
    /// line format and therefore the one a change would break separately.
    @Test func theWhiteOnlyFinalLineAlsoRoundTrips() throws {
        let moves = ["d4", "d5", "c4"]
        #expect(try MovetextEdit.tokenize(MovetextEditorView.scoreSheet(moves)) == moves)
    }

    /// Wrong numbers are harmless, which is the property that lets the sheet be
    /// decoration rather than data. Renumbering nonsense still tokenizes to the
    /// same plies — so a mid-game deletion leaving stale numbers cannot make an
    /// otherwise-legal game fail to validate.
    @Test func wrongMoveNumbersDoNotAffectTokenization() throws {
        let nonsense = "99.  e4   e5\n 7.  Nf3  Nc6"
        #expect(try MovetextEdit.tokenize(nonsense) == ["e4", "e5", "Nf3", "Nc6"])
    }
}
