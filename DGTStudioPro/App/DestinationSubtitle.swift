//
//  DestinationSubtitle.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 03/08/2026.
//

// MARK: Destination Subtitle

/// The toolbar subtitle grammar for all three destinations — a pure
/// formatter, `GameHeadline`'s shape and for `GameHeadline`'s reason: the
/// destinations are different views onto one line of chrome, and the grammar
/// is the part worth pinning. The views stay dumb.
///
/// **The slot is narrow, which is what makes it useful.** Two neighbours
/// already have jobs. `navigationTitle` is *identity* — the game's name, the
/// filter's name, "Players" — and is untouched by this type. `GameHeadline`
/// is *the pairing*, and its own doc calls the title "one glance up". So the
/// only non-redundant job left is **state**: what is true right now that a
/// glance at the content does not already say. A subtitle reading "412 games"
/// over a list of 412 games is decoration.
///
/// **Every case can answer nil, and several routinely do.** A subtitle that
/// is always populated is one you stop reading — the `.DS_Store` lesson, and
/// the same reason the serial enumeration count was demoted to `.debug` on
/// the day this was written. Nothing to say is a first-class answer here, not
/// a fallback.
internal enum DestinationSubtitle {

    // MARK: Board

    /// The Board's subtitle: session status while playing, position status
    /// while reviewing, nothing when there is neither.
    ///
    /// **Exceptional states replace the routine one rather than joining it.**
    /// `phase` arrives already priority-ordered (see
    /// `LiveGameHUDView.Phase.current`), so "Desynced" versus "White to move"
    /// is never a decision made here — the resolver settled it, and this type
    /// would be the place a second, quietly different ordering crept in.
    ///
    /// `reviewing` is the loaded game's side to move, and is what makes a
    /// review tab say something at all: `phase` is about the physical board,
    /// which has nothing to do with a game being read out of the Library. The
    /// caller passes one or the other, never both — it branches on
    /// `tabState.boardPGN` exactly as the destination's own body does.
    internal static func board(
        phase: LiveGameHUDView.Phase?,
        reviewing sideToMove: PieceColor?
    ) -> String? {
        if let sideToMove {
            // `GameHeadline.Activity.reviewing.rawValue`, not the literal:
            // that enum owns the app's user-facing verbs, and a second
            // "Reviewing" here is how the inspector headline and the toolbar
            // drift apart on a word they both show at once.
            return "\(GameHeadline.Activity.reviewing.rawValue) · \(sideToMove.toMoveDescription)"
        }
        guard let phase else { return nil }
        switch phase {
        // Named for the problem, not the response. "Recovering" describes
        // what the app is doing; "Desynced" describes what is wrong, which is
        // the more useful word when you have one. It is also the vocabulary
        // `DGTSessionLog.recordDesync` already uses.
        case .recovering:    return "Desynced"
        case .correction:    return "Fix a piece"
        case .awaitingSetup: return "Set up pieces"
        case .reconnecting:  return "Reconnecting"
        case .archiveFailed: return "Not saved"
        case .finished:      return "Finished"
        case .playing(let side, _, _):
            return "\(GameHeadline.Activity.recording.rawValue) · \(side.toMoveDescription)"
        // Deliberately silent. A connected board with no game is the resting
        // state of the app, and the sidebar's card already says "Board
        // connected" for anyone who wants it. Rendering "Idle" here would put
        // a permanent word in the chrome that never means anything.
        case .idle:          return nil
        }
    }

    // MARK: Library

    /// Selection when there is one, otherwise the analysis backlog, otherwise
    /// nothing.
    ///
    /// The backlog is the only unprompted thing the Library has worth saying:
    /// it is *actionable* — there is a batch queue one click away — and it
    /// goes quiet at zero, so a fully analysed library shows a bare title. A
    /// running total of games would be neither.
    internal static func library(selected: Int, unanalyzed: Int) -> String? {
        if selected > 0 { return "\(selected) selected" }
        return unanalyzed > 0 ? "\(unanalyzed) unanalyzed" : nil
    }

    // MARK: Players

    /// One player selected says nothing — the inspector profile is right
    /// there. **Exactly two** is the interesting case, and the reason this
    /// function exists: selecting two people is how you ask a head-to-head
    /// question, and until now that gesture produced a bare count.
    ///
    /// `record` is wins–draws–losses **from `first`'s side**, so the names
    /// bracket the numbers in reading order: "Giri 7–3–2 Ding". The
    /// asymmetry is the whole content, which is why the caller passes an
    /// ordered pair rather than a set.
    internal static func players(
        selected: Int,
        headToHead: (first: String, second: String, record: (Int, Int, Int))?
    ) -> String? {
        if let h = headToHead {
            let (wins, draws, losses) = h.record
            return "\(h.first) \(wins)–\(draws)–\(losses) \(h.second)"
        }
        return selected > 1 ? "\(selected) selected" : nil
    }
}

// MARK: Side to Move

extension PieceColor {

    /// "White to move" / "Black to move".
    ///
    /// Extracted from `LiveGameHUDView.title`, which had the only copy — and
    /// which the subtitle would otherwise have restated three feet away in
    /// the same window. The two surfaces are visible simultaneously, so a
    /// drift between "to move" and "to play" would be on screen at once.
    ///
    /// Deliberately **not** on `PieceColor` in `Piece.swift`: that file is
    /// chess-core, which the purity invariant keeps free of I/O, actors and —
    /// by the same spirit — user-facing English. This is presentation, so it
    /// lives with the presentation code and reaches back via an extension.
    internal var toMoveDescription: String {
        self == .white ? "White to move" : "Black to move"
    }
}
