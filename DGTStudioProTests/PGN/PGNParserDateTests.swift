import Testing
import Foundation
@testable import DGTStudioPro

/// The timezone convention: **PGN dates are UTC calendar days** — parser and hash formatter
/// must agree on the zone or parse → hash-format stops round-tripping and dedupe silently breaks.
@Suite("PGN Parser — Date Tags")
struct PGNParserDateTests {
    
    /// 2026-05-28T00:00:00Z, computed independently of any formatter
    /// (56 years incl. 14 leap days to 2026-01-01, plus 147 days).
    private static let utcMidnight = Date(timeIntervalSince1970: 1_779_926_400)
    
    /// The pin itself: a date tag parses to UTC midnight of that day, on
    /// every machine, in every timezone.
    @Test func dateParsesAtUTCMidnight() {
        #expect(PGNParser.parseDate("2026.05.28") == Self.utcMidnight)
    }
    
    /// The invariant the dedup bug violated: parsing a date string and
    /// formatting it back with the hash's own convention (yyyy.MM.dd, UTC)
    /// must reproduce the original string exactly.
    @Test func parseRoundTripsThroughTheUTCHashConvention() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        for original in ["2026.05.28", "1999.12.31", "2026.01.01"] {
            let parsed = try #require(PGNParser.parseDate(original))
            #expect(formatter.string(from: parsed) == original)
        }
    }
    
    /// Unknown-date tags stay nil (unchanged behavior, pinned so the fix
    /// can't have widened what parses).
    @Test func unknownDatesStayNil() {
        #expect(PGNParser.parseDate("????.??.??") == nil)
        #expect(PGNParser.parseDate(nil) == nil)
    }

    /// A partially unknown date discards the known components too (`parseDate` refuses any `?`) —
    /// fine for the DGT ecosystem's full-or-unknown files.
    @Test(arguments: ["2026.??.??", "2026.05.??", "??26.05.15"])
    func partiallyUnknownDatesDiscardTheKnownComponents(raw: String) {
        #expect(PGNParser.parseDate(raw) == nil)
    }
}
