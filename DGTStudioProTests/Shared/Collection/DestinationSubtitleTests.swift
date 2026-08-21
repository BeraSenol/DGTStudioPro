import Testing
@testable import DGTStudioPro

/// The subtitle grammar, pinned the way `GameHeadline` is: views dumb, grammar held still.
/// Nonisolated, load-bearing (nested types don't inherit isolation).
@Suite("Destination Subtitle")
struct DestinationSubtitleTests {

    // MARK: Board - the exceptional vocabulary

    /// The words themselves - a change to window chrome should have to touch a test.
    @Test func exceptionalPhasesRenderAsOneShortWord() {
        func subtitle(_ phase: LiveGameHUDView.Phase) -> String? {
            DestinationSubtitle.board(phase: phase, reviewing: nil)
        }

        #expect(subtitle(.recovering(lastSAN: "Qd2")) == "Desynced")
        #expect(subtitle(.correction(message: "lift the pawn on e5")) == "Fix a piece")
        #expect(subtitle(.awaitingSetup) == "Set up pieces")
        #expect(subtitle(.reconnecting) == "Reconnecting")
        #expect(subtitle(.archiveFailed(result: .whiteWins, message: "disk full")) == "Not saved")
        #expect(subtitle(.finished(result: .draw)) == "Finished")
    }

    /// The payload never reaches the subtitle - the whole point of the line is that it stays a word.
    @Test func theSubtitleNeverLeaksAPhasePayload() {
        let subtitle = DestinationSubtitle.board(
            phase: .correction(message: "lift the pawn on e5"),
            reviewing: nil
        )
        #expect(subtitle == "Fix a piece")
        #expect(subtitle?.contains("e5") == false)
    }

    // MARK: Board - the routine cases

    @Test func playingCarriesTheSideToMove() {
        #expect(DestinationSubtitle.board(phase: .playing(sideToMove: .white, lastSAN: nil, ply: 0),
                                          reviewing: nil) == "Recording · White to move")
        #expect(DestinationSubtitle.board(phase: .playing(sideToMove: .black, lastSAN: "e4", ply: 1),
                                          reviewing: nil) == "Recording · Black to move")
    }

    @Test func reviewingCarriesTheSideToMove() {
        #expect(DestinationSubtitle.board(phase: nil, reviewing: .black)
                == "Reviewing · Black to move")
    }

    /// **Reviewing outranks the session.** A tab reading an archived game must
    /// not report the physical board's troubles - it is not party to them
    ///. Asserted against a phase that would otherwise win loudly, so
    /// this fails if the branches are ever reordered.
    @Test func aReviewTabIgnoresTheLiveSession() {
        #expect(DestinationSubtitle.board(phase: .recovering(lastSAN: nil), reviewing: .white)
                == "Reviewing · White to move")
    }

    /// The two silent cases, which are the ones most likely to be "fixed"
    /// into saying something. Idle is the app's resting state and a permanent
    /// word there means nothing; a nil phase is a disconnected board with no
    /// game, which has nothing to report either.
    @Test func theBoardSaysNothingWhenThereIsNothingToSay() {
        #expect(DestinationSubtitle.board(phase: .idle, reviewing: nil) == nil)
        #expect(DestinationSubtitle.board(phase: nil, reviewing: nil) == nil)
    }

    /// The verbs come from `GameHeadline.Activity`, asserted against that
    /// enum rather than against literals. A literal would keep passing while
    /// the inspector headline and the toolbar drifted apart on a word they
    /// both display at the same time - the `EvaluationGraphReading` lesson.
    @Test func theVerbsAreTheHeadlinesOwn() {
        let recording = DestinationSubtitle.board(
            phase: .playing(sideToMove: .white, lastSAN: nil, ply: 0), reviewing: nil
        )
        #expect(recording?.hasPrefix(GameHeadline.Activity.recording.rawValue) == true)

        let reviewing = DestinationSubtitle.board(phase: nil, reviewing: .white)
        #expect(reviewing?.hasPrefix(GameHeadline.Activity.reviewing.rawValue) == true)
    }

    // MARK: Library

    @Test func librarySelectionOutranksTheBacklog() {
        #expect(DestinationSubtitle.library(selected: 3, unanalyzed: 12) == "3 selected")
        #expect(DestinationSubtitle.library(selected: 1, unanalyzed: 0) == "1 selected")
    }

    /// The backlog clause vanishes at zero rather than reading "0
    /// unanalyzed" - a fully analyzed Library shows a bare title, which is
    /// the entire argument for putting the backlog here instead of a count.
    @Test func libraryGoesQuietWithNothingToDo() {
        #expect(DestinationSubtitle.library(selected: 0, unanalyzed: 7) == "7 unanalyzed")
        #expect(DestinationSubtitle.library(selected: 0, unanalyzed: 0) == nil)
    }

    // MARK: Players

    /// The names bracket the numbers in the order they were passed, so the
    /// record is readable in one direction only and that direction is stated
    /// on screen. A record printed without names, or with them the wrong way
    /// round, is plausible and wrong at the same time.
    @Test func headToHeadReadsFirstPlayerFirst() {
        #expect(DestinationSubtitle.players(
            selected: 2,
            headToHead: (first: "Anish Giri", second: "Liren Ding", record: (7, 3, 2))
        ) == "Anish Giri 7–3–2 Liren Ding")
    }

    /// One selected says nothing: the inspector profile is already showing
    /// everything a single player has. Two without a shared game falls back
    /// to the count rather than inventing 0–0–0.
    @Test func playersFallsBackToACountOrSilence() {
        #expect(DestinationSubtitle.players(selected: 0, headToHead: nil) == nil)
        #expect(DestinationSubtitle.players(selected: 1, headToHead: nil) == nil)
        #expect(DestinationSubtitle.players(selected: 2, headToHead: nil) == "2 selected")
        #expect(DestinationSubtitle.players(selected: 5, headToHead: nil) == "5 selected")
    }
}
