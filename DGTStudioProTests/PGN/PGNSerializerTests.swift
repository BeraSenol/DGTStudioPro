//
//  PGNSerializerTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 29/07/2026.
//

import Testing
import Foundation
@testable import DGTStudioPro

/// The D24′ witness (M1 item 14): export is byte-pinned to the three DGT
/// reference files the app actually interchanges — their *real bytes*,
/// bundled beside this file as test resources, never a transcription.
/// (The 28 July suite this re-lands was a transcription; its own header
/// asked for the true files to replace it. They have.)
///
/// Each game round-trips import → `pgn.pgnText` — the exporter's exact
/// production path (`PGN+Export`) — and must come back identical, byte
/// for byte: LF endings, nine tags in fixed order, one full move per
/// line with a white-only final line when the game ends on White's move,
/// the result alone at the end, one trailing newline, no wrapping, no
/// `[%eval]` comments. This restores the `PGNExporter` waiver's witness:
/// every byte the exporter writes comes from `PGNSerializer` (register),
/// so pinning the serializer against the reference bytes IS the export
/// contract, minus the save panel.
@Suite("PGN Serializer — Reference Bytes")
struct PGNSerializerTests {

    /// Swift Testing suites are structs; `Bundle(for:)` needs a class to
    /// anchor the test-bundle lookup.
    private final class BundleLocator {}

    private func referenceText(_ name: String) throws -> String {
        let url = try #require(
            Bundle(for: BundleLocator.self).url(forResource: name, withExtension: "pgn"),
            "Reference file '\(name).pgn' missing from the test bundle — the synchronized test folder should carry it as a resource"
        )
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: Round Trip

