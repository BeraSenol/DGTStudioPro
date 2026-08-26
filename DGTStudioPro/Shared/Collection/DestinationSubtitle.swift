// MARK: Destination Subtitle

/// The toolbar subtitle grammar, all three destinations - a pure formatter (`GameHeadline`'s
/// shape). The subtitle's one job is **state**: what a glance at the content does not already
/// say. Nothing to say is a first-class answer.
enum DestinationSubtitle {

    // MARK: Board

    /// Board: session status while playing, position status while reviewing, nothing otherwise.
    /// Exceptional states replace the routine one. `phase` arrives already priority-ordered
    /// (`SessionPhase.current`) - re-ordering here would be the second, quietly different copy.
    ///
    /// (Dropped from the Board 16 Aug 2026 as a crash hypothesis, re-added 17 Aug by request
    /// once the hypothesis was disproven - the round trip is recorded at `BoardDestination`.)
    static func board(
        phase: SessionPhase?,
        reviewing sideToMove: PieceColor?
    ) -> String? {
        if let sideToMove {
            // The enum owns the app's user-facing verbs - a second "Reviewing" literal is how the headline
            // and the toolbar drift on a word they show at once.
            return "\(GameHeadline.Activity.reviewing.rawValue) · \(sideToMove.toMoveDescription)"
        }
        guard let phase else { return nil }
        switch phase {
        // Named for the problem, not the response - "Desynced" is `recordDesync`'s own vocabulary.
        case .recovering:    return "Desynced"
        case .correction:    return "Fix a piece"
        case .awaitingSetup: return "Set up pieces"
        case .reconnecting:  return "Reconnecting"
        case .archiveFailed: return "Not saved"
        case .finished:      return "Finished"
        case .playing(let side, _, _):
            return "\(GameHeadline.Activity.recording.rawValue) · \(side.toMoveDescription)"
        // Deliberately silent: a connected board with no game is the resting state, and "Idle" would be
        // a permanent word that never means anything.
        case .idle:          return nil
        }
    }

    // MARK: Library

    /// Selection when there is one, else the analysis backlog, else nothing.
    static func library(selected: Int, unanalyzed: Int) -> String? {
        if selected > 0 { return "\(selected) selected" }
        return unanalyzed > 0 ? "\(unanalyzed) unanalyzed" : nil
    }

    // MARK: Players

    /// One selected says nothing (the profile is right there). **Exactly two** is the head-to-head
    /// question: "Giri 7–3–2 Ding", numbers bracketed in reading order - an ordered pair, not a set.
    static func players(
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

    /// "White to move" - extracted from the HUD's only copy. Deliberately not in `Piece.swift`:
    /// that file is chess-core pure and this is UI copy.
    var toMoveDescription: String {
        self == .white ? "White to move" : "Black to move"
    }
}
