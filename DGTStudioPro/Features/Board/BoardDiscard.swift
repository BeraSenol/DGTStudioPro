/// The Board's Discard contract (D85′): two meanings, one button, mode-decided - and one
/// spelling of the destructive copy for both doors (the toolbar's dialog and the inspector's),
/// because two doors with two dialogs is the twin-read-site shape in dialog clothes.
enum BoardDiscard {

    /// What pressing Discard would do right now. Nil is the disabled state, and it is
    /// producible both ways: an empty tab over no live game.
    enum Action: Equatable {
        /// Reviewing an archived game: unload the tab back to the mirror. **The Library row
        /// is untouched** - discard-from-board is not delete-from-Library, and the button's
        /// help says so. Nondestructive, so no confirmation.
        case clearReview
        /// A live recording: the double-check the feature was asked for, then
        /// `session.discardGame()`.
        case discardLive
    }

    /// The mode decision, one predicate for the button's action, enablement and help.
    /// Reviewing wins when both hold: the button acts on the tab's subject, and a tab showing
    /// an archived game shows the review board - the live game keeps its own Discard in the
    /// inspector.
    static func action(isReviewing: Bool, hasLiveGame: Bool) -> Action? {
        if isReviewing { return .clearReview }
        if hasLiveGame { return .discardLive }
        return nil
    }

    /// The button's help per state - the nondestructive arm must say the Library survives.
    static func help(for action: Action?) -> String {
        switch action {
        case .clearReview: "Clear the board. The game stays in your Library."
        case .discardLive: "Discard the live game. It won't be saved."
        case nil:          "Nothing to discard."
        }
    }

    // MARK: One Spelling of the Copy (both dialogs read these)

    static let confirmationTitle   = "Discard this game?"
    static let confirmationButton  = "Discard Game"
    static let confirmationMessage = "The game and its moves will be lost. It won't be saved to the Library."
}
