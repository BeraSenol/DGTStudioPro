import Foundation
import os
import SwiftData

/// Drives a full-game engine pass: walks each ply of a ``PGN``, asks Stockfish
/// for an evaluation at the requested depth, records **one** evaluation per ply
/// into ``PGN/evaluations``, and saves **once per exit** — game done, pass
/// cancelled, or any failure — never per ply (D71′).
///
/// This header has now been corrected twice in the same direction, and the
/// trajectory is the finding. It said "streams progressive-deepening results …
/// so the graph animates" until 6 Aug 2026, when the per-*emission* model
/// write was making the app unusable during a batch; the write moved to once
/// per ply. It then said "saves once per ply so partial progress survives a
/// crash" until 8 Aug 2026, when the per-*ply* `save()` turned out to be the
/// remaining stutter: a save invalidates every `@Query` in every open window,
/// so an 80-ply game re-rendered the whole app eighty times — the exact
/// multiplier D70′ memoized the folds against, still paid by the query fetch,
/// the sort and the table diff the memo sits under. The argument, and what the
/// coarser cadence costs, is at the save site in
/// ``runAnalysis(engine:pgn:depth:modelContext:)``.
///
/// `@MainActor` so all SwiftData mutation happens on the context's actor — the
/// engine's `AsyncStream` bridges back at each emission, while the subprocess
/// work runs inside ``StockfishEngine`` without blocking. **The per-emission
/// hop is the cost that made the write rate matter**: every `info` line the
/// engine prints resumes this actor, so anything done per emission is done on
/// the thread drawing the UI.
///
/// One driver per `AnalysisQueueController`, one controller per tab; views no
/// longer instantiate drivers. The engine starts lazily on the first `analyze`
/// and lives until ``shutdown()``, so successive games in a batch reuse it and
/// pay the ~100 ms UCI handshake once.
@Observable
@MainActor
internal final class GameAnalysisDriver {
    
    // MARK: Static Constants
    private static let logger = AppLog.logger(.analysis)
    
    // MARK: Status
    /// Coarse pass state, read only by `AnalysisQueueController`. **No view
    /// reads it** — the inspector's control row switches on `queue.status(of:)`,
    /// which knows about waiting and queue position where this does not.
    internal enum Status: Equatable {
        case idle
        case analyzing(progress: Double)
        case done
        case failed(message: String)
    }
    
    // MARK: Live Search

    /// What the engine is doing *right now*, for the queue window to render.
    ///
    /// **Deliberately here and not on the model, which is the whole point.**
    /// The 6 Aug write-coalescing pass exists because `PGN.evaluations` was
    /// being written per `info` line, and every such write re-encoded a Codable
    /// array and invalidated every view observing that game. This is the same
    /// per-line cadence with none of that: a small value on an object whose
    /// only observers are the queue controller and the window, so a batch
    /// running with the window closed costs one property write per line and
    /// wakes nothing.
    ///
    /// Nil between plies and after a pass ends — a stale search left on screen
    /// after the engine moved on is a read-out describing nothing, which is the
    /// argument D46′'s hover read-out makes for clearing on exit.
    internal struct Search: Equatable, Sendable {
        /// 0-based ply index within the game.
        internal let plyIndex: Int
        internal let totalPlies: Int
        /// The move whose resulting position is being searched, in SAN.
        internal let san: String
        internal let progress: EngineProgress

        /// The depth this pass was asked for — the `18` in `go depth 18`.
        ///
        /// **What the window's Depth fact shows since 8 Aug 2026, by
        /// request.** It used to show `progress.depth`, the iteration the
        /// last info line came from — which climbs 1→18 inside every ply and
        /// resets at the next, so the readout spun continuously and read as
        /// the *setting* bouncing rather than as a search deepening. The
        /// target is the fact that holds still, and it is the one a reader
        /// can act on (it is the Settings slider). The per-line reached depth
        /// stays parsed and carried on `progress` for anything that ever
        /// wants the live figure back.
        internal let targetDepth: Int
    }

