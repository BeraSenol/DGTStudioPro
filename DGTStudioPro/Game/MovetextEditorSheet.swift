//
//  MovetextEditorSheet.swift
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
/// `PGNStore.applyMovetextEdit` write and the rebuild of the on-board `Game` —
/// the sheet never touches SwiftData, the `EditGameInfoSheet` discipline.
///
/// The result is *shown* (from the game) and validated against, never edited
/// here: a result change is a metadata edit (`applyEdit`), a separate door, so
/// this door validates against the result exactly as the store does.
internal struct MovetextEditorSheet: View {
    
    // MARK: Stored Properties
    
    /// The archived game — read for its name, its result (the claim the
    /// movetext is validated against), and to seed the field.
    internal let pgn: PGN
    
    /// Called with the tokenized SAN on Save; the caller runs the store write
    /// and rebuilds the loaded `Game`.
    internal let onCommit: ([String]) -> Void
    
    // MARK: Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: View State
    
    @State private var text: String
    
    // MARK: Initializer
    
    internal init(pgn: PGN, onCommit: @escaping ([String]) -> Void) {
        self.pgn = pgn
        self.onCommit = onCommit
        // One move per line reads better for scanning and fixing a typo than a
        // single wrapped paragraph; the tokenizer is whitespace-agnostic.
        _text = State(initialValue: pgn.moves.joined(separator: "\n"))
    }
    
    // MARK: Derived
    
    private var tokens: [String] { MovetextEdit.tokenize(text) }
    
    private var validation: Result<MovetextEdit.Accepted, MovetextEdit.Rejection> {
        MovetextEdit.validate(tokens, claimedResult: pgn.result)
    }
    
    private var isValid: Bool {
        if case .success = validation { return true }
        return false
    }
    
    // MARK: Body
    
    internal var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Edit Moves")
                    .font(.title2.bold())
                Text("\(pgn.whiteDisplayName) vs \(pgn.blackDisplayName) — \(pgn.result.rawValue)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.horizontal, .top])
            
            TextEditor(text: $text)
                .font(.body.monospaced())
                .frame(minHeight: 200)
                .padding(.horizontal)
                .padding(.top, 8)
                .accessibilityIdentifier(AccessibilityID.movetextEditorField)
            
            statusLine
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier(AccessibilityID.movetextEditorCancel)
                
                Spacer()
                
                Button("Save") {
                    onCommit(tokens)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
                .accessibilityIdentifier(AccessibilityID.movetextEditorSave)
            }
            .padding()
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 420)
        .accessibilityIdentifier(AccessibilityID.movetextEditorSheet)
    }
    
    // MARK: Status
    
    @ViewBuilder
    private var statusLine: some View {
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

// MARK: - Previews

#Preview("Legal") {
    MovetextEditorSheet(
        pgn: PGN(white: "Alice", black: "Bob", moves: ["e4", "e5", "Nf3", "Nc6"], result: .whiteWins),
        onCommit: { _ in }
    )
}

#Preview("Mate") {
    MovetextEditorSheet(
        pgn: PGN(white: "Alice", black: "Bob", moves: ["f3", "e5", "g4", "Qh4#"], result: .blackWins),
        onCommit: { _ in }
    )
}
