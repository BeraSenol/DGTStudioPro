// MARK: Session Phase

extension LiveGameHUDView.Phase {

    /// The one resolution of "what is the session doing right now", shared by
    /// the sidebar's status card and the Board's toolbar subtitle.
    ///
    /// **Why this moved out of `SessionSidebarPanel`.** It was a private
    /// computed property on that view, which was correct while the card was
    /// the only consumer. The subtitle is the second, and re-deriving the
    /// ordering at the toolbar would have made it the third spelling of
    /// session state in the app — the exact defect D15′ recorded catching in
    /// `RecoveryGuidance`, where two *computations* were the decision and two
    /// *spellings* of it were not. This deliberately mirrors that fix down to
    /// the signature: `current(session:connection:)`, `@MainActor`, an
    /// extension beside the type it produces.
    ///
    /// **The ordering is the content.** Session flags overlap — a game can be
    /// finished *and* the archive failed, a board can be disconnected *while*
    /// a recovery is pending — and both consumers must resolve the overlap
    /// identically or the sidebar and the toolbar will disagree in front of
    /// the user. Reading top to bottom, each `return` outranks everything
    /// below it:
    ///
    /// 1. **Reconnecting** outranks everything, including a pending recovery:
    ///    with no live port there is nothing to reconcile against.
    /// 2. **Disconnected** answers nil rather than a phase — no board, no
    ///    session status. This is the guard that keeps a review tab quiet.
    /// 3. **Recovery** outranks a correction: both mean "the physical board
    ///    disagrees", and the harder one wins.
    /// 4. **Correction** outranks awaiting-setup, which outranks any game.
    /// 5. Within a live game, a **failed archive** outranks the plain
    ///    finished banner — the player must Retry or discard before anything
    ///    else (M5).
    ///
    /// Not a pure core in the D10′ sense, and deliberately so: every input is
    /// a member of one of the two `@MainActor` app-global observables, and
    /// funnelling them through a snapshot value would buy testability the
    /// `@MainActor` session suites already have while adding a type whose
    /// only job is to be copied. `RecoveryGuidance.current` made the same
    /// call, and this stands beside it.
    @MainActor
    internal static func current(
        session: DGTLiveSession,
        connection: DGTConnection
    ) -> Self? {
        if connection.isReconnecting { return .reconnecting }
        guard connection.isConnected else { return nil }

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
