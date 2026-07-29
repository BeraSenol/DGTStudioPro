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
}
