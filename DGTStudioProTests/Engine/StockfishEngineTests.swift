//
//  StockfishEngineTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 15/05/2026.
//

import Testing
import Foundation
@testable import DGTStudioPro

/// Tests for `StockfishEngine`. The integration tests require a real
/// Stockfish binary in the app's Resources folder — see
/// `Engine_README.md` for setup — and are conditionally enabled via
/// `.enabled(if: stockfishAvailable)`; when the binary isn't present
/// they're skipped automatically, so CI environments and fresh checkouts
/// won't see false failures. The startup-hardening tests (F4) use system
/// binaries as stand-ins and run on every checkout.
@Suite("Stockfish Engine Integration")
struct StockfishEngineTests {

    private static var stockfishAvailable: Bool {
        StockfishEngine.defaultBinaryURL != nil
    }

    /// A ⌘U host is not a user's Mac. `readyok` lands *after* the
    /// `setoption name Hash` write, so the handshake's slowest step —
    /// allocating and zeroing the table — is precisely the one a saturated
    /// host starves, and the depth-5 perft suites saturate every core in
    /// parallel. The 5 s production default exists to protect a *user* from
    /// a dead binary; inherited here it manufactures a startup failure out
    /// of load. The dead-binary contract stays pinned by
    /// `startThrowsOnHandshakeTimeout`, which passes 250 ms for the same
    /// reason in the opposite direction.
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
        for await evaluation in stream {
            lastEval = evaluation
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
        // Queen odds: the starting position minus White's queen, White
        // to move. Chosen over a "just blundered the queen" middlegame
        // because a hand-built tactic can quietly refute the premise —
        // the original FEN here parked the black queen on c3, where the
        // b2 AND d2 pawns both attack it, so White recaptures at once
        // and the real deficit is one pawn (Stockfish said −170cp, and
        // it was right; the test was wrong). It surfaced only when the
        // binary-gated integration tests first ran on a checkout with
        // Stockfish present. Queen odds has no move to argue with: the
        // material verdict is the only thing the engine can report.
        let url = try #require(StockfishEngine.defaultBinaryURL)
        let engine = StockfishEngine(binaryURL: url)
        try await engine.start()
        defer { Task { await engine.shutdown() } }

        let fen = try FEN(parsing:
                            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNB1KBNR w KQkq -"
        )

        let stream = engine.analyze(fen: fen, depth: 10)
        var lastEval: Evaluation?
        for await evaluation in stream {
            lastEval = evaluation
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

    /// The stale-`bestmove` guard (M1 item 8). Replacing a live search
    /// makes the engine answer the abandoned `go` with one hurried
    /// `bestmove`; serial UCI delivers it *after* the replacement's `go`
    /// was sent — while the current stream already belongs to the new
    /// analysis. Pre-guard, that stale reply finished the new stream,
    /// which then completed empty (or worse: carrying only the abandoned
    /// search's stragglers). Deterministic, not a race: depth 24 keeps
    /// the first search alive past the replacement call, and the
    /// abandoned search's `bestmove` always precedes the new search's
    /// first `info` in the pipe.
    @Test(.enabled(if: stockfishAvailable))
    func replacementAnalysisSurvivesStaleBestMove() async throws {
        let url = try #require(StockfishEngine.defaultBinaryURL)
        let engine = StockfishEngine(binaryURL: url)
        try await engine.start(handshakeTimeout: Self.handshakeTimeout)
        defer { Task { await engine.shutdown() } }

        // A deep search we never drain — proven live by awaiting its
        // first info, then abandoned by the replacement below.
        let abandoned = engine.analyze(fen: .starting, depth: 24)
        var abandonedIterator = abandoned.makeAsyncIterator()
        _ = await abandonedIterator.next()

        // Queen odds again — the sign oracle: the replacement's own
        // deepest eval must be decisively black-favored, so a
        // near-level straggler from the abandoned starting-position
        // search standing in its place also fails the test.
        let fen = try FEN(parsing:
                            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNB1KBNR w KQkq -"
        )
        let stream = engine.analyze(fen: fen, depth: 8)
        var evals: [Evaluation] = []
        for await evaluation in stream {
            evals.append(evaluation)
        }

        // Single literal, deliberately: `#expect`'s comment is `Comment?`,
        // which a string literal satisfies but a `String` expression
        // (e.g. two literals joined with `+`) does not.
        #expect(!evals.isEmpty,
                "The replacement stream must carry its own evaluations — a stale bestmove from the abandoned search must not finish it")
        switch try #require(evals.last) {
        case .centipawns(let cp):
            #expect(cp < -500, "Expected the replacement's queen-odds eval, got \(cp)cp")
        case .mate(let n):
            #expect(n < 0, "Mate should favor black, got mate(\(n))")
        }
    }

    // MARK: Startup Hardening (F4 — no Stockfish binary required)

    /// A binary that launches and exits before speaking UCI must fail the
    /// handshake promptly. The old `start()` awaited `uciok` on a
    /// non-throwing continuation with no termination handler: a dead binary
    /// left the caller suspended forever and leaked the continuation.
    /// `/usr/bin/true` is the canonical instant-exit stand-in.
    @Test func startThrowsWhenTheEngineExitsBeforeTheHandshake() async {
        let engine = StockfishEngine(binaryURL: URL(filePath: "/usr/bin/true"))

        await #expect(throws: StockfishEngine.EngineError.self) {
            try await engine.start()
        }
        #expect(await engine.isRunning == false)
    }

    /// A binary that launches and stays silent must trip the handshake
    /// timeout rather than suspend forever. `/bin/cat` blocks on stdin and
    /// never writes — the pure timeout path (the process outlives the
    /// deadline, so only the timeout task can fire). The failure path also
    /// terminates the stray process: `isRunning` false afterwards.
    @Test func startThrowsOnHandshakeTimeout() async {
        let engine = StockfishEngine(binaryURL: URL(filePath: "/bin/cat"))

        await #expect(throws: StockfishEngine.EngineError.self) {
            try await engine.start(handshakeTimeout: .milliseconds(250))
        }
        #expect(await engine.isRunning == false)
    }

    /// The teardown-ordering hole (30 July audit): `shutdown()` during a
    /// still-pending handshake clears `process` in `teardown()`, after
    /// which `processDidTerminate` and `engineOutputEnded` both guard
    /// themselves into no-ops — pre-fix, only the handshake's own timeout
    /// task rescued the waiter, so a Stop All inside the window reported
    /// failure up to 30 s late. The assertion is on the *message*: the
    /// prompt teardown failure and the late timeout backstop throw
    /// differently-worded `startupFailed`s, so equality distinguishes the
    /// fix from the backstop with no wall-clock bound (the 60 s deadlines
    /// here exist to be *not* hit — a regression fails this test after a
    /// minute rather than flaking under load).
    ///
    /// `/bin/cat` again: launches, blocks on stdin, never speaks UCI. By
    /// the time `isRunning` reads true the handshake continuation is
    /// already registered — no suspension point sits between the process
    /// assignment and the registration on the actor — so the `shutdown()`
    /// below always races nothing.
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
        try #require(launched, "cat never launched — nothing to shut down")

        await engine.shutdown()

        await #expect(throws: StockfishEngine.EngineError.startupFailed(
            "The engine was shut down before completing the UCI handshake."
        )) {
            try await start.value
        }
        #expect(await engine.isRunning == false)
    }
}
