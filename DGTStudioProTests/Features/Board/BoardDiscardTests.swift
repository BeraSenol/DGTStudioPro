import Testing
@testable import DGTStudioPro

/// Pins D85′: the mode table, the precedence, the disabled state's producibility, and the
/// one spelling of the destructive copy both dialogs read. Nonisolated - a pure predicate
/// over two facts, load-bearing.
@Suite("Board Discard")
struct BoardDiscardTests {

    /// Four cells, four distinct answers - and the both-true cell is the precedence pin:
    /// reviewing wins, because the button acts on the tab's visible subject.
    @Test func theModeTableIsTotalAndReviewingWins() {
        #expect(BoardDiscard.action(isReviewing: true, hasLiveGame: true) == .clearReview)
        #expect(BoardDiscard.action(isReviewing: true, hasLiveGame: false) == .clearReview)
        #expect(BoardDiscard.action(isReviewing: false, hasLiveGame: true) == .discardLive)
        #expect(BoardDiscard.action(isReviewing: false, hasLiveGame: false) == nil)
    }

    /// The disabled guard's enabling value is producible both ways (D40′'s check at minting):
    /// loading a game enables from one side, starting a live game from the other.
    @Test func theDisabledStateIsEscapableFromBothSides() {
        let disabled = BoardDiscard.action(isReviewing: false, hasLiveGame: false)
        #expect(disabled == nil)
        #expect(BoardDiscard.action(isReviewing: true, hasLiveGame: false) != nil)
        #expect(BoardDiscard.action(isReviewing: false, hasLiveGame: true) != nil)
    }

    /// Three helps, three distinct sentences - and the nondestructive arm must say the
    /// Library survives, which is the whole difference between the two meanings.
    @Test func helpNamesEachModesConsequence() {
        #expect(BoardDiscard.help(for: .clearReview) == "Clear the board. The game stays in your Library.")
        #expect(BoardDiscard.help(for: .discardLive) == "Discard the live game. It won't be saved.")
        #expect(BoardDiscard.help(for: nil) == "Nothing to discard.")
    }

    /// The copy both dialogs read, pinned to the word - the inspector's dialog carried these
    /// literals before D85′, so a drift here is a drift the user would see twice.
    @Test func theSharedCopyIsPinnedToTheWord() {
        #expect(BoardDiscard.confirmationTitle == "Discard this game?")
        #expect(BoardDiscard.confirmationButton == "Discard Game")
        #expect(
            BoardDiscard.confirmationMessage
                == "The game and its moves will be lost. It won't be saved to the Library."
        )
    }
}
