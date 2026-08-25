/// Per-square instructions for restoring a desynced board to the last legal position (Decision
/// #1 locks the resolution; there is nothing to decide, only squares to fix).
struct RecoveryGuidance: Equatable, Sendable {
    
    // MARK: Item
    
    /// One square to fix, with a ready-to-display instruction.
    struct Item: Equatable, Sendable, Identifiable {
        
        enum Action: Equatable, Sendable {
            /// The board holds a piece where the target square is empty.
            case remove(Piece)
            /// The target square holds a piece; the board square is empty.
            case place(Piece)
            /// Both squares are occupied, by different pieces.
            case replace(current: Piece, expected: Piece)
        }
        
        let square: Square
        let action: Action
        
        /// One item per square - the square doubles as stable identity.
        var id: Square { square }
        
        /// "c3 - remove the White Knight" / "g1 - place…" / "e4 - replace… with…".
        var message: String {
            switch action {
            case .remove(let piece):
                "\(square.algebraicNotation), remove the \(Self.name(of: piece))"
            case .place(let piece):
                "\(square.algebraicNotation), place the \(Self.name(of: piece))"
            case .replace(let current, let expected):
                "\(square.algebraicNotation), replace the \(Self.name(of: current)) "
                + "with the \(Self.name(of: expected))"
            }
        }
        
        /// Prose piece names live here - the chess core stays presentation-free.
        private static func name(of piece: Piece) -> String {
            guard let color = piece.color, let type = piece.type else {
                // Unreachable: every `Piece` an `Item` carries came from a diff map or from a
                // square already tested `isOccupied`, so both halves are non-nil. Kept total.
                return "piece"
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
    
    /// Sorted by square index (a1 → h8) - deterministic for UI and tests.
    let items: [Item]
    
    // MARK: Computed Properties
    
    /// `.attention`: something here shouldn't be.
    var attentionSquares: Set<Square> {
        Set(items.compactMap {
            switch $0.action {
            case .remove, .replace: $0.square
            case .place: nil
            }
        })
    }
    
    /// `.target`: a piece belongs on this empty square. Wrong-piece squares stay attention-only -
    /// stacking both styles reads as noise.
    var targetSquares: Set<Square> {
        Set(items.compactMap {
            if case .place = $0.action { $0.square } else { nil }
        })
    }
    
    var isEmpty: Bool { items.isEmpty }
    
    // MARK: Initializer
    
    /// **The diff runs backwards here, and that is the point.** Every other construction in the app
    /// asks `(from: game, to: physical)` - "what did the player do?". This one asks
    /// `(from: physical, to: target)` - "what must the player still do?" - so the type's vocabulary
    /// inverts with it: `vacated` names squares the *board* holds and the target does not, and
    /// `placed` names what the *target* wants. Read the two loops with that swap in mind.
    init(physical: Position, target: Position) {
        let diff = DGTBoardDiff(from: physical, to: target)
        var items: [Item] = []
        
        // vacated: occupied on the board, empty in the target → remove.
        for (square, piece) in diff.vacated {
            items.append(Item(square: square, action: .remove(piece)))
        }
        // placed: plain placement when the physical square is empty, otherwise a swap.
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

// MARK: Live Derivation

extension RecoveryGuidance {
    
    /// The live checklist, or nil. Two consumers compute this independently by decision -
    /// `BoardDestination` for the board's overlays, `SessionWindow` for the written checklist. Two
    /// *computations* was the decision; two *spellings* was not, hence one static.
    ///
    /// Non-nil is not the same as non-empty: a board restored while `needsRecovery` is still set
    /// yields an empty checklist. The two consumers handle that window differently and both are
    /// right - `SessionWindow` tests `isEmpty`, because an empty written list is a heading over
    /// nothing; `BoardDestination` does not need to, because empty square sets draw nothing anyway.
    /// It does still gate move hints on the *optional*, so hints stay down for the whole window
    /// rather than flickering back for the frame before recovery clears.
    @MainActor
    static func current(
        session: DGTLiveSession,
        connection: DGTConnection
    ) -> RecoveryGuidance? {
        guard session.needsRecovery, let game = session.liveGame else { return nil }
        return RecoveryGuidance(
            physical: connection.physicalBoard,
            target: game.currentState.position
        )
    }
}
