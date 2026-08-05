//
//  MovetextEditorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 21/07/2026.
//

import SwiftUI

/// Edits an archived game's movetext (M-lib.3, D18′). The field seeds with the
/// game's current SAN; every keystroke re-validates purely
/// (`MovetextEdit.validate`), so the status line shows the first illegal ply
/// (or a green "N moves") and **Save** is gated on a legal, result-consistent
/// game. Save hands the tokenized SAN to the caller, which owns the
/// `PGNStore.applyMovetextEdit` write — this view never touches SwiftData, the
/// `EditGameInfoSheet` discipline.
///
/// The result is *shown* (from the game) and validated against, never edited
/// here: a result change is a metadata edit (`applyEdit`), a separate door, so
/// this door validates against the result exactly as the store does.
///
/// **Was `MovetextEditorSheet` until 5 Aug 2026.** It lost its sheet chrome —
/// the title block, the frame, the `Cancel` button and the `dismiss`
/// environment — when its one presenter went away: the Library inspector's
/// pencil was the only thing that ever opened it, and with the door moved to
/// Get Info's Move Text tab a sheet had nothing left to be presented *from*.
/// Renamed rather than kept as a sheet wrapping a tab's content, because a
/// type whose name says "sheet" and whose only host is a tab is the kind of
/// stale label this project has repeatedly found reading as evidence that
/// something was still true.
///
/// What deliberately did **not** change: the validator, the accept-whole rule,
/// the splice refusal, the per-ply error copy, and all five
/// `movetext.editor.*` identifiers. Only the container moved.
internal struct MovetextEditorView: View {

    // MARK: Stored Properties

    /// The archived game — read for its result (the claim the movetext is
    /// validated against) and to seed the field.
    internal let pgn: PGN

    /// Called with the tokenized SAN on Save; the caller runs the store write.
    internal let onCommit: ([String]) -> Void

    // MARK: View State

    @State private var text: String

    /// The seed, kept so **Revert** can restore it without re-reading `pgn`.
    ///
    /// Re-reading would look equivalent and is not: `pgn` is a live `@Model`,
    /// so after a successful commit it holds the *new* moves, and a Revert
    /// pressed afterwards would restore the edit rather than undo it. Storing
    /// the seed makes Revert mean "back to what this editor opened with",
    /// which is the only definition a reader can predict.
    @State private var seed: String

    // MARK: Initializer

    internal init(pgn: PGN, onCommit: @escaping ([String]) -> Void) {
        self.pgn = pgn
        self.onCommit = onCommit
        // One move per line reads better for scanning and fixing a typo than a
        // single wrapped paragraph; the tokenizer is whitespace-agnostic.
        let seeded = pgn.moves.joined(separator: "\n")
        _text = State(initialValue: seeded)
        _seed = State(initialValue: seeded)
    }

    // MARK: Derived

    private typealias Validation = Result<MovetextEdit.Accepted, MovetextEdit.Rejection>

    /// Tokenization and validation as one step: `tokenize` refuses spliced
    /// input (M2 item 3), so tokens and verdict now travel together — a
    /// separate `tokens` property would re-tokenize *and* need its own story
    /// for the throw. On a splice the tokens are empty, which is safe: Save
    /// is gated on `.success`, so they're never committed.
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
        // Validate once per render. As a computed property this was pulled by
        // both Save's gate and the status line, and each pull re-tokenized
        // too — every keystroke replayed the whole game twice over.
        let check = checked()

        VStack(spacing: 0) {
            // The result the movetext is validated *against*, stated at the top
            // because it is the one input to this editor that cannot be changed
            // from it. Without it, "the result must be 1-0" in the status line
            // below is an instruction with no visible subject.
            LabeledContent("Validated against") {
                Text(pgn.result.rawValue).monospacedDigit()
            }
            .padding([.horizontal, .top])
            .padding(.bottom, 8)

            TextEditor(text: $text)
                .font(.body.monospaced())
                .frame(minHeight: 200)
                .padding(.horizontal)
                .accessibilityIdentifier(AccessibilityID.movetextEditorField)

            statusLine(check.validation)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack {
                // **Revert, not Cancel.** A sheet's Cancel meant "close without
                // saving" and the closing did the work; a tab cannot close, so
                // the same button would have to mean "put the text back" — a
                // different verb wearing the old label. Disabled when there is
                // nothing to revert, and that disabled state is producible
                // (open the tab, touch nothing), which is the D40′ check.
                Button("Revert") { text = seed }
                    .disabled(text == seed)
                    .accessibilityIdentifier(AccessibilityID.movetextEditorCancel)

                Spacer()

                // No `.keyboardShortcut(.defaultAction)` any more, and its
                // absence is deliberate rather than an oversight: Return inside
                // a `TextEditor` is a newline — which is how you add a move —
                // and a default-action Save would have made the most ordinary
                // keystroke in this field commit the game instead. The sheet
                // got away with it because Return there was unambiguous; in a
                // tab beside a multi-line editor it is not.
                Button("Save") {
                    onCommit(check.tokens)
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
                "Legal — \(accepted.moves.count) \(accepted.moves.count == 1 ? "move" : "moves").",
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

    /// Turns a validator rejection into editor copy — `MovetextEdit.Rejection`
    /// stays a pure value; the wording is view-layer.
    private func message(for rejection: MovetextEdit.Rejection) -> String {
        switch rejection {
        case .illegalMove(let index, let san, let reason):
            return "Move \(index + 1) (\(san)): \(reasonText(reason))."
        case .claimsCheckmateButPositionIsNot(let san):
            return "\(san) is marked mate (#), but that position isn't checkmate."
        case .checkmateResultMismatch(let expected, _):
            return "This line ends in checkmate — the result must be \(expected.rawValue)."
        case .stalemateRequiresDraw:
            return "This line ends in stalemate — the result must be a draw (1/2-1/2)."
        case .resultRequiresDecision:
            return "An archived game needs a decided result (not *)."
        case .splicedGames(let token):
            return "\(token) appears before the end — this looks like more than one game. Edit one game's moves only."
        }
    }

    private func reasonText(_ reason: SANParseError) -> String {
        switch reason {
        case .empty:                   return "no move given"
        case .malformed(let san):      return "\(san) isn't a valid move"
        case .noMatchingMove:          return "no legal move matches"
        case .ambiguous(_, let count): return "ambiguous — \(count) moves match; add a disambiguator"
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

/// The rejection arm a reader hits by accident, and the one the status line
/// exists for. Seeded legal — the canvas shows the green state, and typing a
/// nonsense ply is how you reach the red one. Kept as a preview rather than a
/// fixture with pre-broken text because the *transition* is the behaviour:
/// Save disables the moment the line stops being legal.
#Preview("Result Mismatch") {
    MovetextEditorView(
        pgn: PGN(white: "Alice", black: "Bob", moves: ["f3", "e5", "g4", "Qh4#"], result: .whiteWins),
        onCommit: { _ in }
    )
    .frame(width: 460, height: 420)
}
