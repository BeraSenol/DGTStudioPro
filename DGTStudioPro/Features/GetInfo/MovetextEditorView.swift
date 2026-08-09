import SwiftUI

/// Edits an archived game's movetext (D18′). Every keystroke re-validates purely
/// (`MovetextEdit.validate`); Save is gated on a legal, result-consistent line and hands the
/// tokens to the caller — this view never touches SwiftData.
internal struct MovetextEditorView: View {
    
    // MARK: Stored Properties
    
    /// Read for its result (the claim validated against) and to seed the field.
    internal let pgn: PGN
    
    /// Called with the tokenized SAN on Save; the caller runs the store write.
    internal let onCommit: ([String]) -> Void
    
    // MARK: View State
    
    @State private var text: String
    
    /// The seed, kept so **Revert** can restore it without re-reading `pgn` — a live `@Model` holds
    /// the *new* moves after a commit, and Revert must mean "what the tab opened with or last saved".
    @State private var seed: String
    
    // MARK: Initializer
    
    internal init(pgn: PGN, onCommit: @escaping ([String]) -> Void) {
        self.pgn = pgn
        self.onCommit = onCommit
        let seeded = Self.scoreSheet(pgn.moves)
        _text = State(initialValue: seeded)
        _seed = State(initialValue: seeded)
    }
    
    // MARK: Score sheet
    
    /// Plies as a numbered two-column score sheet (by request). **Safe because the numbers are not
    /// data**: `MovetextEdit.tokenize` strips a leading `<digits><dots>` run, so numbers and padding
    /// are decoration the validator never sees. Sharp edge, accepted: delete a ply mid-game and
    /// every number below is wrong and nothing complains — Save re-renders from accepted moves.
    /// (Tabs were tried and reverted: `TextEditor` gives no way to set tab stops.)
    internal nonisolated static func scoreSheet(_ moves: [String]) -> String {
        guard !moves.isEmpty else { return "" }
        
        let lastNumber = (moves.count + 1) / 2
        let numberWidth = String(lastNumber).count
        // The widest ply governs the column, so "Qa1xd4#" doesn't push its row out of line.
        let sanWidth = moves.reduce(2) { max($0, $1.count) }
        
        return stride(from: 0, to: moves.count, by: 2).map { index -> String in
            let number = index / 2 + 1
            let label = String(number) + "."
            let gutter = String(repeating: " ", count: numberWidth - String(number).count)
            let white = moves[index]
            
            guard index + 1 < moves.count else {
                // A game ending on White's move gets a white-only final line — D24′'s shape, arrived at
                // independently: it is simply what a score sheet does.
                return gutter + label + "  " + white
            }
            // Stdlib padding: `String.padding(toLength:)` is Foundation (MemberImportVisibility would
            // refuse it) and counts UTF-16 units where this counts Characters.
            let padded = white + String(repeating: " ", count: max(0, sanWidth - white.count))
            return gutter + label + "  " + padded + "  " + moves[index + 1]
        }
        .joined(separator: "\n")
    }
    
    // MARK: Derived
    
    private typealias Validation = Result<MovetextEdit.Accepted, MovetextEdit.Rejection>
    
    /// Tokenization and validation as one step: `tokenize` refuses spliced input, so tokens and
    /// verdict travel together. On a splice the tokens are empty — safe, Save gates on `.success`.
    private func checked() -> (tokens: [String], validation: Validation) {
        do {
            let tokens = try MovetextEdit.tokenize(text)
            return (tokens, MovetextEdit.validate(tokens, claimedResult: pgn.result))
        } catch {
            return ([], .failure(error))
        }
    }
    
    private func isValid(_ validation: Validation) -> Bool {
        if case .success = validation { return true }
        return false
    }
    
    // MARK: Body
    
    internal var body: some View {
        // Validate once per render — as a computed property this was pulled twice per keystroke,
        // replaying the whole game twice.
        let check = checked()
        
        VStack(spacing: 0) {
            statusLine(check.validation)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.horizontal, .top])
            
