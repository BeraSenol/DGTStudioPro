//
//  GameAnalysisDriver.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 18/05/2026.
//

import Foundation
import os
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
/// Lifecycle: one driver per `AnalysisQueueController` — one per tab.
/// The queue is the single analysis owner since M-batch (its decision 1);
/// views no longer instantiate drivers. The engine starts lazily on the
/// first ``analyze(pgn:depth:modelContext:)`` call and stays alive until
/// ``shutdown()`` is invoked (the controller releases it when the queue
/// drains, and at tab teardown). Successive games in a batch reuse the
/// warmed-up engine, saving the ~100ms UCI handshake per game.
@Observable
@MainActor
internal final class GameAnalysisDriver {
    
    // MARK: Static Constants
    private static let logger = AppLog.logger(.analysis)
    
    // MARK: Status
    /// Coarse-grained pass state, read only by `AnalysisQueueController`:
    /// `.analyzing` supplies `currentProgress`, and the terminal case maps
    /// to an `AnalysisQueue.Outcome` when the awaited pass returns. No view
    /// reads this — since M-batch the inspector's control row switches on
    /// `queue.status(of:)` (`AnalysisQueue.ItemStatus`), which knows about
    /// waiting and queue position and this type does not.
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
    
    /// Runs one full-game analysis pass and returns the terminal status —
    /// `.done`, `.failed`, or `.idle` after a ``stop()`` — awaitable so
    /// the queue controller knows when to advance to the next game.
    /// No-op returning the current status if a pass is already in flight;
    /// the controller serializes calls, so that guard is belt and braces.
    @discardableResult
    internal func analyze(
        pgn: PGN,
        // The one depth default in the codebase (M11 review — this was half
        // of a twin `= 18`; the engine's half is now parameter-required).
        // Evaluated at each call, so a batch queued after a Settings change
        // analyzes at the new depth.
        depth: Int = EngineConfiguration.current.depth,
        modelContext: ModelContext
    ) async -> Status {
        guard task == nil else {
            Self.logger?.info(
                "Analysis request ignored — a prior analysis is already in flight"
            )
            return status
        }
        
        guard let binaryURL = StockfishEngine.defaultBinaryURL else {
            Self.logger?.error("Stockfish binary not bundled in app Resources")
            status = .failed(
                message: "Stockfish binary not bundled in app Resources. " +
                "See Engine_README.md for setup."
            )
            return status
        }
        
        let engine = self.engine ?? StockfishEngine(binaryURL: binaryURL)
        self.engine = engine
        
        Self.logger?.info(
            "Analysis started: pgn='\(pgn.name, privacy: .public)' plies=\(pgn.moves.count) depth=\(depth)"
        )
        
        // The evaluations reset lives in `runAnalysis`, *after* a
        // successful engine start: resetting here destroyed the previous
        // analysis even when `start()` then threw, so a broken binary
        // cost the user their stored graph for nothing (M1 item 9a).

        // The pass still runs in its own Task — that is what ``stop()``
        // cancels — but the caller awaits its completion. Cancelling the
        // *awaiting* task does not cancel the pass; teardown goes through
        // ``stop()``/``shutdown()``, exactly as it always has.
        let pass = Task { @MainActor [weak self] in
            // `guard let`, not optional chaining: a lone
            // `await self?.runAnalysis(...)` is a single-expression
            // closure of type `Void?`, and the resulting
            // `Task<Void?, Never>` won't assign to `task` below. (The
            // old fire-and-forget body dodged this only by having a
            // second statement.)
            guard let self else { return }
            await self.runAnalysis(
                engine: engine,
                pgn: pgn,
                depth: depth,
                modelContext: modelContext
            )
        }
        task = pass
        await pass.value
        task = nil
        return status
    }
    
    /// Cancels the running analysis Task. Structured cancellation
    /// propagates through the AsyncStream's `onTermination` handler into
    /// the engine actor, which sends UCI `stop` to the subprocess. The
    /// driver returns to `.idle`; any evaluations already populated stay
    /// in the PGN.
    internal func stop() {
        Self.logger?.info("Analysis stop requested")
        task?.cancel()
    }
    
    /// Cancels any running analysis and shuts down the engine subprocess
    /// with a 500ms grace period. The queue controller calls this when
    /// the queue drains (decision 4) and at tab teardown. Safe to call
    /// multiple times — re-entry after shutdown returns immediately.
    internal func shutdown() async {
        Self.logger?.info("Analysis driver shutdown")
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
            Self.logger?.info("Reusing warm engine")
        } catch {
            Self.logger?.error(
                "Engine start failed: \(String(describing: error), privacy: .public)"
            )
            status = .failed(message: "Engine failed to start: \(error).")
            return
        }

        // Only now — with a live engine — is destroying the previous
        // analysis justified. Nil-per-ply preserves PGN's
        // empty-or-same-length-as-moves invariant and gives the graph a
        // flat baseline to animate against; re-analyzing replaces prior
        // results entirely. (Sat in `analyze()` before the start attempt
        // until 29 July — see the note there, M1 item 9a.)
        pgn.evaluations = Array(repeating: nil, count: pgn.moves.count)