    /// Import → export must reproduce the reference file exactly. One
    /// expression per file pins the whole contract: any drift in tag
    /// order, unknown vocabulary, movetext lining, line endings, or the
    /// trailing newline surfaces as a byte diff here.
    @Test(arguments: [
        "1. Bera vs Reinaud",
        "2. Christophe vs Reinaud",
        "3. Christophe vs Bera",
    ])
    func referenceFileRoundTripsByteForByte(name: String) throws {
        let original = try referenceText(name)
        let pgn = try PGNParser.parse(original)
        #expect(pgn.pgnText == original,
                "Round trip of '\(name).pgn' drifted from the reference bytes")
    }

    // MARK: Reference Spot Checks

    /// A few parsed values pinned by eye against the file, so a green
    /// round trip can't be two mirrored errors cancelling out (parse and
    /// serialize wrong in the same way).
    @Test func referenceOneParsesTheKnownRoster() throws {
        let pgn = try PGNParser.parse(try referenceText("1. Bera vs Reinaud"))
        #expect(pgn.white == "Senol, Bera")
        #expect(pgn.black == "Brouns, Reinaud")
        #expect(pgn.result == .blackWins)
        #expect(pgn.board == "DGT 3000448278")
        #expect(pgn.round == 1)
        #expect(pgn.moves.count == 42)
        #expect(pgn.moves.last == "Qxg2#", "Mate suffix survives import verbatim")
    }

    /// File 2 ends on White's 39th — the white-only-final-line case the
    /// serializer's movetext doc names.
    @Test func referenceTwoEndsOnWhitesMove() throws {
        let pgn = try PGNParser.parse(try referenceText("2. Christophe vs Reinaud"))
        #expect(pgn.moves.count == 77)
        #expect(pgn.moves.count % 2 == 1)
        #expect(pgn.moves.last == "Qxe1")
        #expect(pgn.result == .whiteWins)
    }

    /// File 3 carries both promotion shapes — an underpromotion capture
    /// and a queening with check — which must survive storage verbatim:
    /// the parser strips only `!`/`?`, and export re-emits stored moves.
    @Test func referenceThreeKeepsPromotionSuffixesVerbatim() throws {
        let pgn = try PGNParser.parse(try referenceText("3. Christophe vs Bera"))
        #expect(pgn.moves.contains("cxd1=N"))
        #expect(pgn.moves.contains("a8=Q+"))
    }

    // MARK: Filename

    /// `1. Bera vs Reinaud.pgn` — ordinal within the export, then the two
    /// players' *given* names, White vs Black (D24′; given names are what
    /// the reference files do — over-the-board opponents are first names).
    @Test func fileNameMatchesTheReferenceShape() {
        #expect(
            PGNSerializer.fileName(white: "Senol, Bera", black: "Brouns, Reinaud", index: 1)
            == "1. Bera vs Reinaud.pgn"
        )
        #expect(
            PGNSerializer.fileName(white: "Heylen, Christophe", black: "Senol, Bera", index: 3)
            == "3. Christophe vs Bera.pgn"
        )
    }

    /// An empty seat falls back to `?` rather than collapsing the name
    /// into " vs "; `/` and `:` sanitize to `-` so two players differing
    /// only there can't collide in a folder.
    @Test func fileNameFallbacksAndSanitization() {
        #expect(
            PGNSerializer.fileName(white: "", black: "Brouns, Reinaud", index: 2)
            == "2. ? vs Reinaud.pgn"
        )
        #expect(
            PGNSerializer.fileName(white: "Smith, A/B", black: "Jones, C:D", index: 1)
            == "1. A-B vs C-D.pgn"
        )
    }

    // MARK: Library Index — The Reader Half (D58′)

    /// The real shape this exists for: the folder on disk numbers every game,
    /// and uses **full display names** where the app's writer uses given names.
    /// Both must read, which is why only the ordinal is parsed.
    @Test func readsTheOrdinalOffTheFolderConvention() {
        #expect(
            PGNSerializer.libraryIndex(
                fromFileName: "47. Bera Senol vs Christophe Heylen.pgn"
            ) == 47
        )
        #expect(
            PGNSerializer.libraryIndex(fromFileName: "1. Bera vs Reinaud.pgn") == 1
        )
        #expect(
            PGNSerializer.libraryIndex(
                fromFileName: "1284. Bera Senol vs Lorenzo Reinaud.pgn"
            ) == 1284
        )
    }

    /// The writer and the reader are one convention, so this asserts the reader
    /// against **the writer's own output** rather than against a literal.
    ///
    /// A literal would keep passing while the two drifted — the exact failure
    /// the assert-against-the-shared-source rule exists for, and the one that
    /// matters most here because these two functions sit twenty lines apart and
    /// look independent. Walks a range rather than sampling: the parse reads a
    /// digit *prefix*, so a one-digit case cannot catch a boundary a four-digit
    /// case would.
    @Test func writerAndReaderRoundTripAcrossMagnitudes() {
        for index in [1, 9, 10, 99, 100, 1_284, 10_000] {
            let name = PGNSerializer.fileName(
                white: "Senol, Bera", black: "Heylen, Christophe", index: index
            )
            #expect(
                PGNSerializer.libraryIndex(fromFileName: name) == index,
                "round trip broke at \(index) via '\(name)'"
            )
        }
    }

    /// No ordinal is a fact about the file, not an error — and the period is
    /// what separates the two "no ordinal" cases from a real one.
    ///
    /// `1961 Candidates.pgn` is the case the guard exists for: digits with no
    /// period after them are a *year in a title*, and reading it as game 1961
    /// would silently file a whole tournament's games under invented numbers
    /// near the top of the run.
    @Test func unnumberedFilesReadAsNil() {
        #expect(PGNSerializer.libraryIndex(fromFileName: "Carlsen-Nepo.pgn") == nil)
        #expect(PGNSerializer.libraryIndex(fromFileName: "1961 Candidates.pgn") == nil)
        #expect(PGNSerializer.libraryIndex(fromFileName: ".pgn") == nil)
        #expect(PGNSerializer.libraryIndex(fromFileName: "") == nil)
    }

    /// A game carrying an index exports under **it**, not under its position in
    /// the batch; a game without one falls back to the position (D58′).
    ///
    /// The pair is the point: asserting only the first would pass on an
    /// implementation that ignored the parameter entirely.
    @Test func exportNameUsesTheLibraryIndexWhenThereIsOne() {
        let numbered = PGN(
            white: "Senol, Bera", black: "Heylen, Christophe", result: .whiteWins
        )
        numbered.libraryIndex = 47
        #expect(numbered.exportFileName(index: 2) == "47. Bera vs Christophe.pgn")

        let unnumbered = PGN(
            white: "Senol, Bera", black: "Heylen, Christophe", result: .whiteWins
        )
        #expect(unnumbered.exportFileName(index: 2) == "2. Bera vs Christophe.pgn")
    }

    // (The hash-exclusion pin is deliberately *not* here. `contentHash(for:)`
    // is private to `PGNStore`, and reaching it would mean widening a door to
    // suit a test. It lives in `PGNStoreRetagTests` as the behaviour instead —
    // two differently-numbered copies of one game dedupe — which is the
    // stronger claim anyway: it asserts the consequence rather than the digest.)

    // MARK: The Constant Nine-Tag Shape

    /// A game that knows nothing still exports all nine tag lines — PGN's
    /// own unknown vocabulary (`?`, `????.??.??`), `-` for no time
    /// control, `*` for no result — so the tag block is a constant shape
    /// (D24′). `PGN()` bare *is* the all-unknown game (every init
    /// parameter defaults to its unknown), and zero moves emit no
    /// movetext lines while the blank line and result still stand.
    @Test func unknownEverythingStillExportsNineTags() {
        let expected = [
            "[Event \"?\"]",
            "[Site \"?\"]",
            "[Date \"????.??.??\"]",
            "[Round \"?\"]",
            "[White \"?\"]",
            "[Black \"?\"]",
            "[Result \"*\"]",
            "[Board \"?\"]",
            "[TimeControl \"-\"]",
            "",
            "*",
            "",
        ].joined(separator: "\n")
        #expect(PGN().pgnText == expected)
    }

    // MARK: Archive-Shaped Export (M2 gate)

    /// The M2 gate sentence, as bytes: a game shaped like the archive door
    /// now produces it — tag-form seats from the D29′ picker, a real board
    /// identity from the D28′ stamp — exports `[White "Senol, Bera"]` and
    /// `[Board "DGT …"]`, not display names and not `?`. The reference
    /// round-trips prove the same for imported files; this pins it for the
    /// app's own archives, which never pass through the parser.
    @Test func archiveShapedGameExportsTagFormAndBoard() {
        let pgn = PGN(
            event: "Casual Game",
            site: "Home",
            date: nil,
            round: 4,
            white: "Senol, Bera",
            black: "Brouns, Reinaud",
            moves: ["e4", "c6"],
            result: .whiteWins,
            board: "DGT 3000448278"
        )
        let text = pgn.pgnText

        #expect(text.contains("[White \"Senol, Bera\"]"))
        #expect(text.contains("[Black \"Brouns, Reinaud\"]"))
        #expect(text.contains("[Board \"DGT 3000448278\"]"))
        #expect(!text.contains("[Board \"?\"]"))
    }
}