            TextEditor(text: $text)
                .font(.body.monospaced())
                .frame(minHeight: 200)
                .padding()
                .accessibilityIdentifier(AccessibilityID.movetextEditorField)
            
            Divider()
            
            HStack {
                // **Revert, not Cancel** — a tab cannot close, so the button means "put the text back".
                // Disabled state is producible (open the tab, touch nothing) — the D40′ check.
                Button("Revert") { text = seed }
                    .disabled(text == seed)
                    .accessibilityIdentifier(AccessibilityID.movetextEditorCancel)
                
                Spacer()
                
                // No `.keyboardShortcut(.defaultAction)`, deliberately: Return in a `TextEditor` is how you add
                // a move, and a default-action Save would commit on the field's most ordinary keystroke.
                Button("Save") {
                    onCommit(check.tokens)
                    // Re-render from the **accepted** moves — the canonical SAN the store persists — the one moment
                    // the editor can show exactly what landed (also re-aligns the score sheet).
                    if case .success(let accepted) = check.validation {
                        text = Self.scoreSheet(accepted.moves)
                    }
                    seed = text
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid(check.validation) || text == seed)
                .accessibilityIdentifier(AccessibilityID.movetextEditorSave)
            }
            .padding()
        }
        .accessibilityIdentifier(AccessibilityID.movetextEditorSheet)
    }
    
    // MARK: Status
    
    @ViewBuilder
    private func statusLine(_ validation: Validation) -> some View {
        switch validation {
        case .success(let accepted):
            Label(
                "Legal, \(accepted.moves.count) \(accepted.moves.count == 1 ? "move" : "moves").",
                systemImage: "checkmark.circle"
            )
            .foregroundStyle(.green)
            .accessibilityIdentifier(AccessibilityID.movetextEditorStatus)
        case .failure(let rejection):
            Label(message(for: rejection), systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .accessibilityIdentifier(AccessibilityID.movetextEditorStatus)
        }
    }
    
    /// Validator rejection → editor copy; `MovetextEdit.Rejection` stays a pure value.
    private func message(for rejection: MovetextEdit.Rejection) -> String {
        switch rejection {
        case .illegalMove(let index, let san, let reason):
            return "Move \(index + 1) (\(san)): \(reasonText(reason))."
        case .claimsCheckmateButPositionIsNot(let san):
            return "\(san) is marked mate (#), but that position isn't checkmate."
        case .checkmateResultMismatch(let expected, _):
            return "This line ends in checkmate, the result must be \(expected.rawValue)."
        case .stalemateRequiresDraw:
            return "This line ends in stalemate, the result must be a draw (1/2-1/2)."
        case .resultRequiresDecision:
            return "An archived game needs a decided result (not *)."
        case .splicedGames(let token):
            return "\(token) appears before the end, this looks like more than one game. Edit one game's moves only."
        }
    }
    
    private func reasonText(_ reason: SANParseError) -> String {
        switch reason {
        case .empty:                   return "no move given"
        case .malformed(let san):      return "\(san) isn't a valid move"
        case .noMatchingMove:          return "no legal move matches"
        case .ambiguous(_, let count): return "ambiguous, \(count) moves match; add a disambiguator"
        }
    }
}

// MARK: Previews

#Preview("Legal") {
    MovetextEditorView(
        pgn: PGN(white: "Alice", black: "Bob", moves: ["e4", "e5", "Nf3", "Nc6"], result: .whiteWins),
        onCommit: { _ in }
    )
    .frame(width: 460, height: 420)
}

#Preview("Mate") {
    MovetextEditorView(
        pgn: PGN(white: "Alice", black: "Bob", moves: ["f3", "e5", "g4", "Qh4#"], result: .blackWins),
        onCommit: { _ in }
    )
    .frame(width: 460, height: 420)
}

/// The rejection arm, seeded legal: the *transition* is the behaviour — Save disables the
/// moment the line stops being legal.
#Preview("Result Mismatch") {
    MovetextEditorView(
        pgn: PGN(white: "Alice", black: "Bob", moves: ["f3", "e5", "g4", "Qh4#"], result: .whiteWins),
        onCommit: { _ in }
    )
    .frame(width: 460, height: 420)
}
