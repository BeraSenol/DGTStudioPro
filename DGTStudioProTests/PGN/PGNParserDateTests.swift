//
//  PGNParserDateTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 08/07/2026.
//

import Testing
import Foundation
@testable import DGTStudioPro

/// Pins the timezone convention for `[Date]` tags: **PGN dates are UTC
/// calendar days.** `PGNParser.parseDate` and `PGNStore`'s hash formatter
/// must agree on the zone, or parse → hash-format stops round-tripping and
/// one-hash/two-doors deduplication silently breaks — which is precisely
/// what happened before the pin: in any timezone east of UTC, an imported
/// "2026.05.28" parsed to *local* midnight (= May 27 in UTC) and
/// re-formatted as "2026.05.27", so a same-day archived twin never
/// deduplicated against its imported copy.
///
/// Nonisolated: `PGNParser` is stateless static parsing over value types.
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
}
