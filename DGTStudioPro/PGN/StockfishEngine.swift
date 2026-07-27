//
//  StockfishEngine.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 15/05/2026.
//

import Foundation
import os

/// Manages a Stockfish chess engine subprocess and exposes analysis
/// requests as `AsyncStream<Evaluation>` per call.
///
/// The actor handles the UCI protocol handshake, subprocess lifecycle,
/// stdout line buffering, and side-to-move-relative → white-relative
/// score conversion. All UCI message parsing is delegated to the pure
/// `UCIProtocol.parse(_:)` function (Phase 7.5a).
///
/// **Lifecycle:**
/// ```
/// let engine = StockfishEngine(binaryURL: StockfishEngine.defaultBinaryURL!)
/// try await engine.start()
///
/// let stream = engine.analyze(fen: someFEN, depth: 18)
/// for await evaluation in stream {
///     // evaluation is white-relative; project for UI.
///     updateUI(evaluation.whiteWinProbability)
/// }
///
/// await engine.shutdown()
/// ```
///
/// **Startup failures (F4):** `start()` *throws* rather than suspending
/// forever. Three exits guard the handshake: the process terminating
/// before it's ready (a wrong-architecture or instantly-crashing binary),
/// its stdout closing, or a handshake timeout (default 5 s — a binary
/// that launches and never speaks UCI, e.g. not actually a UCI engine).
/// The previous design awaited `uciok` on a non-throwing continuation
/// with no timeout: a dead binary left `start()` suspended permanently,
/// the caller's cancellation couldn't resume it, and the runtime logged a
/// leaked-continuation warning while the analysis driver sat at
/// "analyzing" forever. On any startup failure the half-started process
/// is terminated and torn down, so a retry can `start()` fresh.
///
/// **Inbound pipeline (F2):** stdout chunks flow through one ordered
/// `AsyncStream<Data>` consumed by a single actor task — the readability
/// handler's serial callback queue yields in order, so line assembly can
/// never see swapped chunks. (The previous design spawned one unstructured
/// `Task` per chunk; separate tasks carry no ordering guarantee, which
/// could interleave UCI lines under load.) Buffering as `Data` and
/// splitting on `\n` also fixes a silent byte-drop: decoding each chunk to
/// `String` up front returned nil — and discarded the chunk — whenever a
/// read happened to split a multi-byte codepoint.
///
/// **Cancellation:** if the Task consuming the stream is cancelled
/// (e.g. the user navigates away from a game), the stream's
/// `onTermination` handler sends `stop` to Stockfish to abort the
/// search. A subsequent `analyze(...)` call can be issued immediately.
///
/// **Concurrent analyses:** the eval-only phase supports one active
/// analysis at a time. Calling `analyze(...)` while a prior analysis
/// is in flight cleanly aborts the prior search, finishes its stream,
/// and begins the new one. The per-analysis UUID ensures the prior's
/// termination handler doesn't disrupt the new analysis.
internal actor StockfishEngine {
    
    // MARK: Static Constants
    
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "engine"
    )
    
    private static let uciLogger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "uci"
    )
    
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
    private var currentContinuation: AsyncStream<Evaluation>.Continuation?
    private var currentSideToMove: PieceColor = .white
    private var currentAnalysisID: UUID?
    
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
    /// `uci`, awaits `uciok`; sends `isready`, awaits `readyok`).
    /// After this returns, the engine is ready to accept analysis
    /// requests.
    ///
    /// Throws `EngineError.startupFailed` when the process exits or goes
    /// silent before completing the handshake, or when `handshakeTimeout`
    /// elapses first (F4). A failed start leaves nothing behind — the
    /// half-started process is terminated and all state cleared — so the
    /// caller may retry.
    internal func start(handshakeTimeout: Duration = .seconds(5)) async throws {
        guard process == nil else {
            Self.logger.error("start() called but engine is already running")
            throw EngineError.alreadyStarted
        }
        
        Self.logger.info("Starting engine at \(self.binaryURL.path, privacy: .public)")
        
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
            Self.logger.error(
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
            for option in EngineConfiguration.current.uciOptionLines {
                try writeLine(option)
            }
            
            try writeLine("isready")
            try await awaitHandshake(timeout: handshakeTimeout, awaiting: "readyok") {
                self.readyOKContinuation = $0
            }
        } catch {
            // A half-started engine must not leak (F4): kill it and clear
            // everything so a retry can `start()` fresh. The termination
            // handler will fire for the kill and no-op against the already
            // torn-down state. Foreign errors (e.g. an EPIPE from writing
            // `uci` into a pipe whose reader already died) are wrapped so
            // `start()`'s failure surface is uniformly `EngineError`.
            Self.logger.error(
                "Engine startup failed: \(String(describing: error), privacy: .public) — terminating subprocess"
            )
            if proc.isRunning { proc.terminate() }
            teardown()
            throw (error as? EngineError)
            ?? EngineError.startupFailed("UCI handshake failed: \(error.localizedDescription)")
        }
        
        Self.logger.info(
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
        
        Self.logger.info("Shutting down engine")
        
        // Tear down any in-flight analysis.
        currentContinuation?.finish()
        currentContinuation = nil
        currentAnalysisID = nil
        
        try? writeLine("quit")
        
        // Grace period for the engine to drain `quit`. Async sleep
        // keeps the actor's executor free during the wait. (The clean
        // exit fires `processDidTerminate` during this sleep; it runs
        // `teardown()` itself, and the repeat below is a guarded no-op.)
        try? await Task.sleep(for: .milliseconds(500))
        if proc.isRunning {
            Self.logger.info("Engine did not exit within grace period; force-terminating")
            proc.terminate()
        }
        
        teardown()
        
        Self.logger.info("Engine shutdown complete")
    }
    
    /// Fires for every process exit — the clean `quit` during `shutdown()`,
    /// a startup-failure kill, and an unexpected mid-session crash alike.
    /// Anything still waiting on the engine must not wait forever (F4):
    /// fail any pending handshake, finish any live analysis stream, tear
    /// down. Idempotent: a deliberate teardown that already ran leaves
    /// `process` nil, and this becomes a no-op.
    private func processDidTerminate(status: Int32) {
        guard process != nil else { return }
        Self.logger.error("Engine terminated (status \(status, privacy: .public))")
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
        Self.logger.error("Engine stdout ended while the process was still tracked")
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
        stdoutHandle?.readabilityHandler = nil
        stdoutContinuation?.finish()
        stdoutContinuation = nil
        stdoutTask = nil
        stdoutBuffer = Data()
        process = nil
        stdinHandle = nil
        stdoutHandle = nil
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
    /// `AsyncStream<Evaluation>` that yields progressively-deeper
    /// evaluations as Stockfish reports them, then completes when
    /// `bestmove` arrives.
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
    ) -> AsyncStream<Evaluation> {
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
        continuation: AsyncStream<Evaluation>.Continuation
    ) async {
        let analysisID = UUID()
        let priorContinuation = currentContinuation
        let hadPriorAnalysis = priorContinuation != nil
        
        currentContinuation = continuation
        currentSideToMove = fen.activeColor
        currentAnalysisID = analysisID
        
        Self.logger.debug(
            "beginAnalysis id=\(analysisID, privacy: .public) depth=\(depth) fen='\(fen.string, privacy: .public)' replacing=\(hadPriorAnalysis)"
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
            }
            try writeLine("position fen \(fen.string)")
            try writeLine("go depth \(depth)")
        } catch {
            Self.logger.error(
                "beginAnalysis write failed for id=\(analysisID, privacy: .public): \(error.localizedDescription, privacy: .public)"
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
    private func handleStdoutLine(_ line: String) {
        Self.uciLogger.debug("recv: \(line, privacy: .public)")
        
        guard let response = UCIProtocol.parse(line) else {
            // Empty lines are normal between sections; only log non-empty
            // unparseables so we can spot real engine drift.
            if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                Self.uciLogger.error("unparseable: \(line, privacy: .public)")
            }
            return
        }
        
        switch response {
        case .info(let info):
            guard let score = info.score else { return }
            let evaluation = score.toEvaluation(sideToMove: currentSideToMove)
            currentContinuation?.yield(evaluation)
            
        case .bestMove:
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
            Self.logger.error(
                "writeLine called but engine not started: command='\(command, privacy: .public)'"
            )
            throw EngineError.notStarted
        }
        Self.uciLogger.debug("send: \(command, privacy: .public)")
        try stdin.write(contentsOf: Data((command + "\n").utf8))
    }
}
