//
//  RecoveryGuidance.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/07/2026.
//

/// The per-square instructions for restoring a desynced physical board to
/// the game's last legal position (M6.2; Decision #1 locks FIDE semantics —
/// the only resolution is restoring that position, so there is nothing to
/// decide here, only squares to fix).
///
/// A pure formatter over `DGTBoardDiff(from: physical, to: target)`:
/// - occupied on the board, empty in the target → **remove**;
/// - empty on the board, occupied in the target → **place**;
/// - occupied by the wrong piece → **replace**.
///
/// Recomputed by the view layer on every physical change, so highlights and
/// the instruction list shrink square by square as the player fixes the
/// board (a 64-square diff is cheap; reach for `.task(id:)` memoization
/// only if profiling ever demands it). The board views render
/// `attentionSquares` / `targetSquares` as generic styles and know nothing
/// about recovery — the same division of labor as the castling ghost.
internal struct RecoveryGuidance: Equatable, Sendable {
    
    // MARK: Item
    
    /// One square to fix, with a ready-to-display instruction.
    internal struct Item: Equatable, Sendable, Identifiable {
        
        internal enum Action: Equatable, Sendable {
            /// The board holds a piece where the target square is empty.
            case remove(Piece)
            /// The target square holds a piece; the board square is empty.
            case place(Piece)
            /// Both squares are occupied, by different pieces.
            case replace(current: Piece, expected: Piece)
        }
        
        internal let square: Square
        internal let action: Action
        
        /// One item per square, so the square doubles as a stable identity
        /// for SwiftUI lists.
        internal var id: Square { square }
        
        /// e.g. "c3 — remove the White Knight",
        /// "g1 — place the White Knight",
        /// "e4 — replace the Black Pawn with the White Knight".
        internal var message: String {
            switch action {
            case .remove(let piece):
                "\(square.algebraicNotation) — remove the \(Self.name(of: piece))"
            case .place(let piece):
                "\(square.algebraicNotation) — place the \(Self.name(of: piece))"
            case .replace(let current, let expected):
                "\(square.algebraicNotation) — replace the \(Self.name(of: current)) "
                + "with the \(Self.name(of: expected))"
            }
        }
        
        /// "White Knight" etc. Lives here rather than on `Piece` — this is
        /// the only place v1 needs prose piece names, and the chess core
        /// stays presentation-free.
        private static func name(of piece: Piece) -> String {
            guard let color = piece.color, let type = piece.type else {
                return "piece"      // unreachable for occupied squares; kept total
            }
            let colorName = switch color {
            case .white: "White"
            case .black: "Black"
            }
            let typeName = switch type {
            case .pawn:   "Pawn"
            case .knight: "Knight"
            case .bishop: "Bishop"
            case .rook:   "Rook"
            case .queen:  "Queen"
            case .king:   "King"
            }
            return "\(colorName) \(typeName)"
        }
    }
    
    // MARK: Stored Properties
    
    /// Every square to fix, sorted by square index (a1 → h8) so the list is
    /// deterministic for the UI and for table-driven tests.
    internal let items: [Item]
    
    // MARK: Computed Properties
    
    /// Squares rendered with the `.attention` style: something is here that
    /// shouldn't be (a removal or a wrong piece).
    internal var attentionSquares: Set<Square> {
        Set(items.compactMap {
            switch $0.action {
            case .remove, .replace: $0.square
            case .place: nil
            }
        })
    }
    
    /// Squares rendered with the `.target` style: a piece belongs on this
    /// empty square. Wrong-piece squares stay attention-only — the
    /// instruction text carries what belongs there, and stacking both
    /// styles on one square reads as noise.
    internal var targetSquares: Set<Square> {
        Set(items.compactMap {
            if case .place = $0.action { $0.square } else { nil }
        })
    }
    
    internal var isEmpty: Bool { items.isEmpty }
    
    // MARK: Initializer
    
    internal init(physical: Position, target: Position) {
        let diff = DGTBoardDiff(from: physical, to: target)
        var items: [Item] = []
        
        // `vacated`: occupied on the board, empty in the target → remove.
        for (square, piece) in diff.vacated {
            items.append(Item(square: square, action: .remove(piece)))
        }
        // `placed`: the target square is occupied and differs — a plain
        // placement when the physical square is empty, otherwise a swap.
        for (square, expected) in diff.placed {
            let current = physical[square]
            items.append(Item(
                square: square,
                action: current.isOccupied
                ? .replace(current: current, expected: expected)
                : .place(expected)
            ))
        }
        
        self.items = items.sorted { $0.square < $1.square }
    }
}
