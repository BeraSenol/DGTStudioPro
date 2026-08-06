import Testing
import Foundation
@testable import DGTStudioPro

/// Pins the two pure halves of Syzygy support: what the app *tells* the engine,
/// and what it *reads back* from it.
///
/// Nonisolated — both subjects are value-typed folds with no actor and no
/// subprocess. `StockfishEngine.tablebaseReport(in:)` is `static nonisolated`
/// precisely so it can be tested here rather than behind a live engine, which
/// is the difference between a check that runs on every ⌘U and one that runs
/// when somebody remembers to plug a folder in.
@Suite("Syzygy — Options and Report")
struct SyzygyConfigurationTests {

    // MARK: Option Emission

    /// **The default configuration says nothing about tablebases at all**, and
    /// this is the assertion that keeps it that way. Four `setoption` lines for
    /// a feature nobody switched on would be noise in every UCI log — and worse,
    /// `SyzygyProbeLimit` sent to an engine with no tables reads, to anyone
    /// grepping the log later, like tablebases are configured.
    @Test("With no folder, no Syzygy options are sent")
    func silentWithoutAPath() {
        let lines = EngineConfiguration.default.uciOptionLines
        #expect(lines.count == 2)
        #expect(!lines.contains { $0.contains("Syzygy") })
    }

    /// All four, and `SyzygyPath` **last**. Stockfish loads the tables when the
    /// path arrives and answers with its `info string`; sending it after the
    /// probe options keeps that answer as the final line of the block. Asserted
    /// on position rather than membership, because membership would pass with
    /// the order reversed and the ordering is the part with a reason.
    @Test("With a folder, all four go out and the path goes last")
    func emitsAllFourWithPathLast() {
        let config = EngineConfiguration(
            depth: 20, hashMB: 1024, threads: 12,
            syzygyPath: "/Volumes/Chess/syzygy",
            syzygyProbeDepth: 3,
            syzygy50MoveRule: false,
            syzygyProbeLimit: 6
        )
        let lines = config.uciOptionLines

        #expect(lines.count == 6)
        #expect(lines.contains("setoption name SyzygyProbeDepth value 3"))
        #expect(lines.contains("setoption name Syzygy50MoveRule value false"))
        #expect(lines.contains("setoption name SyzygyProbeLimit value 6"))
        #expect(lines.last == "setoption name SyzygyPath value /Volumes/Chess/syzygy")
    }

    /// An empty or whitespace path is the same state as no path.
    ///
    /// Not pedantry: `setoption name SyzygyPath value ` with nothing after it is
    /// a command Stockfish accepts and reads as "forget the tables". Letting
    /// `""` through would give "no tablebases" two spellings, one of which
    /// emits four lines and one of which emits none.
    @Test(
        "An empty path is no path",
        arguments: ["", "   ", "\n"]
    )
    func emptyPathFoldsToNone(path: String) {
        let config = EngineConfiguration(
            depth: 18, hashMB: 128, threads: 1, syzygyPath: path
        )
        #expect(config.syzygyPath == nil)
        #expect(!config.uciOptionLines.contains { $0.contains("Syzygy") })
    }

    /// Clamped against the ranges Stockfish itself advertises, so a hand-edited
    /// plist cannot push the engine outside them — the contract the depth and
    /// threads values already have, extended rather than restated.
    @Test("Probe depth and limit clamp to Stockfish's own ranges")
    func clampsProbeValues() {
        let low = EngineConfiguration(
            depth: 18, hashMB: 128, threads: 1,
            syzygyPath: "/tb", syzygyProbeDepth: -5, syzygyProbeLimit: -1
        )
        #expect(low.syzygyProbeDepth == 1)
        #expect(low.syzygyProbeLimit == 0)

        let high = EngineConfiguration(
            depth: 18, hashMB: 128, threads: 1,
            syzygyPath: "/tb", syzygyProbeDepth: 999, syzygyProbeLimit: 99
        )
        #expect(high.syzygyProbeDepth == 100)
        #expect(high.syzygyProbeLimit == 7)
    }

    /// Zero is a real setting, not a floor to clamp away: it disables probing
    /// while keeping the folder configured, which is the A/B you want when
    /// asking whether the tables are helping.
    @Test("A probe limit of zero survives")
    func zeroProbeLimitIsAllowed() {
        let config = EngineConfiguration(
            depth: 18, hashMB: 128, threads: 1,
            syzygyPath: "/tb", syzygyProbeLimit: 0
        )
        #expect(config.syzygyProbeLimit == 0)
        #expect(config.uciOptionLines.contains("setoption name SyzygyProbeLimit value 0"))
    }

    // MARK: Report Parsing

    /// **Both wordings, because Stockfish has already changed this once.**
    /// Builds up to roughly Stockfish 15 said "Found 145 tablebases"; current
    /// ones say "Found 145 WDL and 145 DTZ tablebase files (up to 5-man)". The
    /// matcher keys on "Found" plus "tablebase", which both contain — and this
    /// test is what stops someone tightening it to one exact sentence.
    ///
    /// The figures are the real ones (145 material configurations up to five
    /// men, 510 up to six) so a reader can tell a plausible fixture from an
    /// invented one. Nothing asserts on them — the matcher parses no count,
    /// deliberately.
    @Test(
        "Both known report wordings are recognised",
        arguments: [
            "info string Found 145 tablebases",
            "info string Found 145 WDL and 145 DTZ tablebase files (up to 5-man)",
            "info string Found 510 WDL and 510 DTZ tablebase files (up to 6-man)",
        ]
    )
    func recognisesReportWordings(line: String) {
        let report = StockfishEngine.tablebaseReport(in: line)
        #expect(report != nil)
        #expect(report?.hasPrefix("Found") == true)
    }

    /// The report is stored without its protocol prefix, so what Settings shows
    /// is the engine's sentence rather than a line of UCI.
    @Test("The report drops the info string prefix and keeps the rest verbatim")
    func stripsThePrefixOnly() {
        let line = "info string Found 145 WDL and 145 DTZ tablebase files (up to 5-man)"
        #expect(
            StockfishEngine.tablebaseReport(in: line)
            == "Found 145 WDL and 145 DTZ tablebase files (up to 5-man)"
        )
    }

    /// Every other `info string` this engine emits must not match — these are
    /// the exact lines a real start prints, taken from a session log. Without
    /// this, a matcher loose enough to catch both wordings is also loose enough
    /// to report "Using 12 threads" as a tablebase count.
    @Test(
        "Ordinary engine chatter is not a tablebase report",
        arguments: [
            "info string Available processors: 0-11",
            "info string Using 12 threads",
            "info string NNUE evaluation using nn-c288c895ea92.nnue (125MiB, (102384, 1024, 15, 32, 1))",
            "info string Network replica 1: Local memory. Shared memory not supported by the OS.",
            "info depth 20 seldepth 50 multipv 1 score cp -37 nodes 4759383 nps 8039498",
            "bestmove e7e5 ponder g1f3",
            "",
        ]
    )
    func ignoresEverythingElse(line: String) {
        #expect(StockfishEngine.tablebaseReport(in: line) == nil)
    }

    /// The near-miss worth pinning: a line that says "Found" about something
    /// that is not a tablebase. No shipped Stockfish prints this, which is why
    /// it is here — the matcher's second term is doing work that no real log
    /// would demonstrate.
    @Test("\"Found\" alone is not enough")
    func requiresBothTerms() {
        #expect(StockfishEngine.tablebaseReport(in: "info string Found 4 NUMA nodes") == nil)
    }
}
