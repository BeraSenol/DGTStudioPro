import Testing
import Foundation
@testable import DGTStudioPro

/// The diagnostic timeline's observable contract: append order, the ring bound, desync capture.
/// `record` vs `capture` differ only in the Console mirror, which a unit test cannot see.
@MainActor
@Suite("DGT Session Log")
struct DGTSessionLogTests {

    /// Mirrors the type's private `maxEntries`. If that cap changes, this
    /// constant (and the eviction test) should change with it.
    private let cap = 2000

    // MARK: record / capture

    @Test func recordAppendsEntryWithLevelAndMessage() {
        let log = DGTSessionLog()
        log.record(.info, "connected")

        #expect(log.entries.count == 1)
        #expect(log.entries[0].level == .info)
        #expect(log.entries[0].message == "connected")
    }

    /// `capture` buffers without the Console mirror; its effect on `entries` is
    /// identical to `record` (the mirror is not unit-observable).
    @Test func captureAppendsEntryToBuffer() {
        let log = DGTSessionLog()
        log.capture(.debug, "settle: no change")

        #expect(log.entries.count == 1)
        #expect(log.entries[0].level == .debug)
        #expect(log.entries[0].message == "settle: no change")
    }

    @Test func entriesAreOldestFirst() {
        let log = DGTSessionLog()
        log.record(.info, "first")
        log.capture(.debug, "second")
        log.record(.error, "third")

        #expect(log.entries.map(\.message) == ["first", "second", "third"])
        #expect(log.entries.map(\.level) == [.info, .debug, .error])
    }

    @Test func clearEmptiesTheTimeline() {
        let log = DGTSessionLog()
        log.record(.info, "a")
        log.record(.info, "b")
        #expect(log.entries.count == 2)

        log.clear()
        #expect(log.entries.isEmpty)
    }

    // MARK: Ring Buffer

    /// Past the cap, the oldest entries are evicted first and the count holds
    /// steady at the cap. Appending `cap + 100` numbered entries must leave
    /// exactly `cap` of them — the most recent — with entry "100" now oldest.
    @Test func ringBufferEvictsOldestPastCap() {
        let log = DGTSessionLog()
        for i in 0..<(cap + 100) {
            log.record(.debug, "\(i)")
        }

        #expect(log.entries.count == cap)
        #expect(log.entries.first?.message == "100")   // 0...99 evicted
        #expect(log.entries.last?.message == "\(cap + 99)")
    }

    // MARK: recordDesync

    /// The headline capture: a multi-line block at `.error` level carrying the
    /// last legal FEN, side to move, the physical board, the diff, and recent
    /// moves. With no moves yet, the recent-moves line reads "(game start)".
    @Test func recordDesyncCapturesFullContextAtErrorLevel() {
        let log = DGTSessionLog()
        let before = GameState.starting

        log.recordDesync(before: before, physical: .starting, recentSAN: [], plyCount: 0)

        #expect(log.entries.count == 1)
        let entry = log.entries[0]
        #expect(entry.level == .error)
        #expect(entry.message.contains("DESYNC at ply 0"))
        #expect(entry.message.contains(FEN(before).string))   // last legal FEN, verbatim
        #expect(entry.message.contains("(game start)"))        // empty recentSAN
    }

    /// The recent-moves line is capped at the last eight SAN tokens. Given ten,
    /// the first two are dropped and the trailing eight appear in order.
    @Test func recordDesyncTruncatesToLastEightMoves() {
        let log = DGTSessionLog()
        let recent = ["Ra1", "Rb1", "Nc3", "Nd5", "Be2", "Bf4", "Qg4", "Kh1", "O-O-O", "Rd1"]

        log.recordDesync(before: .starting, physical: .starting, recentSAN: recent, plyCount: 10)

        let message = log.entries[0].message
        #expect(message.contains("Nc3 Nd5 Be2 Bf4 Qg4 Kh1 O-O-O Rd1"))
        #expect(!message.contains("Ra1"))   // dropped — only the last eight survive
        #expect(!message.contains("Rb1"))
    }

    // MARK: exportText

    @Test func exportTextOnEmptyLogReportsZeroEntries() {
        let log = DGTSessionLog()
        let text = log.exportText()

        #expect(text.contains("DGT Studio Pro Live Session Log"))
        #expect(text.contains("0 entries"))
    }

    /// One entry uses the singular "entry"; the word "entries" must not appear.
    @Test func exportTextUsesSingularForOneEntry() {
        let log = DGTSessionLog()
        log.record(.info, "only one")
        let text = log.exportText()

        #expect(text.contains("1 entry"))
        #expect(!text.contains("entries"))
    }

    /// Multiple entries pluralize, and each entry's message and uppercased
    /// level tag appear in the rendered output.
    @Test func exportTextPluralizesAndRendersEntries() {
        let log = DGTSessionLog()
        log.record(.info, "alpha")
        log.record(.error, "beta")
        let text = log.exportText()

        #expect(text.contains("2 entries"))
        #expect(text.contains("alpha"))
        #expect(text.contains("beta"))
        #expect(text.contains("[INFO]"))
        #expect(text.contains("[ERROR]"))
    }
}
