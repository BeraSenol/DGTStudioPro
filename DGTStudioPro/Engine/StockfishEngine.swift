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
        case binaryNotFound
        case startupFailed(String)
        case alreadyStarted
        case notStarted
    }
    
    // MARK: Stored State
    
    private let binaryURL: URL
    
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var stdoutBuffer: String = ""
    
    private(set) var engineName: String?
    private(set) var engineAuthor: String?
    
    // Analysis state — one active at a time in the eval-only phase.
    private var currentContinuation: AsyncStream<Evaluation>.Continuation?
    private var currentSideToMove: PieceColor = .white
    private var currentAnalysisID: UUID?
    
    // One-shot handshake continuations.
    private var uciOKContinuation: CheckedContinuation<Void, Never>?
    private var readyOKContinuation: CheckedContinuation<Void, Never>?
    
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
    internal func start() async throws {
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
        
        // Bounce stdout chunks into the actor.
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let chunk = String(data: data, encoding: .utf8)
            else { return }
            Task { [weak self] in
                await self?.ingestStdoutChunk(chunk)
            }
        }
        
        do {
            try proc.run()
        } catch {
            Self.logger.error(
                "Engine subprocess failed to launch: \(error.localizedDescription, privacy: .public)"
            )
            throw EngineError.startupFailed(error.localizedDescription)
        }
        
        self.process = proc
        self.stdinHandle = stdin.fileHandleForWriting
        self.stdoutHandle = stdout.fileHandleForReading
        
        // UCI handshake. The continuation is registered synchronously
        // inside withCheckedContinuation's body before the function
        // suspends, so there's no race with stdout arrival.
        try writeLine("uci")
        await withCheckedContinuation { cont in
            uciOKContinuation = cont
        }
        
        try writeLine("isready")
        await withCheckedContinuation { cont in
            readyOKContinuation = cont
        }
        
        Self.logger.info(
            "Engine ready: name='\(self.engineName ?? "?", privacy: .public)' author='\(self.engineAuthor ?? "?", privacy: .public)'"
        )
    }
    
    /// Shuts the engine down: terminates any in-flight analysis,
    /// sends `quit`, gives the subprocess a brief grace period to exit
    /// cleanly, then force-terminates if necessary.
    internal func shutdown() async {
        guard let proc = process else { return }
        
        Self.logger.info("Shutting down engine")
        
        // Tear down any in-flight analysis.
        currentContinuation?.finish()
        currentContinuation = nil
        currentAnalysisID = nil
        
        try? writeLine("quit")
        
        // Grace period for the engine to drain `quit`. Async sleep
        // keeps the actor's executor free during the wait.
        try? await Task.sleep(for: .milliseconds(500))
        if proc.isRunning {
            Self.logger.info("Engine did not exit within grace period; force-terminating")
            proc.terminate()
        }
        
        stdoutHandle?.readabilityHandler = nil
        process = nil
        stdinHandle = nil
        stdoutHandle = nil
        
        Self.logger.info("Engine shutdown complete")
    }
    
    // MARK: Analysis
    
    /// Begins analysis of `fen` to `depth` plies. Returns an
    /// `AsyncStream<Evaluation>` that yields progressively-deeper
    /// evaluations as Stockfish reports them, then completes when
    /// `bestmove` arrives.
    ///
    /// All emitted evaluations are normalized to white's perspective.
    /// The default depth of 18 matches Lichess cloud analysis defaults
    /// and balances responsiveness against evaluation quality.
    ///
    /// Cancelling the consuming Task aborts the search via UCI `stop`.
    /// Calling `analyze(...)` again while a prior analysis is in flight
    /// cleanly aborts the prior and starts the new one.
    nonisolated internal func analyze(
        fen: FEN,
        depth: Int = 18
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
    /// but read chunks don't necessarily align with line boundaries.
    private func ingestStdoutChunk(_ chunk: String) {
        stdoutBuffer += chunk
        while let newlineRange = stdoutBuffer.range(of: "\n") {
            let line = String(stdoutBuffer[..<newlineRange.lowerBound])
            stdoutBuffer.removeSubrange(..<newlineRange.upperBound)
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
            uciOKContinuation?.resume()
            uciOKContinuation = nil
            
        case .readyOK:
            readyOKContinuation?.resume()
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
        let data = (command + "\n").data(using: .utf8)!
        try stdin.write(contentsOf: data)
    }
}
