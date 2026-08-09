import Foundation

/// Draft conversion: `draftSnapshot` projects to disk form; `init(resuming:)` replays the SAN
/// transcript through the chess core.
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
            board: roster.board,
            sanMoves: sanMoves,
            result: result,
            startedAt: startedAt,
            updatedAt: .now
        )
    }
    
    // MARK: Resume
    
    /// Rebuilds by replaying through the normal `commit` path — legality, SAN re-serialization,
    /// tracker walk and auto-result all come free; a replay-derived terminal result must equal the
    /// draft's or the file is corrupt.
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
                black: draft.black,
                board: draft.board   // D28′ — a resumed game keeps its board
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
