import Foundation
import os

/// Manages a Stockfish chess engine subprocess and exposes analysis
/// requests as `AsyncStream<EngineProgress>` per call.
///
/// The actor owns the UCI handshake, subprocess lifecycle, stdout line
/// buffering, and side-to-move-relative → white-relative score conversion. All
/// parsing is delegated to the pure `UCIProtocol.parse(_:)`.
///
/// ```
/// let engine = StockfishEngine(binaryURL: StockfishEngine.defaultBinaryURL!)
/// try await engine.start()
/// for await evaluation in engine.analyze(fen: someFEN, depth: 18) {
///     updateUI(evaluation.whiteWinProbability)   // white-relative
/// }
/// await engine.shutdown()
/// ```
///
/// **Startup failures (F4):** `start()` *throws* rather than suspending forever.
/// Three exits guard the handshake — the process terminating before it is ready,
/// its stdout closing, or a 5 s timeout for a binary that launches and never
/// speaks UCI. The half-started process is torn down on any of them, so a retry
/// can `start()` fresh.
///
/// **Inbound pipeline (F2):** stdout chunks flow through one ordered
/// `AsyncStream<Data>` consumed by a single actor task; the readability
/// handler's serial queue yields in order, so line assembly can never see
/// swapped chunks. Buffering as `Data` and splitting on `\n` is load-bearing
/// too — decoding each chunk to `String` up front returns nil, and silently
/// drops the chunk, whenever a read splits a multi-byte codepoint.
///
/// **Cancellation:** the stream's `onTermination` sends `stop` to abort the
/// search; a subsequent `analyze(...)` can be issued immediately.
///
/// **Concurrent analyses:** one at a time. Calling `analyze(...)` mid-flight
/// aborts the prior search and finishes its stream; the per-analysis UUID is
/// what keeps the prior's termination handler from disrupting the new one.
internal actor StockfishEngine {
    
    // MARK: Static Constants
    
    private static let logger = AppLog.logger(.engine)
    
    private static let uciLogger = AppLog.logger(.uci)
    
    // MARK: Errors
    
    internal enum EngineError: Error, Equatable {
        case startupFailed(String)
        case alreadyStarted
        case notStarted
    }
    
    // MARK: Stored State
    
    private let binaryURL: URL
    
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    
    /// Raw stdout bytes awaiting a complete `\n`-terminated line. `Data`,
    /// not `String` — see the type doc's F2 note on split codepoints.
    private var stdoutBuffer = Data()
    
    /// Feeds stdout chunks to `stdoutTask`, in arrival order (F2). Finished
    /// by the handler on EOF (engine exited / closed stdout) or by
    /// `teardown()`.
    private var stdoutContinuation: AsyncStream<Data>.Continuation?
    
    /// The single actor-isolated consumer of the stdout stream.
    private var stdoutTask: Task<Void, Never>?
    
    private(set) var engineName: String?
    private(set) var engineAuthor: String?
    
    // Analysis state — one active at a time in the eval-only phase.
    private var currentContinuation: AsyncStream<EngineProgress>.Continuation?

    /// Holds the tablebase folder's security-scoped access open for the
    /// engine's lifetime. Nil when no folder is configured or it would not
    /// resolve; cleared at teardown, which is what closes the resource.
    private var syzygyAccess: SyzygyLocation.Access?

    /// Stockfish's own sentence about what it loaded, verbatim — "Found 290 WDL
    /// and 290 DTZ tablebase files (up to 5-man)", or whatever this build says.
    ///
    /// **Stored raw rather than parsed into a count, and that is the decision.**
    /// The wording has changed across Stockfish versions (older builds said
    /// "Found 145 tablebases"), so any number extracted here is a guess about a
    /// format the engine is free to change. Showing the engine's own words
    /// cannot go stale and cannot be subtly wrong — and the question this
    /// exists to answer is "did the subprocess see the files", where a
    /// verbatim answer is strictly more informative than a parsed one.
    ///
    /// Nil when no `SyzygyPath` was sent, and — the case worth naming — also
    /// nil if a path *was* sent and the engine said nothing about it, which
    /// would itself be news.
    internal private(set) var tablebaseReport: String?
    private var currentSideToMove: PieceColor = .white
    private var currentAnalysisID: UUID?

    /// `bestmove` replies still owed by searches abandoned via replacement
    /// (`beginAnalysis` over a live search). The engine answers every `go`
    /// with exactly one `bestmove` — a replacement `stop` just hurries it
    /// along — and serial UCI delivers that reply *after* the
    /// replacement's `go` was written, i.e. while `currentContinuation`
    /// already belongs to the NEW analysis. `.bestMove` consumes from this
    /// budget before it may finish anything, and `.info` drops lines while
    /// the budget is open (they are the abandoned search's stragglers —
    /// yielding one would convert it under the new side-to-move and flip
    /// its sign into the new stream). The consumer-cancel `stop`
    /// (`handleStreamTermination`) deliberately does not count here: its
    /// `bestmove` targets the still-current analysis and must run the
    /// normal finish-and-clear path. Pinned by
    /// `replacementAnalysisSurvivesStaleBestMove`.
    private var staleBestMovesOwed = 0
    
    // One-shot handshake continuations. Throwing (F4): resumed with success
    // by `uciok`/`readyok`, or with `EngineError.startupFailed` by process
    // termination, stdout EOF, or the handshake timeout.
    private var uciOKContinuation: CheckedContinuation<Void, any Error>?
    private var readyOKContinuation: CheckedContinuation<Void, any Error>?
    
    // MARK: Initialization
    
    internal init(binaryURL: URL) {
        self.binaryURL = binaryURL
    }
    
    /// Resolves the bundled Stockfish binary, if present. Returns nil
    /// when the binary isn't in the app's Resources — typically because
    /// the developer hasn't run through the steps in `Engine_README.md`,
    /// or because we're running from a test bundle that doesn't include
    /// the binary.
    internal static var defaultBinaryURL: URL? {
        Bundle.main.url(forResource: "stockfish", withExtension: nil)
    }
    
    /// Reports whether the engine subprocess is currently running.
    /// Useful for UI state ("Start engine" vs "Engine running") and
    /// for tests that verify clean lifecycle transitions.
    internal var isRunning: Bool {
        process?.isRunning ?? false
    }
    
    // MARK: Lifecycle
    
    /// Spawns the subprocess and performs the UCI handshake (sends
    /// `uci`, awaits `uciok`; sends the configured options, then
    /// `isready`, awaits `readyok`). After this returns, the engine is
    /// ready to accept analysis requests.
    ///
    /// Throws `EngineError.startupFailed` when the process exits or goes
    /// silent before completing the handshake, or when either deadline
    /// elapses first (F4). A failed start leaves nothing behind — the
    /// half-started process is terminated and all state cleared — so the
    /// caller may retry.
    ///
    /// The two waits carry separate deadlines because they are different
    /// in kind. `uciok` is a pure protocol reply — the engine parses one
    /// word and answers, so a slow one is a broken one. `readyok` is an
    /// *allocation barrier*: it is the first thing the engine answers
    /// after `setoption`, so it covers building the transposition table
    /// (128 MB by default) and sizing the thread pool, which is precisely
    /// what `isready` exists for in the UCI contract. One constant served
    /// both only while the options were being sent outside their window
    /// and silently ignored — the bug fixed 27 July. Making them land
    /// gave the second wait real work to cover.
    internal func start(
        handshakeTimeout: Duration = .seconds(5),
        readyTimeout: Duration = .seconds(30)
    ) async throws {
        guard process == nil else {
            Self.logger?.error("Engine start ignored, already running")
            throw EngineError.alreadyStarted
        }
        
        Self.logger?.info("Starting engine at \(self.binaryURL.path, privacy: .public)")
        
        let proc = Process()
        proc.executableURL = binaryURL
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()  // discarded
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr
        
        // The ordered stdout pipeline (F2) — see the type doc. The handler
        // captures no `self`; it only bridges bytes into the stream. Raw
        // `read(2)` keeps a dead pipe from raising through `availableData`,
        // and 0/-1 becomes the end-of-stream signal.
        let (chunks, stdoutContinuation) = AsyncStream.makeStream(of: Data.self)
        self.stdoutContinuation = stdoutContinuation
        stdout.fileHandleForReading.readabilityHandler = { handle in
            var buffer = [UInt8](repeating: 0, count: 4096)
            let count = Darwin.read(handle.fileDescriptor, &buffer, buffer.count)
            if count > 0 {
                stdoutContinuation.yield(Data(buffer[0..<count]))
            } else if count < 0 && (errno == EAGAIN || errno == EINTR) {
                // Spurious wakeup — the next callback retries.
            } else {
                // EOF or fatal read error — the engine exited or closed
                // stdout. End the pipeline; `engineOutputEnded()` reacts.
                handle.readabilityHandler = nil
                stdoutContinuation.finish()
            }
        }
        
        // One long-lived, actor-isolated consumer: line assembly and
        // dispatch run here, in chunk-arrival order.
        stdoutTask = Task {
            for await chunk in chunks {
                ingestStdoutChunk(chunk)
            }
            engineOutputEnded()
        }
        
        // F4: the engine dying — at any point, including the clean `quit`
        // during `shutdown()` — must never strand a waiter. Termination
        // fails any pending handshake, finishes any live analysis stream,
        // and tears down (all idempotent, so overlapping exits are safe).
        proc.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            Task { [weak self] in
                await self?.processDidTerminate(status: status)
            }
        }
        
        do {
            try proc.run()
        } catch {
            Self.logger?.error(
                "Engine subprocess failed to launch: \(error.localizedDescription, privacy: .public)"
            )
            teardown()
            throw EngineError.startupFailed(error.localizedDescription)
        }
        
        self.process = proc
        self.stdinHandle = stdin.fileHandleForWriting
        self.stdoutHandle = stdout.fileHandleForReading
        
        // UCI handshake. Each continuation is registered synchronously
        // inside withCheckedThrowingContinuation's body before the function
        // suspends, so there's no race with stdout arrival; the timeout
        // task, termination handler, and stdout-EOF path can each resume it
        // with a failure (exactly one wins — `failHandshake` nils as it
        // resumes).
        do {
            try writeLine("uci")
            try await awaitHandshake(timeout: handshakeTimeout, awaiting: "uciok") {
                self.uciOKContinuation = $0
            }
            
            // The user's engine options (M11 review — the Settings pane now
            // binds to reality). `setoption` is only valid *after* `uciok`
            // and before `isready`, so this is the one window — and this loop
            // used to sit above `uci`, outside it. Read fresh at every launch;
            // the engine relaunches per run (released at drain), so a Settings
            // change applies to the next analysis with no restart story.
            // Syzygy (7 Aug 2026): the folder is opened *here*, and the token
            // is held on the actor for the engine's whole life. Releasing it
            // when this scope ended would close the scoped resource under a
            // subprocess that is still probing — the failure `SyzygyLocation`
            // is arranged to make impossible by construction rather than by
            // remembering.
            //
            // Nil when no folder is configured, when the bookmark no longer
            // resolves (moved, renamed, unmounted volume), or when the sandbox
            // refuses it. All three produce the same thing — no `SyzygyPath`
            // line — because from the engine's side they are the same state:
            // no tables. Telling them apart is Settings' verification job, and
            // it has two numbers to do it with.
            syzygyAccess = SyzygyLocation.access()
            for option in EngineConfiguration.current(
                syzygyPath: syzygyAccess?.path
            ).uciOptionLines {
                try writeLine(option)
            }
            
            try writeLine("isready")
            try await awaitHandshake(timeout: readyTimeout, awaiting: "readyok") {
                self.readyOKContinuation = $0
            }
        } catch {
            // A half-started engine must not leak (F4): kill it and clear
            // everything so a retry can `start()` fresh. The termination
            // handler will fire for the kill and no-op against the already
            // torn-down state. Foreign errors (e.g. an EPIPE from writing
            // `uci` into a pipe whose reader already died) are wrapped so
            // `start()`'s failure surface is uniformly `EngineError`.
            Self.logger?.error(
                "Engine startup failed: \(String(describing: error), privacy: .public), terminating subprocess"
            )
            if proc.isRunning { proc.terminate() }
            teardown()
            throw (error as? EngineError)
            ?? EngineError.startupFailed("UCI handshake failed: \(error.localizedDescription)")
        }
        
        Self.logger?.info(
            "Engine ready: name='\(self.engineName ?? "?", privacy: .public)' author='\(self.engineAuthor ?? "?", privacy: .public)'"
        )
    }
    
    /// Shuts the engine down: terminates any in-flight analysis,
    /// sends `quit`, gives the subprocess a brief grace period to exit
    /// cleanly, then force-terminates if necessary. Safe to call when
    /// not started (no-op) and after a failed `start()` (also a no-op —
    /// the failure path already tore down).
    internal func shutdown() async {
        guard let proc = process else { return }
        
        Self.logger?.info("Shutting down engine")
        
        // Tear down any in-flight analysis.
        currentContinuation?.finish()
        currentContinuation = nil
        currentAnalysisID = nil
        
        try? writeLine("quit")
        
        // Grace period for the engine to drain `quit`. Async sleep
        // keeps the actor's executor free during the wait. (The clean
        // exit fires `processDidTerminate` during this sleep; it runs
        // `teardown()` itself, and the repeat below is a guarded no-op.)
        // `try?`, load-bearing: this is the one suspension point on the
        // teardown path, and a cancelled caller (tab close, cancelled
        // `.task`) makes it throw immediately. Swallowing that means
        // cancellation skips the *grace period* and falls straight through to
        // `terminate()` + `teardown()` — the engine-teardown invariant, upheld
        // by construction. Any rewrite that returns or rethrows here orphans
        // the subprocess precisely when the tab is going away.
        try? await Task.sleep(for: .milliseconds(500))
        if proc.isRunning {
            Self.logger?.info("Engine did not exit within grace period; force-terminating")
            proc.terminate()
        }
        
        teardown()
        
        Self.logger?.info("Engine shutdown complete")
    }
    
    /// Fires for every process exit — the clean `quit` during `shutdown()`,
    /// a startup-failure kill, and an unexpected mid-session crash alike.
    /// Anything still waiting on the engine must not wait forever (F4):
    /// fail any pending handshake, finish any live analysis stream, tear
    /// down. Idempotent: a deliberate teardown that already ran leaves
    /// `process` nil, and this becomes a no-op.
    private func processDidTerminate(status: Int32) {
        guard process != nil else { return }
        Self.logger?.error("Engine terminated (status \(status, privacy: .public))")
        failHandshake(
            with: EngineError.startupFailed(
                "The engine exited (status \(status)) before completing the UCI handshake."
            )
        )
        currentContinuation?.finish()
        currentContinuation = nil
        currentAnalysisID = nil
        teardown()
    }
    
    /// Runs when the stdout stream finishes. A deliberate teardown already
    /// cleared `process` — nothing to do. Otherwise the engine closed its
    /// stdout while still tracked (a crash's first symptom): no further
    /// responses are coming, so fail any pending handshake and finish any
    /// live analysis stream now. Process bookkeeping is left to the
    /// termination handler, which follows immediately behind.
    private func engineOutputEnded() {
        guard process != nil else { return }
        Self.logger?.error("Engine stdout ended while the process was still tracked")
        failHandshake(
            with: EngineError.startupFailed(
                "The engine closed its output before completing the UCI handshake."
            )
        )
        currentContinuation?.finish()
        currentContinuation = nil
        currentAnalysisID = nil
    }
    
    /// Clears every piece of subprocess state: read source, pipeline,
    /// handles, process reference. Idempotent by construction — every line
    /// tolerates already-cleared state — so the shutdown path, the
    /// termination handler, and the startup-failure path can overlap safely.
    private func teardown() {
        // A teardown that runs while a handshake is still suspended must
        // fail it here: this clears `process`, after which
        // `processDidTerminate` and `engineOutputEnded` guard themselves
        // into no-ops and only the handshake's own timeout task would
        // rescue a stranded `start()` — a Stop All inside the 5 s/30 s
        // window used to report failure up to 30 s late (F4's "never
        // strand a waiter", made total). `failHandshake` nils as it
        // resumes, so every already-resumed path makes this a no-op.
        // Pinned by `shutdownDuringThePendingHandshakeFailsStartPromptly`.
        failHandshake(
            with: EngineError.startupFailed(
                "The engine was shut down before completing the UCI handshake."
            )
        )
        stdoutHandle?.readabilityHandler = nil
        stdoutContinuation?.finish()
        stdoutContinuation = nil
        stdoutTask = nil
        stdoutBuffer = Data()
        process = nil
        stdinHandle = nil
        stdoutHandle = nil
        // Owed stale replies die with the process; a fresh start must not
        // eat its first real `bestmove` against a dead search's debt.
        staleBestMovesOwed = 0
        // Releasing the token here is what closes the tablebase folder's
        // security-scoped access, and teardown is the right place precisely
        // because it is the one path *every* exit runs through — a clean
        // `quit`, a timed-out handshake, a killed half-start, an EOF. A
        // scoped resource left open by one of those is a leak the process
        // exiting does not clean up.
        //
        // The report goes with it: it describes the tables a now-dead engine
        // loaded, and a stale one on the next start would answer a question
        // about a subprocess that no longer exists.
        syzygyAccess = nil
        tablebaseReport = nil
    }
    
    // MARK: Handshake (F4)
    
    /// Awaits one handshake response with a deadline. `register` stores the
    /// throwing continuation (synchronously, before any suspension); the
    /// timeout task resumes it with `startupFailed` if the response doesn't
    /// arrive first. Whichever of {response, timeout, termination, EOF}
    /// runs first wins — `failHandshake` and the response handlers all nil
    /// the continuation as they resume it.
    private func awaitHandshake(
        timeout: Duration,
        awaiting expected: String,
        register: (CheckedContinuation<Void, any Error>) -> Void
    ) async throws {
        let timeoutTask = Task {
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            failHandshake(
                with: EngineError.startupFailed(
                    "Timed out waiting for the engine's '\(expected)'."
                )
            )
        }
        defer { timeoutTask.cancel() }
        try await withCheckedThrowingContinuation(register)
    }
    
    /// Resumes any pending handshake continuation with `error`, exactly
    /// once each. No-op when nothing is pending.
    private func failHandshake(with error: EngineError) {
        uciOKContinuation?.resume(throwing: error)
        uciOKContinuation = nil
        readyOKContinuation?.resume(throwing: error)
        readyOKContinuation = nil
    }
    
    // MARK: Analysis
    
    /// Begins analysis of `fen` to `depth` plies. Returns an
    /// `AsyncStream<EngineProgress>` that yields progressively-deeper
    /// evaluations as Stockfish reports them, then completes when
    /// `bestmove` arrives.
    ///
    /// **Yielded `EngineProgress` rather than a bare `Evaluation` since 6 Aug
    /// 2026**, so a consumer can show the search rather than only its answer.
    /// The extra fields were already parsed and already on the same line; what
    /// changed is that they stop being discarded. `GameAnalysisDriver` still
    /// stores only the evaluation, and only the last one per ply.
    ///
    /// All emitted evaluations are normalized to white's perspective.
    /// `depth` is required, not defaulted: the M11 review collapsed the twin
    /// `= 18` defaults into `EngineConfiguration.current.depth`, which
    /// `GameAnalysisDriver` supplies. The comment outlived the default.
    ///
    /// Cancelling the consuming Task aborts the search via UCI `stop`.
    /// Calling `analyze(...)` again while a prior analysis is in flight
    /// cleanly aborts the prior and starts the new one.
    nonisolated internal func analyze(
        fen: FEN,
        depth: Int
    ) -> AsyncStream<EngineProgress> {
        AsyncStream { [weak self] continuation in
            Task { [weak self] in
                await self?.beginAnalysis(
                    fen: fen,
                    depth: depth,
                    continuation: continuation
                )
            }
        }
    }
    
    private func beginAnalysis(
        fen: FEN,
        depth: Int,
        continuation: AsyncStream<EngineProgress>.Continuation
    ) async {
        let analysisID = UUID()
        let priorContinuation = currentContinuation
        let hadPriorAnalysis = priorContinuation != nil
        
        currentContinuation = continuation
        currentSideToMove = fen.activeColor
        currentAnalysisID = analysisID
        
        Self.logger?.debug(
            "Analysis begun: id=\(analysisID, privacy: .public) depth=\(depth) fen='\(fen.string, privacy: .public)' replacing=\(hadPriorAnalysis)"
        )
        
        // Capture analysisID in the termination closure so it can be
        // compared against currentAnalysisID at termination time. If the
        // current analysis has been replaced by a newer one, this
        // termination signal is stale and must not interrupt the new search.
        continuation.onTermination = { [weak self, analysisID] _ in
            Task { [weak self] in
                await self?.handleStreamTermination(forAnalysisID: analysisID)
            }
        }
        
        do {
            // If a prior analysis is active, abort its search before
            // sending the new position. Stockfish processes commands
            // serially, so the order stop → position → go is guaranteed
            // to apply correctly.
            if hadPriorAnalysis {
                try writeLine("stop")
                // The abandoned search now owes one stale `bestmove`.
                // Counted only after the write succeeds — a failed write
                // means the engine is gone, and teardown resets the budget.
                staleBestMovesOwed += 1
            }
            try writeLine("position fen \(fen.string)")
            try writeLine("go depth \(depth)")
        } catch {
            Self.logger?.error(
                "Analysis write failed for id=\(analysisID, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            continuation.finish()
            currentContinuation = nil
            currentAnalysisID = nil
        }
        
        // Notify the prior consumer that its stream is over. Its
        // termination handler will fire but will see currentAnalysisID
        // no longer matches and will no-op.
        priorContinuation?.finish()
    }
    
    private func handleStreamTermination(forAnalysisID id: UUID) async {
        guard currentAnalysisID == id else {
            // Stale termination signal from a replaced analysis. Ignore.
            return
        }
        try? writeLine("stop")
    }
    
    // MARK: Stdout Ingestion
    
    /// Appends raw stdout bytes to the line buffer and flushes any
    /// complete lines to the response handler. UCI is line-oriented,
    /// but read chunks don't necessarily align with line boundaries —
    /// or even with codepoint boundaries, which is why the buffer is
    /// `Data` and decoding happens per complete line (F2). Runs only on
    /// `stdoutTask`, in chunk-arrival order.
    private func ingestStdoutChunk(_ chunk: Data) {
        stdoutBuffer.append(chunk)
        while let newlineIndex = stdoutBuffer.firstIndex(of: 0x0A) {
            var lineData = stdoutBuffer[stdoutBuffer.startIndex..<newlineIndex]
            if lineData.last == 0x0D {  // tolerate \r\n
                lineData = lineData.dropLast()
            }
            // `String(decoding:)` never fails — invalid sequences become
            // U+FFFD instead of silently discarding the line. UCI output
            // is ASCII in practice; this is belt and braces.
            let line = String(decoding: lineData, as: UTF8.self)
            stdoutBuffer.removeSubrange(stdoutBuffer.startIndex...newlineIndex)
            handleStdoutLine(line)
        }
    }
    
    /// Parses a single complete line from stdout and dispatches by
    /// response type.
    /// Pulls Stockfish's tablebase sentence out of an `info string` line, or
    /// nil for any other line.
    ///
    /// **Matched on "Found" plus "tablebase", not on the full sentence**, which
    /// is what makes it survive the wording change that has already happened
    /// once: builds up to roughly Stockfish 15 said "Found 145 tablebases",
    /// current ones say "Found 290 WDL and 290 DTZ tablebase files (up to
    /// 5-man)". Both contain those two words and no other `info string` this
    /// engine emits does — the rest are processor counts, thread counts and
    /// NNUE file names.
    ///
    /// Returns the text *after* `info string`, so the caller stores a sentence
    /// rather than a protocol prefix. `nonisolated` and `static` so it is a
    /// pure function of its input and testable without a subprocess.
    nonisolated internal static func tablebaseReport(in line: String) -> String? {
        let prefix = "info string "
        guard line.hasPrefix(prefix) else { return nil }
        let body = String(line.dropFirst(prefix.count))
        guard body.contains("Found"), body.contains("tablebase") else { return nil }
        return body
    }

    private func handleStdoutLine(_ line: String) {
        Self.uciLogger?.debug("recv: \(line, privacy: .public)")

        // **Captured off the raw line, before parsing, and it has to be.**
        // `UCIProtocol.parseInfo` consumes `string` to end-of-line and stores
        // nothing — correctly, since `info string` is free-form engine chatter
        // with no grammar to model. Teaching it to keep the text would put a
        // `String?` on `UCIInfo` that is nil for every line but this family.
        // One `hasPrefix` here is the smaller change and keeps the parser's
        // subject the lines that *have* fields.
        if let report = Self.tablebaseReport(in: line) {
            tablebaseReport = report
            Self.logger?.info("Syzygy: \(report, privacy: .public)")
        }

        guard let response = UCIProtocol.parse(line) else {
            // `parse` returns nil for three different reasons and only one of
            // them is news. Empty lines are normal between sections. Option
            // advertisements are the recorded invariant — deliberately
            // ignored, and there are about twenty-five of them at every start,
            // which is what used to make this an error channel nobody could
            // read. What is left is genuine engine drift.
            //
            // One line per start still reaches the error arm in normal use:
            // Stockfish's `Stockfish 18 by the …` banner, which is legal
            // pre-handshake chatter and matches no keyword. Named here so a
            // reader knows what the floor looks like — if this arm ever prints
            // anything *else*, the engine has changed under us, which is the
            // whole reason the arm exists.
            if !UCIProtocol.isDeliberatelyIgnored(line),
               !line.trimmingCharacters(in: .whitespaces).isEmpty {
                Self.uciLogger?.error("Unrecognized engine line: '\(line, privacy: .public)'")
            }
            return
        }
        
        switch response {
        case .info(let info):
            // Stragglers of an abandoned search: the engine is serial, so
            // until the owed `bestmove` arrives, every info line belongs
            // to the dead search — see `staleBestMovesOwed`.
            guard staleBestMovesOwed == 0 else { return }
            // **A line with no score is not progress, it is chatter.** Depth,
            // node counts and `currmove` all arrive on scoreless lines too, and
            // yielding those would give the window a search whose evaluation
            // slot has nothing in it — which is why `EngineProgress.evaluation`
            // is non-optional and this guard is what makes that honest. The
            // rest of the fields ride along from the same line rather than
            // being remembered across lines, so a value never mixes one
            // iteration's depth with another's score.
            guard let score = info.score else { return }
            currentContinuation?.yield(
                EngineProgress(
                    evaluation: score.toEvaluation(sideToMove: currentSideToMove),
                    depth: info.depth,
                    nodes: info.nodes,
                    nodesPerSecond: info.nodesPerSecond
                )
            )

        case .bestMove:
            // A stale reply from an abandoned search must not finish the
            // stream it never belonged to — pre-guard, it prematurely
            // ended the *next* analysis's stream, which then completed
            // empty (M1 item 8). See `staleBestMovesOwed`.
            if staleBestMovesOwed > 0 {
                staleBestMovesOwed -= 1
                return
            }
            currentContinuation?.finish()
            currentContinuation = nil
            currentAnalysisID = nil
            
        case .id(let key, let value):
            switch key {
            case "name":   engineName = value
            case "author": engineAuthor = value
            default:       break
            }
            
        case .uciOK:
            uciOKContinuation?.resume(returning: ())
            uciOKContinuation = nil
            
        case .readyOK:
            readyOKContinuation?.resume(returning: ())
            readyOKContinuation = nil
        }
    }
    
    // MARK: Stdin
    
    /// Writes a single UCI command line (newline appended) to the
    /// engine's stdin. Synchronous from the actor's perspective —
    /// `FileHandle.write(contentsOf:)` doesn't suspend.
    private func writeLine(_ command: String) throws {
        guard let stdin = stdinHandle else {
            Self.logger?.error(
                "Write refused, engine not started: command='\(command, privacy: .public)'"
            )
            throw EngineError.notStarted
        }
        Self.uciLogger?.debug("send: \(command, privacy: .public)")
        try stdin.write(contentsOf: Data((command + "\n").utf8))
    }
}
