//
//  DGTBoardSimulator.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 26/05/2026.
//

@testable import DGTStudioPro

/// A hardware-free stand-in for a physical DGT board, used to drive the
/// reconstruction engine in tests without any serial I/O. It folds a sequence
/// of field updates (lift = piece→empty, place = empty→piece) onto a starting
/// position, exposing the board after every step so a test can assert what the
/// reconstructor would conclude at each intermediate state as well as at the
/// final, settled state.
///
/// Mirrors how a real board reports a move as several discrete field updates;
/// the per-move-class update orderings live in the tests that use it.
internal struct DGTBoardSimulator {

    /// One field update: the square that changed and what now occupies it.
    internal typealias Update = (square: Square, piece: Piece)

    /// The running physical board.
    private(set) internal var board: Position

    internal init(_ start: Position) {
        board = start
    }

    /// Applies a single field update.
    internal mutating func apply(_ update: Update) {
        board[update.square] = update.piece
    }

    /// Folds `updates` onto `start`, returning the board after each step (the
    /// stream a reconstructor would see). Does not include `start` itself.
    internal static func boards(
        from start: Position,
        updates: [Update]
    ) -> [Position] {
        var simulator = DGTBoardSimulator(start)
        return updates.map { update in
            simulator.apply(update)
            return simulator.board
        }
    }

    /// Convenience: the final board after applying all `updates` to `start`.
    internal static func finalBoard(
        from start: Position,
        updates: [Update]
    ) -> Position {
        boards(from: start, updates: updates).last ?? start
    }
}
