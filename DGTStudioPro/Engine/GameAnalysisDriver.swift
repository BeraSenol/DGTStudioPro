import Foundation
import os
import SwiftData

/// Drives a full-game engine pass: walks each ply, asks Stockfish for an evaluation at the
/// requested depth, records **one** evaluation per ply, saves **once per exit** - never per ply.
/// The pass is a *plan*, not the whole game: the classified book prefix is skipped and
/// a ply already scored at ≥ the target depth is kept - re-analysis deepens instead of restarting.
@Observable
@MainActor
final class GameAnalysisDriver {
    
    // MARK: Static Constants
    private static let logger = AppLog.logger(.analysis)
    
    // MARK: Status
    /// Coarse pass state, read only by `AnalysisQueueController` - no view reads it.
    enum Status: Equatable {
        case idle
        case analyzing(progress: Double)
        case done
        case failed(message: String)
    }
    
    // MARK: Live Search

    /// What the engine is doing right now, for the queue window. Here and not on the model - the
    /// whole point of write-coalescing: per-ply model writes invalidated every `@Query` in the app.
    struct Search: Equatable, Sendable {
        /// 0-based ply index within the game.
        let plyIndex: Int
        let totalPlies: Int
        /// The move whose resulting position is being searched, in SAN.
        let san: String
        let progress: EngineProgress

        /// The requested depth (the `18` in `go depth 18`) - what the window's Depth fact shows, by request.
        let targetDepth: Int
    }

    private(set) var search: Search?

    // MARK: Stored Properties
    private(set) var status: Status = .idle

    private var engine: StockfishEngine?
    private var task: Task<Void, Never>?

    /// UserDefaults seam (F9), matching `DGTConnection`'s: the depth default below is a preference
    /// read, and ⌘U must not take it from the real domain.
    @ObservationIgnored var defaults: UserDefaults = .standard
    
    // MARK: Public API
    
