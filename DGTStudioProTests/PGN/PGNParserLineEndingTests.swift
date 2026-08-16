import Foundation
import Testing
@testable import DGTStudioPro

/// Regression tests for line-ending handling. PGN files exported on Windows
/// (and by some DGT eBoard tooling) use CRLF; a `CharacterSet.newlines` split
/// turns each CRLF into two separators, injecting a spurious empty line that
/// the section splitter mistook for the end of the tag block - so every tag
/// after `Event` went missing. These pin that all three common line endings
/// parse identically.
@Suite("PGN Parser - Line Endings")
struct PGNParserLineEndingTests {

    /// A complete game with LF endings, used as the reference.
    private static let lfBody =
    "[Event \"DGT USB eBoard\"]\n" +
    "[Site \"Hasselt, Limburg BEL\"]\n" +
    "[Date \"2026.03.14\"]\n" +
    "[Round \"1\"]\n" +
    "[White \"Vanmullem, Marco\"]\n" +
    "[Black \"Senol, Bera\"]\n" +
    "[Result \"1-0\"]\n" +
    "[Board \"DGT 3000448278\"]\n" +
    "[TimeControl \"-\"]\n" +
    "\n" +
    "1. e4 c6 2. Qh5 Nf6 1-0\n"

    @Test func crlfHeadersParseAllTags() throws {
        let crlf = Self.lfBody.replacingOccurrences(of: "\n", with: "\r\n")
        let pgn = try PGNParser.parse(crlf)

        #expect(pgn.event == "DGT USB eBoard")
        #expect(pgn.white == "Vanmullem, Marco")
        #expect(pgn.black == "Senol, Bera")
        #expect(pgn.result == .whiteWins)
        #expect(pgn.round == 1)
        #expect(pgn.moves == ["e4", "c6", "Qh5", "Nf6"])
    }

    @Test func loneCarriageReturnsParseAllTags() throws {
        let cr = Self.lfBody.replacingOccurrences(of: "\n", with: "\r")
        let pgn = try PGNParser.parse(cr)

        #expect(pgn.white == "Vanmullem, Marco")
        #expect(pgn.result == .whiteWins)
        #expect(pgn.moves == ["e4", "c6", "Qh5", "Nf6"])
    }

    @Test func lfAndCrlfYieldIdenticalResults() throws {
        let lf = try PGNParser.parse(Self.lfBody)
        let crlf = try PGNParser.parse(
            Self.lfBody.replacingOccurrences(of: "\n", with: "\r\n")
        )

        #expect(lf.white == crlf.white)
        #expect(lf.black == crlf.black)
        #expect(lf.result == crlf.result)
        #expect(lf.moves == crlf.moves)
    }
}
