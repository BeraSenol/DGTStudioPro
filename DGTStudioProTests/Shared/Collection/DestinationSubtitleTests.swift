import Testing
@testable import DGTStudioPro

/// The toolbar subtitle grammar (3 Aug 2026), pinned the way `GameHeadline`
/// is: the views are dumb, the grammar is the part worth holding still.
///
/// Nonisolated, and that is load-bearing rather than stylistic — the D44′
/// shape. `DestinationSubtitle` takes a `LiveGameHUDView.Phase`, which is
/// nested inside a `@MainActor` view, and a global actor isolates a type's
/// *members*, not the types nested inside it. This suite constructing those
/// cases off the main actor is the compile-time witness that the formatter is
/// genuinely pure and hasn't quietly acquired isolation from its input.
@Suite("Destination Subtitle")
struct DestinationSubtitleTests {

    // MARK: Board — the exceptional vocabulary

    /// The words themselves. A change here is a change to what the window
    /// chrome says, which is exactly the kind of edit that should have to
    /// touch a test on the way through.
    ///
    /// Spelled out rather than parameterised: `arguments:` would need
    /// `Phase` to satisfy `Sendable`, which it does only implicitly, and a
    /// vocabulary pin is not worth resting on an inference.
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

    /// The payload never reaches the subtitle. `.correction` and
    /// `.recovering` both carry a message the sidebar card renders in full,
    /// and the whole point of this line is that it stays a word — a formatter
    /// that interpolated the hint would put the recovery guidance in the
    /// toolbar, which is the sidebar's job by D15′.
    @Test func theSubtitleNeverLeaksAPhasePayload() {
        let subtitle = DestinationSubtitle.board(
            phase: .correction(message: "lift the pawn on e5"),
            reviewing: nil
        )
        #expect(subtitle == "Fix a piece")
        #expect(subtitle?.contains("e5") == false)
    }

    // MARK: Board — the routine cases

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
    /// not report the physical board's troubles — it is not party to them
    /// (D15′). Asserted against a phase that would otherwise win loudly, so
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
    /// both display at the same time — the `EvaluationGraphReading` lesson.
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
    /// unanalyzed" — a fully analysed Library shows a bare title, which is
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
