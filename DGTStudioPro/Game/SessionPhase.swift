// MARK: Session Phase

extension LiveGameHUDView.Phase {

    /// The one resolution of "what is the session doing", shared by the sidebar card and the
    /// Board's subtitle - two computations was fine; two *spellings* of the priority order was not.
    /// Connection truth outranks session state; a failed archive outranks the finished banner.
    @MainActor
    static func current(
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