        // Classification rides the pass but does not depend on it (D34′).
        // Stamped up front and through the store's single write door, so a
        // walk that stops at an unparseable ply still leaves the game with
        // its opening — the half of "analysis" that never needed an engine
        // shouldn't be hostage to the half that does. Save-free by the
        // store's contract; the per-ply save below carries it, and the
        // Library backfill is the net for a pass that dies before ply one.
        //
        // `warmed()`, not the synchronous default: this method is already
        // async, and a batch started from a tab that never showed the
        // Library would otherwise pay the table's parse on the main actor,
        // right where the user is watching a progress bar.
        PGNStore(modelContext: modelContext)
            .classify(pgn, using: await ECOTable.warmed())

        status = .analyzing(progress: 0)

        var state = GameState.starting
        let total = pgn.moves.count

        // How many per-ply saves in a row may fail before the pass stops
        // pretending. One failed save is recoverable — the next save
        // persists the whole context, so a transient miss costs nothing,
        // which is why a single failure must *not* end the pass. Three in a
        // row is systemic (full disk, wedged store), and riding that out
        // used to land the pass on `.done` with a graph the in-memory model
        // renders and nothing persisted — a green result that vanished at
        // relaunch, with Console the only witness (1 Aug review, E1).
        let saveFailureTolerance = 3
        var consecutiveSaveFailures = 0

        for (index, san) in pgn.moves.enumerated() {
            if Task.isCancelled { break }
            
            // A SAN that won't parse stops the walk — partial analysis is
            // preferable to crashing on corrupt PGN. The graph just keeps
            // its nil tail.
            guard let move = try? state.parseSAN(san) else {
                Self.logger?.error(
                    """
                    SAN walk broke at index \(index) san='\(san, privacy: .public)' \
                    pgn='\(pgn.name, privacy: .public)' — partial analysis stops here, \
                    \(total - index) plies left unevaluated
                    """
                )
                // `.failed`, not a bare `break` into `.done`: the popover
                // used to report success for a pass that stopped at an
                // unparseable ply (M1 item 9b). The controller's outcome
                // mapping always claimed failures are recorded — now the
                // driver actually hands it one.
                status = .failed(
                    message: "\(Self.moveLabel(plyIndex: index, san: san)) won't parse — "
                    + "analysis stopped there; earlier evaluations were kept."
                )
                return
            }
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

            // A dead engine finishes every remaining stream instantly, so
            // the old loop raced through the tail and landed on `.done`
            // with nothing evaluated (M1 item 9b). One actor hop per ply
            // is nothing next to the search that just ran.
            guard await engine.isRunning else {
                Self.logger?.error(
                    "Engine died mid-pass at ply \(index + 1)/\(total) for pgn='\(pgn.name, privacy: .public)'"
                )
                status = .failed(
                    message: "The engine quit at \(Self.moveLabel(plyIndex: index, san: san)) "
                    + "(ply \(index + 1) of \(total)); evaluations up to there were kept."
                )
                return
            }

            status = .analyzing(
                progress: Double(index + 1) / Double(max(total, 1))
            )
            do {
                try modelContext.save()
                consecutiveSaveFailures = 0
            } catch {
                consecutiveSaveFailures += 1
                Self.logger?.error(
                    "Evaluation save failed at ply \(index + 1) (\(consecutiveSaveFailures) in a row): \(error.localizedDescription, privacy: .public)"
                )
                if consecutiveSaveFailures >= saveFailureTolerance {
                    // The message follows the walk's other exits: name where
                    // it stopped, say what was kept. "Up to the last
                    // successful save", not "up to here" — evaluations since
                    // that save exist only in memory, which is the whole
                    // reason this exit exists.
                    status = .failed(
                        message: "The library stopped accepting saves at "
                        + "\(Self.moveLabel(plyIndex: index, san: san)) "
                        + "(\(error.localizedDescription)); evaluations up to "
                        + "the last successful save were kept."
                    )
                    return
                }
            }
        }
        
        if Task.isCancelled {
            Self.logger?.info("Analysis cancelled: pgn='\(pgn.name, privacy: .public)'")
        } else {
            Self.logger?.info("Analysis complete: pgn='\(pgn.name, privacy: .public)' plies=\(total)")
        }
        
        status = Task.isCancelled ? .idle : .done
    }

    /// The user-facing name of a ply, in chess notation: ply index 2 is
    /// "2. Nf3"-shaped for White, "2… Nc6"-shaped for Black. The failure
    /// messages used to print the raw ply ordinal as "Move N", which in a
    /// chess app reads as a full-move number and points at the wrong move
    /// for every Black ply (30 July audit). Log lines keep ply indices —
    /// they're for grep, not for reading at the popover.
    private static func moveLabel(plyIndex: Int, san: String) -> String {
        "\(plyIndex / 2 + 1)\(plyIndex.isMultiple(of: 2) ? ". " : "… ")\(san)"
    }
}
