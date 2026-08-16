import Testing
import Foundation
@testable import DGTStudioPro

/// Integration tests need a real bundled Stockfish (Engine_README.md), conditionally enabled.
@Suite("Stockfish Engine Integration")
struct StockfishEngineTests {

    private static var stockfishAvailable: Bool {
        StockfishEngine.defaultBinaryURL != nil
    }

    /// 60 s: `readyok` lands after the Hash allocation - the one step a saturated ⌘U host slows
    /// arbitrarily. The dead-binary contract stays pinned separately.
    private static let handshakeTimeout: Duration = .seconds(60)

    // MARK: Lifecycle

    @Test(.enabled(if: stockfishAvailable))
    func startsAndIdentifiesEngine() async throws {
        let url = try #require(StockfishEngine.defaultBinaryURL)
        let engine = StockfishEngine(binaryURL: url)

        try await engine.start(handshakeTimeout: Self.handshakeTimeout)

        let name = await engine.engineName
        let author = await engine.engineAuthor

        #expect(name != nil, "Engine should have reported its name during handshake")
        #expect(name?.lowercased().contains("stockfish") == true,
                "Engine name should mention Stockfish; got \(String(describing: name))")
        #expect(author != nil, "Engine should have reported its author during handshake")
    }

    @Test(.enabled(if: stockfishAvailable))
    func reportsRunningStateCorrectly() async throws {
        let url = try #require(StockfishEngine.defaultBinaryURL)
        let engine = StockfishEngine(binaryURL: url)

        let runningBeforeStart = await engine.isRunning
        #expect(runningBeforeStart == false)

        try await engine.start(handshakeTimeout: Self.handshakeTimeout)
        let runningAfterStart = await engine.isRunning
        #expect(runningAfterStart == true)

        await engine.shutdown()
        let runningAfterShutdown = await engine.isRunning
        #expect(runningAfterShutdown == false)
    }

    @Test(.enabled(if: stockfishAvailable))
    func doubleStartThrows() async throws {
        let url = try #require(StockfishEngine.defaultBinaryURL)
        let engine = StockfishEngine(binaryURL: url)

        try await engine.start(handshakeTimeout: Self.handshakeTimeout)
        defer { Task { await engine.shutdown() } }

        await #expect(throws: StockfishEngine.EngineError.alreadyStarted) {
            try await engine.start()
        }
    }

    // MARK: Analysis

    @Test(.enabled(if: stockfishAvailable))
    func analyzesStartingPositionToReasonableEval() async throws {
        let url = try #require(StockfishEngine.defaultBinaryURL)
        let engine = StockfishEngine(binaryURL: url)
        try await engine.start(handshakeTimeout: Self.handshakeTimeout)
        defer { Task { await engine.shutdown() } }

        let stream = engine.analyze(fen: .starting, depth: 10)
        var lastEval: Evaluation?
        var yieldCount = 0
        // `.evaluation` off `EngineProgress` since 6 Aug 2026 - the stream
        // carries depth, nodes and speed alongside the score now, because the
        // queue window shows the search rather than only its answer. These
        // suites still assert the score, which is what they were written about.
        for await progress in stream {
            lastEval = progress.evaluation
            yieldCount += 1
        }

        #expect(yieldCount > 0, "Engine should yield at least one evaluation")
        let final = try #require(lastEval)

        // Starting position is theoretically slightly white-favored but
        // any sub-pawn evaluation is reasonable. A mate evaluation here
        // would indicate something is very wrong.
        switch final {
        case .centipawns(let cp):
            #expect(abs(cp) < 100,
                    "Expected near-drawn starting evaluation, got \(cp)cp")
        case .mate:
            Issue.record("Mate evaluation in starting position is impossible")
        }
    }

    @Test(.enabled(if: stockfishAvailable))
    func analyzesObviouslyLostPositionAsBlackAdvantage() async throws {
        // Queen odds over a hand-built tactic: a composed middlegame can quietly refute its own
        // premise; a missing queen leaves material as the only verdict.
        let url = try #require(StockfishEngine.defaultBinaryURL)
        let engine = StockfishEngine(binaryURL: url)
        try await engine.start()
        defer { Task { await engine.shutdown() } }

        let fen = try FEN(parsing:
                            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNB1KBNR w KQkq -"
        )

        let stream = engine.analyze(fen: fen, depth: 10)
        var lastEval: Evaluation?
        for await progress in stream {
            lastEval = progress.evaluation
        }

        let final = try #require(lastEval)
        switch final {
        case .centipawns(let cp):
            // White is down acon queen against a normal black setup;
            // expect strongly negative eval (deep into black's favor).
            #expect(cp < -500, "Expected strong black advantage, got \(cp)cp")
        case .mate(let n):
            // A forced mate against white is also fine here.
            #expect(n < 0, "Mate should favor black, got mate(\(n))")
        }
    }

    @Test(.enabled(if: stockfishAvailable))
    func sequentialAnalysesEachCompleteCleanly() async throws {
        // Verifies the actor handles back-to-back analyses without
        // leaking state between them.
        let url = try #require(StockfishEngine.defaultBinaryURL)
        let engine = StockfishEngine(binaryURL: url)
        try await engine.start(handshakeTimeout: Self.handshakeTimeout)
        defer { Task { await engine.shutdown() } }

        for _ in 0..<3 {
            let stream = engine.analyze(fen: .starting, depth: 6)
            var yieldCount = 0
            for await _ in stream {
                yieldCount += 1
            }
            #expect(yieldCount > 0, "Each analysis should yield at least once")
        }
    }

    /// The stale-`bestmove` guard (M1 item 8): a replaced search's hurried reply lands after the
    /// replacement's `go` and must not finish the stream it never belonged to. Deterministic - not a race.
    @Test(.enabled(if: stockfishAvailable))
    func replacementAnalysisSurvivesStaleBestMove() async throws {
        let url = try #require(StockfishEngine.defaultBinaryURL)
        let engine = StockfishEngine(binaryURL: url)
        try await engine.start(handshakeTimeout: Self.handshakeTimeout)
        defer { Task { await engine.shutdown() } }

        // A deep search we never drain - proven live by awaiting its
        // first info, then abandoned by the replacement below.
        let abandoned = engine.analyze(fen: .starting, depth: 24)
        var abandonedIterator = abandoned.makeAsyncIterator()
        _ = await abandonedIterator.next()

        // Queen odds again - the sign oracle: the replacement's own
        // deepest eval must be decisively black-favored, so a
        // near-level straggler from the abandoned starting-position
        // search standing in its place also fails the test.
        let fen = try FEN(parsing:
                            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNB1KBNR w KQkq -"
        )
        let stream = engine.analyze(fen: fen, depth: 8)
        var evals: [Evaluation] = []
        for await progress in stream {
            evals.append(progress.evaluation)
        }

        // Single literal, deliberately: `#expect`'s comment is `Comment?`,
        // which a string literal satisfies but a `String` expression
        // (e.g. two literals joined with `+`) does not.
        #expect(!evals.isEmpty,
                "The replacement stream must carry its own evaluations - a stale bestmove from the abandoned search must not finish it")
        switch try #require(evals.last) {
        case .centipawns(let cp):
            #expect(cp < -500, "Expected the replacement's queen-odds eval, got \(cp)cp")
        case .mate(let n):
            #expect(n < 0, "Mate should favor black, got mate(\(n))")
        }
    }

    // MARK: Startup Hardening (F4 - no Stockfish binary required)

    /// A binary that exits before speaking UCI fails the handshake promptly (the old code suspended
    /// until an unrelated timeout).
    @Test func startThrowsWhenTheEngineExitsBeforeTheHandshake() async {
        let engine = StockfishEngine(binaryURL: URL(filePath: "/usr/bin/true"))

        await #expect(throws: StockfishEngine.EngineError.self) {
            try await engine.start()
        }
        #expect(await engine.isRunning == false)
    }

    /// A silent binary trips the timeout - `/bin/cat` blocks on stdin, the pure timeout path.
    @Test func startThrowsOnHandshakeTimeout() async {
        let engine = StockfishEngine(binaryURL: URL(filePath: "/bin/cat"))

        await #expect(throws: StockfishEngine.EngineError.self) {
            try await engine.start(handshakeTimeout: .milliseconds(250))
        }
        #expect(await engine.isRunning == false)
    }

    /// The teardown-ordering hole: `shutdown()` during a pending handshake must fail `start()`
    /// promptly - pre-fix, only the timeout rescued it, up to 30 s late. The waits exist to be NOT hit.
    @Test func shutdownDuringThePendingHandshakeFailsStartPromptly() async throws {
        let engine = StockfishEngine(binaryURL: URL(filePath: "/bin/cat"))

        let start = Task {
            try await engine.start(
                handshakeTimeout: .seconds(60),
                readyTimeout: .seconds(60)
            )
        }

        var launched = false
        for _ in 0..<400 where !launched {
            launched = await engine.isRunning
            if !launched { try await Task.sleep(for: .milliseconds(5)) }
        }
        try #require(launched, "cat never launched - nothing to shut down")

        await engine.shutdown()

        await #expect(throws: StockfishEngine.EngineError.startupFailed(
            "The engine was shut down before completing the UCI handshake."
        )) {
            try await start.value
        }
        #expect(await engine.isRunning == false)
    }
}