    internal private(set) var search: Search?

    // MARK: Stored Properties
    internal private(set) var status: Status = .idle

    private var engine: StockfishEngine?
    private var task: Task<Void, Never>?
    
    // MARK: Public API
    
    /// Runs one full-game pass and returns the terminal status — awaitable, so
    /// the controller knows when to advance. A no-op returning the current
    /// status if a pass is already in flight; the controller serializes calls,
    /// so that guard is belt and braces.
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
        // **`defer`, not a clear at each exit**, and this walk is why: there
        // are five ways out of it — engine start failure, an unparseable SAN, a
        // dead engine mid-pass, save failure past tolerance, and the ordinary
        // end — and a live search left on screen after any of them describes an
        // engine that has moved on. Four sites that must agree is the shape
        // D40′ and D45′ both argue against; one `defer` makes the next exit
        // somebody adds correct before they have written it.
        defer { search = nil }

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
        // store's contract; every D71′ exit save carries it (each failure
        // path persists before it returns), and the Library backfill is the
        // net for a pass that dies before any exit runs.
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
                //
                // The save first, because the message claims the earlier
                // evaluations were kept and D71′ means nothing has been
                // persisted yet — a claim about the store is checked against
                // the store before it is made.
                let saved = persist(modelContext, of: pgn)
                status = .failed(
                    message: "\(Self.moveLabel(plyIndex: index, san: san)) won't parse, "
                    + "analysis stopped there"
                    + (saved ? "; earlier evaluations were kept."
                             : ", and the library refused the save — earlier evaluations were lost.")
                )
                return
            }
            state = state.applying(move)
            let fen = FEN(state)
            
            // **One write per ply, not one per emission** (6 Aug 2026).
            //
            // Stockfish prints an `info` line carrying a score on every
            // iteration *and* again on every new best move, so one depth-18
            // search yields tens of evaluations for a single ply. The loop used
            // to write each of them into the model, which cost three things per
            // emission and bought nothing that survived the next one:
            //
            //   - `evaluations` is a Codable array on a `@Model`, so
            //     `evaluations[i] = x` is a read-modify-write of the *whole*
            //     array — a full re-encode of every ply to record one.
            //   - each write invalidates every view observing this `PGN`: the
            //     inspector's evaluation `Canvas`, the bar, Get Info's coverage
            //     rows, and every `AnalysisGlyph` site — several of which
            //     respond by re-scanning the array that was just re-encoded.
            //   - this is the main actor, so the loop hopped back to it per
            //     emission. Across an 80-ply game that is thousands of round
            //     trips through the thread drawing the UI, which is what made
            //     the whole app feel wedged while a batch ran.
            //
            // **The stored result is unchanged.** The stream's last yield is
            // the deepest search, and the deepest search is exactly what the
            // old loop left behind after overwriting itself N times. What is
            // genuinely given up is the sub-ply "watch it converge" flicker —
            // one x-position twitching for a fraction of a second. The
            // animation anyone actually reads is the curve growing a point per
            // ply, and that is untouched.
            //
            // A cancelled ply now writes nothing rather than storing whatever
            // depth it had reached when the stop landed, which is also the
            // better answer: a shallow eval stored as final is a lie the graph
            // draws, where a nil is a gap it honestly skips.
            // The loop reads every emission and *stores* the last, which is the
            // split the paragraph above is about: `search` is cheap live state
            // for the window, `deepest` is the one thing that reaches the model.
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

            // If we exited the inner loop via cancellation, skip the write and
            // the progress update — the cancellation exit below persists what
            // stands, and we don't want a brief "still analyzing" flicker on
            // the way out.
            if Task.isCancelled { break }

            // Nil only when the stream yielded nothing at all, which means the
            // engine died mid-ply; the `isRunning` guard below is what reports
            // that. Leaving the slot nil rather than writing a placeholder
            // keeps `evaluations` saying "this ply was never scored", which is
            // what the Analysis Data window's em-dash rows read (D73′ — Get
            // Info's "48 of 58" row read it until 8 Aug 2026).
            if let deepest { pgn.evaluations[index] = deepest }

            // A dead engine finishes every remaining stream instantly, so
            // the old loop raced through the tail and landed on `.done`
            // with nothing evaluated (M1 item 9b). One actor hop per ply
            // is nothing next to the search that just ran.
            guard await engine.isRunning else {
                Self.logger?.error(
                    "Engine died mid-pass at ply \(index + 1)/\(total) for pgn='\(pgn.name, privacy: .public)'"
                )
                // Save before the claim, the SAN-failure exit's rule (D71′).
                let saved = persist(modelContext, of: pgn)
                status = .failed(
                    message: "The engine quit at \(Self.moveLabel(plyIndex: index, san: san)) "
                    + "(ply \(index + 1) of \(total))"
                    + (saved ? "; evaluations up to there were kept."
                             : ", and the library refused the save — evaluations were lost.")
                )
                return
            }

            status = .analyzing(
                progress: Double(index + 1) / Double(max(total, 1))
            )

            // **No save here, and the absence is the decision (D71′).** The
            // per-ply `modelContext.save()` this loop carried was the last
            // per-ply fan-out in the app: a save invalidates every `@Query`
            // in every open window, so each of an 80-ply game's plies re-ran
            // the Library's fetch, its sort and its table diff — and Players',
            // and any Get Info's — with the fold memo (D70′) only softening
            // the blow. What the cadence bought was crash-durability of a
            // *partial* pass, and a partial pass is worth nothing durable:
            // the walk resets `evaluations` before it starts, so a crash's
            // partials would be destroyed by the re-run anyway — while making
            // the game read *analyzed* to every surface in between (D67′'s
            // exact false state, persisted on purpose). One save per exit
            // keeps every promise the per-ply save actually delivered.
            //
            // What is genuinely given up: the in-flight game's evaluations
            // now reach disk at its end, so a *hard crash* mid-game loses
            // that one game's partials — which the next pass would have
            // discarded regardless. Open windows lose nothing: an observed
            // model's in-memory mutations still re-render its own surfaces
            // (the inspector's filling graph is untouched); what stops is
            // every *other* window re-fetching per ply.
        }

        // The three ordinary exits, each persisting what the walk wrote:
        // cancellation keeps its recorded promise ("evaluations recorded
        // before the stop were kept" — the queue window's cancelled row), and
        // a completed pass lands `.done` only if the store took the result. A
        // failed save on the done path is `.failed`, not `.done`-with-Console:
        // a green result that vanishes at relaunch is the exact E1 shape the
        // old tolerance exit existed for (1 Aug review), kept under the new
        // cadence.
        if Task.isCancelled {
            if !persist(modelContext, of: pgn) {
                Self.logger?.error(
                    "Cancelled pass could not persist its partial evaluations for pgn='\(pgn.name, privacy: .public)' — the cancelled row's 'were kept' does not hold this once"
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
                message: "Analysis finished, but the library refused the save; "
                + "the evaluations were not stored and will be gone after a relaunch."
            )
        }
    }

    /// The one save (D71′): everything the pass wrote — the evaluations, and
    /// the classification stamped before ply one — in a single transaction at
    /// an exit. Returns whether it landed; the caller owns what that means,
    /// because the honest message differs per exit.
    ///
    /// Failure is logged here so no exit can forget to, per the grammar's
    /// rule 7 — and the log names the game, because by the time a reader sees
    /// it the queue has moved on.
    private func persist(_ modelContext: ModelContext, of pgn: PGN) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            Self.logger?.error(
                "Evaluation save failed for pgn='\(pgn.name, privacy: .public)': \(error.localizedDescription, privacy: .public) — in-memory results still render until relaunch"
            )
            return false
        }
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
