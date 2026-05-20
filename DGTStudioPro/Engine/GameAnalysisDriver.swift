//
//  GameAnalysisDriver.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 18/05/2026.
//

import Foundation
import SwiftData

/// Drives a full-game engine analysis pass: walks each ply of a ``PGN``,
/// asks the bundled Stockfish engine for an evaluation at the requested
/// depth, streams progressive-deepening results into
/// ``PGN/evaluations`` so the inspector graph animates as the search
/// deepens, and saves the model context once per ply so partial progress
/// survives a crash or quit.
///
/// The driver is `@MainActor` so all SwiftData mutation happens on the
/// model context's actor — the AsyncStream from the engine bridges back
/// to MainActor at each emission. The engine subprocess work itself runs
/// on the actor inside ``StockfishEngine`` without blocking MainActor.
///
/// Lifecycle: one driver per inspector view. The engine starts lazily on
/// the first ``analyze(pgn:depth:modelContext:)`` call and stays alive
/// until ``shutdown()`` is invoked (typically from `.onDisappear`).
/// Subsequent analyses on the same driver reuse the warmed-up engine,
/// saving the ~100ms UCI handshake.
@Observable
@MainActor
internal final class GameAnalysisDriver {
    
    // MARK: Status
    /// Coarse-grained view-facing state. The inspector uses this to pick
    /// between the Analyze button, the progress + Stop combo, and the
    /// error message row.
    internal enum Status: Equatable {
        case idle
        case analyzing(progress: Double)
        case done
        case failed(message: String)
    }
    
    // MARK: Stored Properties
    internal private(set) var status: Status = .idle
    
    private var engine: StockfishEngine?
    private var task: Task<Void, Never>?
    
    // MARK: Public API
    
    /// Begins a full-game analysis pass. No-op if a previous analysis is
    /// already running on this driver — the caller can either wait for it
    /// to finish naturally or call ``stop()`` first.
    internal func analyze(
        pgn: PGN,
        depth: Int = 18,
        modelContext: ModelContext
    ) {
        guard task == nil else { return }
        
        guard let binaryURL = StockfishEngine.defaultBinaryURL else {
            status = .failed(
                message: "Stockfish binary not bundled in app Resources. " +
                "See Engine_README.md for setup."
            )
            return
        }
        
        let engine = self.engine ?? StockfishEngine(binaryURL: binaryURL)
        self.engine = engine
        
        // Reset (or initialize) the evaluations array to nil-per-ply.
        // Preserves the empty-or-same-length-as-moves invariant on PGN
        // and gives the graph a flat baseline to animate against as evals
        // stream in. Re-analyzing replaces prior results entirely.
        pgn.evaluations = Array(repeating: nil, count: pgn.moves.count)
        status = .analyzing(progress: 0)
        
        task = Task { @MainActor [weak self] in
            await self?.runAnalysis(
                engine: engine,
                pgn: pgn,
                depth: depth,
                modelContext: modelContext
            )
            self?.task = nil
        }
    }
    
    /// Cancels the running analysis Task. Structured cancellation
    /// propagates through the AsyncStream's `onTermination` handler into
    /// the engine actor, which sends UCI `stop` to the subprocess. The
    /// driver returns to `.idle`; any evaluations already populated stay
    /// in the PGN.
    internal func stop() {
        task?.cancel()
    }
    
    /// Cancels any running analysis and shuts down the engine subprocess
    /// with a 500ms grace period. Call from `.onDisappear` to release the
    /// child process when the inspector view goes away. Safe to call
    /// multiple times — re-entry after shutdown returns immediately.
    internal func shutdown() async {
        task?.cancel()
        await engine?.shutdown()
        engine = nil
    }
    
    // MARK: Analysis Loop
    
    private func runAnalysis(
        engine: StockfishEngine,
        pgn: PGN,
        depth: Int,
        modelContext: ModelContext
    ) async {
        // Warm up the engine on first analyze; later analyses on the same
        // driver skip this path because the actor's `isRunning` is already
        // true and start() throws .alreadyStarted, which we treat as a
        // success signal.
        do {
            try await engine.start()
        } catch StockfishEngine.EngineError.alreadyStarted {
            // Reused engine — already warm, proceed.
        } catch {
            status = .failed(message: "Engine failed to start: \(error).")
            return
        }
        
        var state = GameState.starting
        let total = pgn.moves.count
        
        for (index, san) in pgn.moves.enumerated() {
            if Task.isCancelled { break }
            
            // A SAN that won't parse stops the walk — partial analysis is
            // preferable to crashing on corrupt PGN. The graph just keeps
            // its nil tail.
            guard let move = try? state.parseSAN(san) else { break }
            state = state.applying(move)
            let fen = FEN(state)
            
            // The engine emits progressively deeper evals; updating the
            // PGN on each emission lets the graph animate the search
            // converging. The final emission carries the deepest result.
            for await eval in engine.analyze(fen: fen, depth: depth) {
                if Task.isCancelled { break }
                pgn.evaluations[index] = eval
            }
            
            // If we exited the inner loop via cancellation, skip the
            // progress/save updates — the outer loop will pick up the
            // cancellation on its next iteration and we don't want a
            // brief "still analyzing" flicker on the way out.
            if Task.isCancelled { break }
            
            status = .analyzing(
                progress: Double(index + 1) / Double(max(total, 1))
            )
            try? modelContext.save()
        }
        
        status = Task.isCancelled ? .idle : .done
    }
}
