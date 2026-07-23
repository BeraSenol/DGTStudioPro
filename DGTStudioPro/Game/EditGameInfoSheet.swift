//
//  EditGameInfoSheet.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/07/2026.
//

import SwiftUI

/// The archive-confirmation sheet (M5): presented automatically when a
/// finished live game lands in the Library, confirming the save and offering
/// one last pass over the seven-tag details before the player moves on.
///
/// Reuses `LiveGameRosterForm` — the same field set as the new-game and
/// edit-details sheets, so the three can never drift (the form was built for
/// exactly this reuse) — under the `archive.form.*` identifier prefix.
/// Result is shown, not edited (Decision #4: the game tracks it).
///
/// Edits are staged locally; **Done** dismisses without applying them, and
/// **Save Changes** hands the normalized roster to the caller, which owns
/// the PGN write *and* the `PGNStore.refreshHash(of:)` call — the one-hash,
/// two-doors invariant lives at that call site, not here. The sheet itself
/// never touches SwiftData.
internal struct EditGameInfoSheet: View {
    
    // MARK: Stored Properties
    
    /// The archived game, read for seeding the form and the header line.
    internal let pgn: PGN
    
    /// True when the archive deduplicated against an existing Library row —
    /// the header says so instead of claiming a fresh save.
    internal let deduplicated: Bool
    
    /// Called with the normalized roster when the player saves changes.
    /// The caller applies it to the PGN, refreshes the content hash, and
    /// keeps the on-screen live roster in sync.
    internal let onSave: (LiveGame.Roster) -> Void
    
    // MARK: Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: View State
    
    @State private var roster: LiveGame.Roster
    
    // MARK: Initializer
    
    internal init(
        pgn: PGN,
        deduplicated: Bool,
        onSave: @escaping (LiveGame.Roster) -> Void
    ) {
        self.pgn = pgn
        self.deduplicated = deduplicated
        self.onSave = onSave
        // Seed with form-friendly values ("?" placeholders → empty fields),
        // the same boundary conversion the live sheets use.
        _roster = State(initialValue: LiveGame.Roster(
            event: formValue(pgn.event),
            site: formValue(pgn.site),
            date: pgn.date,
            round: pgn.round,
            white: formValue(pgn.white),
            black: formValue(pgn.black)
        ))
    }
    
    // MARK: Body
    
    internal var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headline)
                    .font(.title2.bold())
                Text(subheadline)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.horizontal, .top])
            
            LiveGameRosterForm(
                roster: $roster,
                identifierPrefix: AccessibilityID.archiveFormPrefix
            )
            
            Divider()
            
            HStack {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier(AccessibilityID.archiveDone)
                
                Spacer()
                
                Button("Save Changes") {
                    onSave(normalized(roster))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(AccessibilityID.archiveSave)
            }
            .padding()
        }
        .frame(minWidth: 400, idealWidth: 440, minHeight: 400)
        .accessibilityIdentifier(AccessibilityID.archiveSheet)
    }
    
    // MARK: Header Copy
    
    private var headline: String {
        deduplicated ? "Already in Your Library" : "Game Saved to Library"
    }
    
    private var subheadline: String {
        let line = "\(pgn.whiteDisplayName) vs \(pgn.blackDisplayName)"
        + " — \(pgn.result.rawValue)."
        return deduplicated
        ? line + " An identical game was already saved, so no duplicate was created."
        : line + " Check the details below and adjust anything before moving on."
    }
}

// MARK: Previews

#Preview("Saved") {
    EditGameInfoSheet(
        pgn: PGN(
            event: "Club Night",
            site: "Home",
            round: 3,
            white: "Alice",
            black: "Bob",
            moves: ["e4", "e5"],
            result: .whiteWins
        ),
        deduplicated: false,
        onSave: { _ in }
    )
}

#Preview("Deduplicated") {
    EditGameInfoSheet(
        pgn: PGN(
            white: "Alice",
            black: "Bob",
            moves: ["f3", "e5", "g4", "Qh4#"],
            result: .blackWins
        ),
        deduplicated: true,
        onSave: { _ in }
    )
}
