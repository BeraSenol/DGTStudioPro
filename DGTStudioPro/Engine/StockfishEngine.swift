import Foundation
import os

/// Manages a Stockfish subprocess; analysis as `AsyncStream<EngineProgress>` per call. Owns the
/// UCI handshake, lifecycle, stdout line buffering, and side-to-move → white-relative conversion.
/// Inbound pipeline (F2): stdout chunks flow through one ordered stream; buffering as `Data` and
/// splitting on `\n` is load-bearing - a `String` round trip drops chunks that split a codepoint.
/// F4: no exit path may strand a waiter.
actor StockfishEngine {
    
    // MARK: Static Constants
    
    private static let logger = AppLog.logger(.engine)
    
    private static let uciLogger = AppLog.logger(.uci)
    
    // MARK: Errors
    
    enum EngineError: Error, Equatable, LocalizedError {
        case startupFailed(String)
        case alreadyStarted
        case notStarted

        /// `LocalizedError` because generic catches render `localizedDescription` (the Syzygy
        /// check's failure line, the queue window's failure row) - without it Foundation prints
        /// the type-and-code fallback and the `startupFailed` payload never surfaces. Exhaustive
        /// and `String`-per-arm, so "every case has prose" is compiler-checked, not tested.
        var errorDescription: String? {
            switch self {
            case .startupFailed(let message): return message
            case .alreadyStarted:            return "The engine is already running."
            case .notStarted:                return "The engine hasn't started."
            }
        }
    }
    
    // MARK: Stored State
    
    private let binaryURL: URL
    
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    
    /// Raw stdout awaiting a complete line. `Data`, not `String` - the F2 split-codepoint note above.
    private var stdoutBuffer = Data()
    
    /// Feeds stdout chunks in arrival order (F2); finished on EOF or by `teardown()`.
    private var stdoutContinuation: AsyncStream<Data>.Continuation?
    
    /// The single actor-isolated consumer of the stdout stream.
    private var stdoutTask: Task<Void, Never>?
    
    private(set) var engineName: String?
    private(set) var engineAuthor: String?
    
    // Analysis state - one active at a time in the eval-only phase.
    private var currentContinuation: AsyncStream<EngineProgress>.Continuation?

    /// Holds the tablebase folder's security-scoped access for the engine's lifetime; cleared at teardown.
    private var syzygyAccess: SyzygyLocation.Access?

    /// Stockfish's own tablebase sentence, verbatim. Raw rather than parsed into a count: the wording
    /// varies across versions, and a report that quotes cannot go stale or be subtly wrong.
    private(set) var tablebaseReport: String?
    private var currentSideToMove: PieceColor = .white
    private var currentAnalysisID: UUID?

    /// `bestmove` replies still owed by searches abandoned via replacement - the engine answers every
    /// `go` exactly once, so until the debt drains, incoming lines belong to a dead search.
    /// Termination deliberately does not count here: its `bestmove` targets the current analysis.
    private var staleBestMovesOwed = 0
    
    // One-shot handshake continuations (F4): resumed by `uciok`/`readyok`, or failed by termination,
    // stdout EOF, or the timeout.
    private var uciOKContinuation: CheckedContinuation<Void, any Error>?
    private var readyOKContinuation: CheckedContinuation<Void, any Error>?
    
    // MARK: Initialization
    
    init(binaryURL: URL) {
        self.binaryURL = binaryURL
    }
    
    /// The bundled binary, or nil (Engine_README.md steps not run, or a test bundle without it).
    static var defaultBinaryURL: URL? {
        Bundle.main.url(forResource: "stockfish", withExtension: nil)
    }
    
    /// Whether the subprocess is running.
    var isRunning: Bool {
        process?.isRunning ?? false
    }
    
    // MARK: Lifecycle
    
    /// Spawns the subprocess and runs the UCI handshake: `uci` → `uciok`, options, `isready` →
    /// `readyok`. Options must be sent inside that window - this loop once sat outside it.
    func start(
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
        // `.utility`: a `Process` inherits the parent's QoS, and with Threads raised the search fought
        // the main thread at UI priority. Not `.background` - that tier can starve on efficiency cores.
        proc.qualityOfService = .utility
        let stdin = Pipe()
        let stdout = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        // `nullDevice`, not a `Pipe`: an attached pipe nobody drains is a 64 KB ceiling, and an engine
        // that started chattering on stderr would block on write and hang mid-search. Discarding at the
        // kernel has no ceiling. Stockfish is quiet here either way - this removes the failure mode.
        proc.standardError = FileHandle.nullDevice
        
        // Ordered stdout pipeline (F2). The handler captures no `self`; raw `read(2)` keeps a dead pipe
        // from raising through `availableData` - 0/-1 becomes the end-of-stream signal.
        let (chunks, stdoutContinuation) = AsyncStream.makeStream(of: Data.self)
        self.stdoutContinuation = stdoutContinuation
        stdout.fileHandleForReading.readabilityHandler = { handle in
            var buffer = [UInt8](repeating: 0, count: 4096)
            let count = Darwin.read(handle.fileDescriptor, &buffer, buffer.count)
            if count > 0 {
                stdoutContinuation.yield(Data(buffer[0..<count]))
            } else if count < 0 && (errno == EAGAIN || errno == EINTR) {
                // Spurious wakeup - the next callback retries.
            } else {
                // EOF or fatal read error - end the pipeline; `engineOutputEnded()` reacts.
                handle.readabilityHandler = nil
                stdoutContinuation.finish()
            }
        }
        
        // One long-lived actor-isolated consumer: assembly and dispatch in chunk-arrival order.
        stdoutTask = Task {
            for await chunk in chunks {
                ingestStdoutChunk(chunk)
            }
            engineOutputEnded()
        }
        
        // F4: the engine dying - including the clean `quit` - must never strand a waiter.
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
        
        // Handshake: continuations register synchronously before suspension, so no race with stdout;
        // exactly one of {response, timeout, termination, EOF} wins.
        do {
            try writeLine("uci")
            try await awaitHandshake(timeout: handshakeTimeout, awaiting: "uciok") {
                self.uciOKContinuation = $0
            }
            
            // The user's engine options, read fresh each launch (the engine relaunches per run). `setoption`
            // is only valid after `uciok` and before `isready` - the one window.
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
            // A half-started engine must not leak (F4): kill, clear, let a retry start fresh. Foreign errors
            // (e.g. EPIPE) are wrapped so the failure surface is uniformly `EngineError`.
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
    
    /// Shutdown: end any analysis, `quit`, brief grace, then force-terminate. Safe when not started
    /// and after a failed `start()`.
    func shutdown() async {
        guard let proc = process else { return }
        
        Self.logger?.info("Shutting down engine")
        
        // Tear down any in-flight analysis.
        currentContinuation?.finish()
        currentContinuation = nil
        currentAnalysisID = nil
        
        try? writeLine("quit")
        
        // Grace for the engine to drain `quit`; async sleep keeps the executor free. `try?` is
        // load-bearing: this is the one suspension point, and cancellation must still reach the kill.
        try? await Task.sleep(for: .milliseconds(500))
        if proc.isRunning {
            Self.logger?.info("Engine did not exit within grace period; force-terminating")
            proc.terminate()
        }
        
        teardown()
        
        Self.logger?.info("Engine shutdown complete")
    }
    
    /// Every process exit - clean quit, startup-failure kill, crash. Fail any pending handshake,
    /// finish any live stream, tear down (F4). Idempotent.
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
    
    /// Stdout finished. Deliberate teardown → no-op; otherwise a crash's first symptom - fail the
    /// handshake and finish any live stream now. Process bookkeeping is the termination handler's.
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
    
    /// Clears all subprocess state. Idempotent by construction, so shutdown, termination handler and
    /// startup-failure paths overlap safely.
    private func teardown() {
        // A teardown during a suspended handshake must fail it here - after `process` is nil the other
        // guards no-op, and only the timeout would rescue a stranded `start()`, up to 30 s late.
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
        // Owed stale replies die with the process - a fresh start must not eat its first real `bestmove`.
        staleBestMovesOwed = 0
        // Releasing the token closes the tablebase folder's security-scoped access; teardown is the one
        // path every exit runs through.
        syzygyAccess = nil
        tablebaseReport = nil
    }
    
    // MARK: Handshake (F4)
    
    /// One handshake response with a deadline; whichever of {response, timeout, termination, EOF}
    /// runs first wins - each nils the continuation as it resumes.
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
    
    /// Fails any pending handshake continuation, exactly once each; no-op when none.
    private func failHandshake(with error: EngineError) {
        uciOKContinuation?.resume(throwing: error)
        uciOKContinuation = nil
        readyOKContinuation?.resume(throwing: error)
        readyOKContinuation = nil
    }
    
    // MARK: Analysis
    
    /// Analysis of `fen` to `depth`, yielding progressively deeper evaluations, completing on
    /// `bestmove`. One analysis at a time; a new call replaces a live search (stop → position → go).
    nonisolated func analyze(
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
        
        // analysisID captured so a stale termination signal from a replaced analysis can be detected.
        continuation.onTermination = { [weak self, analysisID] _ in
            Task { [weak self] in
                await self?.handleStreamTermination(forAnalysisID: analysisID)
            }
        }
        
        do {
            // Abort the prior search first - Stockfish is serial, so stop → position → go applies in order.
            if hadPriorAnalysis {
                try writeLine("stop")
                // The abandoned search owes one stale `bestmove`. Counted only after the write succeeds,
                // and **not** unwound if a later write throws: `stop` was delivered to a search that was
                // still live (`hadPriorAnalysis` means its continuation had not been finished), so that
                // reply is genuinely coming. Decrementing here would hand it to the next analysis.
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
        
        // Tell the prior consumer its stream is over; its termination handler sees a mismatched id and no-ops.
        priorContinuation?.finish()
    }
    
    private func handleStreamTermination(forAnalysisID id: UUID) async {
        guard currentAnalysisID == id else {
            // Stale termination signal from a replaced analysis - ignore.
            return
        }
        try? writeLine("stop")
    }
    
    // MARK: Stdout Ingestion
    
    /// Appends chunk bytes and flushes complete lines. Chunks align with neither line nor codepoint
    /// boundaries - hence `Data` buffer, per-line decoding (F2). Runs only on `stdoutTask`, in order.
    private func ingestStdoutChunk(_ chunk: Data) {
        stdoutBuffer.append(chunk)
        while let newlineIndex = stdoutBuffer.firstIndex(of: 0x0A) {
            var lineData = stdoutBuffer[stdoutBuffer.startIndex..<newlineIndex]
            if lineData.last == 0x0D {  // tolerate \r\n
                lineData = lineData.dropLast()
            }
            // `String(decoding:)` never fails - invalid sequences become U+FFFD instead of dropping the line.
            let line = String(decoding: lineData, as: UTF8.self)
            stdoutBuffer.removeSubrange(stdoutBuffer.startIndex...newlineIndex)
            handleStdoutLine(line)
        }
    }
    
    /// Stockfish's tablebase sentence, or nil. Matched on "Found" + "tablebase", not the full
    /// sentence - the wording varies across versions.
    nonisolated static func tablebaseReport(in line: String) -> String? {
        let prefix = "info string "
        guard line.hasPrefix(prefix) else { return nil }
        let body = String(line.dropFirst(prefix.count))
        guard body.contains("Found"), body.contains("tablebase") else { return nil }
        return body
    }

    /// Dispatches one complete stdout line. (This sentence sat on `tablebaseReport` above until
    /// 24 Aug 2026 - a re-homed `///` block, which nothing compiles and nothing checks.)
    private func handleStdoutLine(_ line: String) {
        Self.uciLogger?.debug("recv: \(line, privacy: .public)")

        // Captured off the raw line, before parsing - `parseInfo` consumes `string` to end-of-line and
        // stores nothing (free-form chatter has no grammar to model). One `hasPrefix` is the smaller change.
        if let report = Self.tablebaseReport(in: line) {
            tablebaseReport = report
            Self.logger?.info("Syzygy: \(report, privacy: .public)")
        }

        guard let response = UCIProtocol.parse(line) else {
            // `parse` returns nil for three reasons and only one is news: empty lines are normal, option
            // advertisements are deliberately ignored (~25 per start - split off the error channel deliberately).
            if !UCIProtocol.isDeliberatelyIgnored(line),
               !line.trimmingCharacters(in: .whitespaces).isEmpty {
                Self.uciLogger?.error("Unrecognized engine line: '\(line, privacy: .public)'")
            }
            return
        }
        
        switch response {
        case .info(let info):
            // Stragglers of an abandoned search: serial engine, so until the owed `bestmove` arrives every
            // info line belongs to the dead search.
            guard staleBestMovesOwed == 0 else { return }
            // A line with no score is chatter, not progress - yielding it would hand the window a search
            // with an empty evaluation slot (`EngineProgress.evaluation` is non-optional; this guard makes that honest).
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
            // A stale reply must not finish the stream it never belonged to - pre-guard, it ended the *next*
            // analysis's stream, which completed empty (M1 item 8).
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
    
    /// One UCI command line to stdin; synchronous - `write(contentsOf:)` doesn't suspend.
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
