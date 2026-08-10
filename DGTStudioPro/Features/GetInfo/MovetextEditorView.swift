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

    /// `AttributedString` since D79′ — the macOS 26 `TextEditor` binding — so the offending ply
    /// can render red *in the field*. Characters are the data; colour is derived, never typed.
    @State private var text: AttributedString

    /// The seed, kept so **Revert** can restore it without re-reading `pgn` — a live `@Model` holds
    /// the *new* moves after a commit, and Revert must mean "what the tab opened with or last saved".
    @State private var seed: String

    /// The last character content the highlight pass styled — the guard that keeps the
    /// attribute-only write in `restyle()` from re-entering `onChange` forever.
    @State private var styledPlain: String

    /// One replay per text change, not one per pull (D78′'s box, at editor scale): the status
    /// line, the Save gate and the highlight all read this validation for the same characters.
    @State private var checkCache =
        CollectionFoldCache<String, (tokens: [String], validation: Validation)>()

    // MARK: Initializer

    internal init(pgn: PGN, onCommit: @escaping ([String]) -> Void) {
        self.pgn = pgn
        self.onCommit = onCommit
        let seeded = Self.scoreSheet(pgn.moves)
        // Styled at init too: an imported game whose stored moves never replayed (diagram 02's
        // import-never-replays note) shows its offending ply red on OPEN, before any edit.
        _text = State(initialValue: Self.highlighted(
            AttributedString(seeded),
            validation: Self.check(seeded, claimedResult: pgn.result).validation
        ))
        _seed = State(initialValue: seeded)
        _styledPlain = State(initialValue: seeded)
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
    private nonisolated static func check(
        _ plain: String,
        claimedResult: GameResult
    ) -> (tokens: [String], validation: Validation) {
        do {
            let tokens = try MovetextEdit.tokenize(plain)
            return (tokens, MovetextEdit.validate(tokens, claimedResult: claimedResult))
        } catch {
            return ([], .failure(error))
        }
    }

    private func checked(_ plain: String) -> (tokens: [String], validation: Validation) {
        checkCache.value(for: plain) {
            Self.check(plain, claimedResult: pgn.result)
        }
    }

    private func isValid(_ validation: Validation) -> Bool {
        if case .success = validation { return true }
        return false
    }

    // MARK: Highlight (D79′)

    /// Colours cleared, then the offending ply — and only it — painted red. Attribute-only: the
    /// characters are never touched, so the caret stays put. Colour is the *pointer*; the words
    /// stay in the status line, so the signal is never colour-alone.
    private nonisolated static func highlighted(
        _ text: AttributedString,
        validation: Validation
    ) -> AttributedString {
        var styled = text
        styled.foregroundColor = nil
        guard case .failure(.illegalMove(let index, _, _)) = validation else { return styled }
        let plain = String(styled.characters)
        guard let range = MovetextEdit.characterRange(ofPly: index, in: plain) else { return styled }
        let lower = styled.characters.index(styled.startIndex, offsetBy: range.lowerBound)
        let upper = styled.characters.index(lower, offsetBy: range.count)
        styled[lower..<upper].foregroundColor = .red
        return styled
    }

    /// Re-derives the highlight after a character change. Typing at the edge of a red run briefly
    /// inherits its colour — repainted here on the same change, so it never survives a frame the
    /// reader can act on. The `styledPlain` guard swallows the attribute-only echo.
    private func restyle() {
        let plain = String(text.characters)
        guard plain != styledPlain else { return }
        styledPlain = plain
        text = Self.highlighted(text, validation: checked(plain).validation)
    }
    
    // MARK: Body
    
    internal var body: some View {
        // One validation per character change (the cache), pulled once per render.
        let plain = String(text.characters)
        let check = checked(plain)

        VStack(spacing: 0) {
            statusLine(check.validation)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.horizontal, .top])

            TextEditor(text: $text)
                .font(.body.monospaced())
                .frame(minHeight: 200)
                .padding()
                .accessibilityIdentifier(AccessibilityID.movetextEditorField)
                // Attribute-only writes re-enter here once; `restyle()`'s guard swallows the echo.
                .onChange(of: text) { _, _ in restyle() }

            Divider()

            HStack {
                // **Revert, not Cancel** — a tab cannot close, so the button means "put the text back".
                // Disabled state is producible (open the tab, touch nothing) — the D40′ check.
                Button("Revert") { text = AttributedString(seed) }
                    .disabled(plain == seed)
                    .accessibilityIdentifier(AccessibilityID.movetextEditorCancel)

                Spacer()

                // No `.keyboardShortcut(.defaultAction)`, deliberately: Return in a `TextEditor` is how you add
                // a move, and a default-action Save would commit on the field's most ordinary keystroke.
                Button("Save") {
                    onCommit(check.tokens)
                    // Re-render from the **accepted** moves — the canonical SAN the store persists — the one moment
                    // the editor can show exactly what landed (also re-aligns the score sheet).
                    if case .success(let accepted) = check.validation {
                        let sheet = Self.scoreSheet(accepted.moves)
                        text = AttributedString(sheet)
                        seed = sheet
                    } else {
                        seed = plain
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid(check.validation) || plain == seed)
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

/// D79′'s witness, and the game-98 shape: stored moves that never replayed show their offending
/// ply red **on open**. The defect this guards is visual — the wrong token painted, or the paint
/// surviving a fix — which only a canvas can see.
#Preview("Illegal Ply") {
    MovetextEditorView(
        pgn: PGN(white: "Alice", black: "Bob", moves: ["e4", "e5", "Qf4+"], result: .whiteWins),
        onCommit: { _ in }
    )
    .frame(width: 460, height: 420)
}
