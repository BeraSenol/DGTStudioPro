//
//  LiveGame+Draft.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 13/06/2026.
//

import Foundation

/// Draft conversion for the live model (M4): `draftSnapshot` projects the
/// game into its on-disk form, and `init(resuming:)` rebuilds a game from
/// one by replaying the SAN transcript through the chess core — the same
/// pattern `Game(pgn:)` uses, with the same "throw on the first
/// inconsistency" stance. Both directions live here, with the model, so
/// `LiveGameDraft` itself stays a passive schema with no `@MainActor`
/// references.
extension LiveGame {
    
    // MARK: Errors
    
    /// Why a draft could not be resumed. Every case means the file does not
    /// describe a game this build's rules can reproduce — the UI's only
    /// offer for such a draft is deletion (Decision #3: resume or delete,
    /// nothing else).
    internal enum ResumeError: Error, Equatable {
        /// `startFEN` failed to parse into a legal starting state.
        case invalidStart(fen: String)
        /// A SAN string failed to parse against the state reached after the
        /// prior moves — same diagnostic shape as `Game.BuildError`.
        case invalidMove(index: Int, san: String)
        /// A SAN parsed but the model refused to commit it (e.g. moves
        /// continue after a position the rules say is already terminal).
        case moveRejected(index: Int, san: String)
        /// The replayed transcript doesn't reproduce the draft's — the file
        /// was edited or written by diverging rules.
        case transcriptMismatch
        /// The draft's stored result contradicts what the replay derived
        /// (e.g. the moves end in checkmate but the draft claims a different
        /// decided result).
        case resultMismatch(stored: GameResult, replayed: GameResult)
    }
    
    // MARK: Snapshot
    
    /// The game's current on-disk form. `updatedAt` is stamped at snapshot
    /// time — the session takes one of these after every committed ply and
    /// every result/roster change.
    internal var draftSnapshot: LiveGameDraft {
        LiveGameDraft(
            schemaVersion: LiveGameDraft.currentSchemaVersion,
            startFEN: FEN(states[0]).string,
            ruleSet: ruleSet,
            event: roster.event,
            site: roster.site,
            date: roster.date,
            round: roster.round,
            white: roster.white,
            black: roster.black,
            sanMoves: sanMoves,
            result: result,
            startedAt: startedAt,
            updatedAt: .now
        )
    }
    
    // MARK: Resume
    
    /// Rebuilds a live game from a draft by replaying its SAN transcript
    /// through the normal `commit` path — legality checks, SAN
    /// re-serialization, tracker walk, and auto result detection are all the
    /// real ones, so a successful resume is equivalent-by-construction to
    /// the original game, and any divergence throws a `ResumeError` (the
    /// corrupt-draft path: the UI offers Delete).
    ///
    /// Result reconciliation after the replay:
    /// - replay derived a terminal result (mate/stalemate) → it must equal
    ///   the draft's, or the draft is inconsistent;
    /// - replay ended `.ongoing` but the draft is decided → that's a manual
    ///   result (resignation / agreed draw); re-apply it;
    /// - replay derived a terminal result but the draft says `.ongoing` →
    ///   inconsistent: the draft is written *after* every commit, so a
    ///   final-move mate is always already in the stored result.
    internal convenience init(resuming draft: LiveGameDraft) throws(ResumeError) {
        let start: GameState
        do {
            start = GameState(try FEN(parsing: draft.startFEN))
        } catch {
            throw ResumeError.invalidStart(fen: draft.startFEN)
        }
        
        self.init(
            start: start,
            roster: .init(
                event: draft.event,
                site: draft.site,
                date: draft.date,
                round: draft.round,
                white: draft.white,
                black: draft.black
            ),
            ruleSet: draft.ruleSet,
            startedAt: draft.startedAt
        )
        
        for (index, san) in draft.sanMoves.enumerated() {
            let move: Move
            do {
                move = try currentState.parseSAN(san)
            } catch {
                throw ResumeError.invalidMove(index: index, san: san)
            }
            guard commit(move) else {
                throw ResumeError.moveRejected(index: index, san: san)
            }
        }
        
        guard sanMoves == draft.sanMoves else {
            throw ResumeError.transcriptMismatch
        }
        
        switch (isFinished, draft.result) {
        case (true, let stored) where stored != result:
            throw ResumeError.resultMismatch(stored: stored, replayed: result)
        case (false, .whiteWins):
            resign(.black)              // manual result: White won
        case (false, .blackWins):
            resign(.white)              // manual result: Black won
        case (false, .draw):
            agreeDraw()                 // manual result: agreed draw
        default:
            break                       // ongoing as stored, or terminal & matching
        }
    }
}