    /// One full-game pass, awaitable so the controller knows when to advance. No-op if already in flight.
    @discardableResult
    func analyze(
        pgn: PGN,
        // Nil resolves from preferences *inside*, per call - so a batch queued after a Settings change
        // analyzes at the new depth. A default argument cannot do this: it could not read `defaults`,
        // so it read `.standard` and made every ⌘U run depend on the real domain.
        depth requestedDepth: Int? = nil,
        modelContext: ModelContext
    ) async -> Status {
        let depth = requestedDepth
        ?? EngineConfiguration.current(syzygyPath: nil, in: defaults).depth

        guard task == nil else {
            Self.logger?.info(
                "Analysis request ignored, a prior analysis is already in flight"
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
        
        // The evaluations reset lives in `runAnalysis`, after a successful engine start: resetting here
        // destroyed the previous analysis even when `start()` threw (M1 9a).

        // The pass runs in its own Task (what `stop()` cancels) while the caller awaits completion.
        // Cancelling the awaiting task does not cancel the pass.
        let pass = Task { @MainActor [weak self] in
            // `guard let`, not chaining: `await self?.run…` makes the closure `Void?` and the Task type mismatches.
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
    
    /// Cancels the running pass; cancellation propagates through `onTermination` into the actor,
    /// which sends UCI `stop`. Evaluations already populated stay.
    func stop() {
        Self.logger?.info("Analysis stop requested")
        task?.cancel()
    }
    
    /// Cancel + engine shutdown with grace. Called at queue drain (decision 4) and teardown; re-entrant.
    func shutdown() async {
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
        // `defer`, not a clear per exit: five ways out of this walk, and a live search left on screen
        // after any of them describes an engine that has moved on.
        defer { search = nil }

        // Classification now precedes the engine: the plan below reads the freshly stamped
        // book depth, and a fully satisfied game never spawns a subprocess. `warmed()` - this
        // method is async and must not block on the table parse.
        PGNStore(modelContext: modelContext)
            .classify(pgn, using: await ECOTable.warmed())

        let total = pgn.moves.count
        let plan = AnalysisPlan.plan(
            moveCount: total,
            evaluations: pgn.evaluations,
            depths: pgn.analysisDepths,
            bookPlies: pgn.ecoDepth ?? 0,
            targetDepth: depth
        )

        guard !plan.searchable.isEmpty else {
            // Book-only, or already at depth. The save still runs - classify may have stamped.
            Self.logger?.info(
                "Analysis satisfied without searching: pgn='\(pgn.name, privacy: .public)'"
            )
            status = persist(modelContext, of: pgn)
                ? .done
                : .failed(message: "Nothing needed searching, but the Library refused the save.")
            return
        }

        // Warm-up on first analyze; `.alreadyStarted` from a warm engine is treated as success.
        do {
            try await engine.start()
        } catch StockfishEngine.EngineError.alreadyStarted {
            // Reused engine - already warm, proceed.
            Self.logger?.info("Reusing warm engine")
        } catch {
            Self.logger?.error(
                "Engine start failed: \(String(describing: error), privacy: .public)"
            )
            // `localizedDescription`, not `\(error)` - interpolation prints Swift case syntax
            // (`startupFailed("…")`) into a row the user reads; the log above keeps the case form.
            status = .failed(message: "Engine failed to start: \(error.localizedDescription)")
            return
        }

        // Storage rebuilds only when the arrays don't fit - narrower than the old blanket reset:
        // a fitting pass keeps every evaluation the plan is about to skip. Still after a
        // successful start, so a broken binary costs nothing stored.
        //
        // **The second check is not redundant with `resetsStorage`.** That flag speaks for
        // `evaluations` alone; `depths` fits or not independently, and a legacy game (evaluations
        // fitting, depths empty) arrives with the flag false. Without this line the indexed write
        // below is out of bounds on the first scored ply.
        if plan.resetsStorage {
            pgn.evaluations = Array(repeating: nil, count: total)
        }
        if pgn.analysisDepths.count != total {
            pgn.analysisDepths = Array(repeating: nil, count: total)
        }

        status = .analyzing(progress: 0)

        var state = GameState.starting
        let searchable = Set(plan.searchable)
        var searched = 0

        for (index, san) in pgn.moves.enumerated() {
            if Task.isCancelled { break }

            // Unparseable SAN stops the walk - partial analysis beats crashing on corrupt PGN.
            guard let move = try? state.parseSAN(san) else {
                Self.logger?.error(
                    """
                    SAN walk broke at index \(index) san='\(san, privacy: .public)' \
                    pgn='\(pgn.name, privacy: .public)' - partial analysis stops here, \
                    \(total - index) plies left unevaluated
                    """
                )
                // `.failed`, not `break` into `.done`: the UI used to report success for a pass that stopped at
                // an unparseable ply (M1 9b).
                let saved = persist(modelContext, of: pgn)
                status = .failed(
                    message: "\(Self.moveLabel(plyIndex: index, san: san)) won't parse, "
                    + "analysis stopped there"
                    + (saved ? "; earlier evaluations were kept."
                             : ", and the Library refused the save - earlier evaluations were lost.")
                )
                return
            }
            state = state.applying(move)

            // Book prefix and already-satisfied plies replay for position and are never searched.
            guard searchable.contains(index) else { continue }
            let fen = FEN(state)

            // **One write per ply, not one per emission**: Stockfish reports every iteration; only the
            // deepest search matters, so fold locally and write once when the stream completes.
            var deepest: Evaluation?
            for await progress in engine.analyze(fen: fen, depth: depth) {
                if Task.isCancelled { break }
                deepest = progress.evaluation
                search = Search(
                    plyIndex: index,
                    totalPlies: total,
                    san: san,
                    progress: progress,
                    targetDepth: depth
                )
            }

            // Cancellation exit persists what stands below - skip the write to avoid a "still analyzing" flicker.
            if Task.isCancelled { break }

            // **Health check before the write, and the order is the point.** The write below records
            // the depth *requested*, not the depth reached, so a ply whose stream ended early - the
            // engine dying mid-search after a few shallow lines - would be stamped with the full
            // target and read as satisfied by every later pass, permanently. `deepest == nil` covers
            // only the engine that emitted nothing at all; this covers the one that emitted a little.
            // A dead engine also finishes every remaining stream instantly, which is the older reason
            // for asking (M1 9b). One actor hop per ply is nothing next to the search.
            guard await engine.isRunning else {
                Self.logger?.error(
                    "Engine died mid-pass at ply \(index + 1)/\(total) for pgn='\(pgn.name, privacy: .public)'"
                )
                // Save before the claim.
                let saved = persist(modelContext, of: pgn)
                status = .failed(
                    message: "The engine quit at \(Self.moveLabel(plyIndex: index, san: san)) "
                    + "(ply \(index + 1) of \(total))"
                    + (saved ? "; evaluations up to there were kept."
                             : ", and the Library refused the save - evaluations were lost.")
                )
                return
            }

            // The engine outlived the ply, so the stream ran to `bestmove` and `depth` is the depth
            // actually reached. Nil only when it yielded nothing; leaving the slot nil keeps "this ply
            // was never scored" readable (the Analysis Data window's placeholder rows).
            if let deepest {
                pgn.evaluations[index] = deepest
                pgn.analysisDepths[index] = depth   // what makes the next pass incremental
            }

            searched += 1
            // Denominated in *searchable* plies - over the full count, a skipped book would
            // freeze the fraction below 1 forever. The `max` never fires: an empty plan returned
            // above, so reaching here means the count is at least 1.
            status = .analyzing(
                progress: Double(searched) / Double(max(plan.searchable.count, 1))
            )

            // **No save here, and the absence is the decision**: a per-ply save invalidated every
            // `@Query` in every open window - the app's last per-ply fan-out.
        }

        // The three ordinary exits, each persisting what the walk wrote; `.done` only if the store took
        // the result - a failed save on the done path is `.failed`, not `.done`-with-Console.
        if Task.isCancelled {
            if !persist(modelContext, of: pgn) {
                Self.logger?.error(
                    "Cancelled pass could not persist its partial evaluations for pgn='\(pgn.name, privacy: .public)' - the cancelled row's 'were kept' does not hold this once"
                )
            }
            Self.logger?.info("Analysis cancelled: pgn='\(pgn.name, privacy: .public)'")
            status = .idle
            return
        }

        Self.logger?.info("Analysis complete: pgn='\(pgn.name, privacy: .public)' plies=\(total)")
        if persist(modelContext, of: pgn) {
            status = .done
        } else {
            status = .failed(
                message: "Analysis finished, but the Library refused the save; "
                + "the evaluations were not stored and will be gone after a relaunch."
            )
        }
    }

    /// The one save: everything the pass wrote, one transaction at an exit. Returns whether
    /// it landed; the caller owns the message, which differs per exit.
    private func persist(_ modelContext: ModelContext, of pgn: PGN) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            Self.logger?.error(
                "Evaluation save failed for pgn='\(pgn.name, privacy: .public)': \(error.localizedDescription, privacy: .public) - in-memory results still render until relaunch"
            )
            return false
        }
    }

    /// Ply → "2. Nf3" / "2… Nc6". Failure messages used to print "Move N", which reads as a
    /// full-move number and points at the wrong move for every Black ply. Logs keep ply indices.
    ///
    /// Internal rather than private since 24 Aug 2026: the queue window renders the same grammar for
    /// the running search, and had its own character-identical copy. One spelling, two readers.
    static func moveLabel(plyIndex: Int, san: String) -> String {
        "\(plyIndex / 2 + 1)\(plyIndex.isMultiple(of: 2) ? ". " : "… ")\(san)"
    }
}
