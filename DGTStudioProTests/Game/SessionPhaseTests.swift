import Testing
import Foundation
@testable import DGTStudioPro

/// Pins the phase ladder (M18 - `SessionPhase`, out of `LiveGameHUDView.Phase`). The waiver
/// register carried this ordering as "the content, and nothing automated checks it"; the
/// scalar connection gate is what retires that regret - every arm below runs off a headless
/// session, connection truth arriving as two named facts.
@MainActor
@Suite("Session Phase")
struct SessionPhaseTests {

    private func roster() -> LiveGame.Roster {
        .init(white: "White", black: "Black")
    }

    /// The armed-settle await, `DGTLiveSessionTests`' helper verbatim.
    private func settled(_ session: DGTLiveSession) async throws {
        let armed = try #require(session.quiescenceTask)
        await armed.value
    }

    /// A session tracking a live game from the starting position.
    private func playingSession() -> DGTLiveSession {
        let session = DGTLiveSession()
        session.quiescence = .milliseconds(10)
        session.boardChanged(.starting)
        session.startNewGame(roster: roster())
        return session
    }

    // MARK: Connection Truth First

    /// A pulled cable outranks everything - including the gate below it: reconnecting reads
    /// as reconnecting whatever `isConnected` says, because the chase *is* the state.
    @Test func reconnectingOutranksALiveGame() {
        let session = playingSession()
        #expect(SessionPhase.current(isReconnecting: true, isConnected: true, session: session) == .reconnecting)
        #expect(SessionPhase.current(isReconnecting: true, isConnected: false, session: session) == .reconnecting)
    }

    /// Plain disconnected has no phase at all - the card's absence is the message.
    @Test func disconnectedIsNoPhase() {
        let session = playingSession()
        #expect(SessionPhase.current(isReconnecting: false, isConnected: false, session: session) == nil)
    }

    // MARK: The Session Ladder

    @Test func aFreshConnectedSessionIsIdle() {
        let session = DGTLiveSession()
        #expect(SessionPhase.current(isReconnecting: false, isConnected: true, session: session) == .idle)
    }

    @Test func aNewGameWithoutTheBoardAwaitsSetup() {
        let session = DGTLiveSession()
        session.startNewGame(roster: roster())
        #expect(SessionPhase.current(isReconnecting: false, isConnected: true, session: session) == .awaitingSetup)
    }

    /// The live facts ride the payload: side to move, last SAN, ply - fresh start and after
    /// one committed move, two distinct expectations.
    @Test func playingCarriesTheLiveFacts() async throws {
        let session = playingSession()
        #expect(
            SessionPhase.current(isReconnecting: false, isConnected: true, session: session)
                == .playing(sideToMove: .white, lastSAN: nil, ply: 0)
        )

        let e4 = try GameState.starting.parseSAN("e4")
        session.boardChanged(GameState.starting.applying(e4).position)
        try await settled(session)

        #expect(
            SessionPhase.current(isReconnecting: false, isConnected: true, session: session)
                == .playing(sideToMove: .black, lastSAN: "e4", ply: 1)
        )
    }

    /// The EP nudge surfaces as `.correction` with the hint's own message - and it outranks
    /// `.playing`, which is what makes the card interrupt.
    @Test func aCorrectionOutranksPlaying() async throws {
        let session = playingSession()

        var state = GameState.starting
        for san in ["e4", "a6", "e5", "d5"] {
            state = state.applying(try state.parseSAN(san))
            session.boardChanged(state.position)
            try await settled(session)
        }
        let midCorrection = DGTBoardSimulator.finalBoard(
            from: state.position,
            updates: [(Squares.e5, .empty), (Squares.d6, .whitePawn)]
        )
        session.boardChanged(midCorrection)
        try await settled(session)

        #expect(
            SessionPhase.current(isReconnecting: false, isConnected: true, session: session)
                == .correction(message: "Remove the captured pawn on d5 to complete exd6.")
        )
    }

    /// An inexplicable board is `.recovering`, carrying the last committed SAN - hookless, so
    /// the first unresolved settle enters recovery immediately.
    @Test func anInexplicableBoardIsRecovering() async throws {
        let session = playingSession()

        let e4 = try GameState.starting.parseSAN("e4")
        session.boardChanged(GameState.starting.applying(e4).position)
        try await settled(session)

        var garbage = Position.starting
        garbage[Squares.e5] = .whitePawn
        session.boardChanged(garbage)
        try await settled(session)

        #expect(
            SessionPhase.current(isReconnecting: false, isConnected: true, session: session)
                == .recovering(lastSAN: "e4")
        )
    }

    /// A decided game banners its result; hookless archive leaves no outcome, so this is the
    /// plain `.finished` arm.
    @Test func aFinishedGameBannersItsResult() {
        let session = playingSession()
        session.resign(.white)

        #expect(
            SessionPhase.current(isReconnecting: false, isConnected: true, session: session)
                == .finished(result: .blackWins)
        )
    }

    /// A failed archive outranks the finished banner - the player must Retry or discard, so
    /// the ladder must not read "finished" past an unsaved game.
    @Test func aFailedArchiveOutranksTheFinishedBanner() {
        struct Refusal: Error {}
        let session = playingSession()
        session.onGameFinished = { _ in throw Refusal() }
        session.resign(.white)

        guard case .archiveFailed(let result, let message)? = SessionPhase.current(
            isReconnecting: false, isConnected: true, session: session
        ) else {
            Issue.record("Expected .archiveFailed")
            return
        }
        #expect(result == .blackWins)
        #expect(!message.isEmpty)
    }
}
