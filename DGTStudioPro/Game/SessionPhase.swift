// MARK: Session Phase

/// Everything the session can be doing, priority-resolved - the domain answer to "what is the
/// app doing with my board right now?", rendered by `LiveGameHUDView` and worded again by
/// `DestinationSubtitle.board`.
///
/// **Its own type since 26 Aug 2026 (M18)** - it was `LiveGameHUDView.Phase`, domain priority
/// logic that could not compile without SwiftUI in scope, while the register and one doc
/// comment already called it `SessionPhase`; the code now agrees with what the documents knew.
/// The connection gate takes its two facts as named scalars precisely so a suite can drive
/// every arm off a headless session - the register's "nothing automated checks the ordering"
/// regret, retired by `SessionPhaseTests`.
enum SessionPhase: Equatable {
    case reconnecting
    /// Connected, no game running: invite setup or a manual New Game.
    case idle
    /// A game exists but the physical pieces don't match its position
    /// yet. Serves fresh starts in M3 and doubles as the resume prompt
    /// in M4 (the session's exit predicate is the *current* position).
    case awaitingSetup
    /// Live tracking: side to move, last SAN, ply count.
    case playing(sideToMove: PieceColor, lastSAN: String?, ply: Int)
    /// A legal move is recognized but one physical fix remains (e.g. an
    /// en-passant capture whose taken pawn wasn't lifted). A gentle
    /// nudge - visually distinct from recovery.
    case correction(message: String)
    /// The board can't be explained by any legal move - restore the last
    /// legal position. The per-square checklist renders below the card
    /// (`RecoveryGuidanceView`); this is only the headline.
    case recovering(lastSAN: String?)
    /// Terminal result reached and safely in the Library.
    case finished(result: GameResult)
    /// Terminal result reached but the Library save failed - the game
    /// is held (draft kept, new-game suppressed) until Retry succeeds
    /// or the player discards from the inspector.
    case archiveFailed(result: GameResult, message: String)

    /// The one resolution of "what is the session doing", shared by the session window's card
    /// and the Board's subtitle - two computations was fine; two *spellings* of the priority
    /// order was not. Connection truth outranks session state; a failed archive outranks the
    /// finished banner.
    ///
    /// The connection's two facts arrive as named scalars rather than the object: the session
    /// half of the ladder is then pinnable headless, and the one call site reads its booleans
    /// off the real `DGTConnection` in the same breath.
    @MainActor
    static func current(
        isReconnecting: Bool,
        isConnected: Bool,
        session: DGTLiveSession
    ) -> Self? {
        if isReconnecting { return .reconnecting }
        guard isConnected else { return nil }

        if session.needsRecovery {
            return .recovering(lastSAN: session.liveGame?.sanMoves.last)
        }
        if let hint = session.correctionHint {
            return .correction(message: hint.message)
        }
        if session.awaitingPhysicalSetup {
            return .awaitingSetup
        }
        if let game = session.liveGame {
            if game.isFinished {
                // A failed archive outranks the plain finished banner: the
                // player must Retry or discard before anything else (M5).
                if case .failed(let message) = session.archiveOutcome {
                    return .archiveFailed(result: game.result, message: message)
                }
                return .finished(result: game.result)
            }
            return .playing(
                sideToMove: game.currentState.activeColor,
                lastSAN: game.sanMoves.last,
                ply: game.plyCount
            )
        }
        return .idle
    }
}
