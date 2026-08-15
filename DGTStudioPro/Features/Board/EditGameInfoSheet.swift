import SwiftUI

/// The archive-confirmation sheet (M5): confirms the save, offers one last pass over the
/// details. Shares `LiveGameRosterForm` (so the three sheets cannot drift) under the
/// `archive.form.*` prefix. Result shown, not edited (Decision #4). The caller owns the PGN
/// write and the `refreshHash` — one hash, two doors.
struct EditGameInfoSheet: View {
    
    // MARK: Stored Properties
    
    /// Read for seeding the form and the header line.
    let pgn: PGN
    
    /// True when the archive deduplicated — the header says so instead of claiming a fresh save.
    let deduplicated: Bool
    
    /// Called with the normalized roster; the caller applies, rehashes, and syncs the live roster.
    let onSave: (LiveGame.Roster) -> Void

    /// Known-player tag forms, forwarded verbatim. **A parameter, not a `@Query`** — this sheet is
    /// deliberately container-free so its previews build; the presenter has the context.
    let knownPlayers: [String]
    
    // MARK: Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: View State
    
    @State private var roster: LiveGame.Roster
    
    // MARK: Initializer
    
    /// Hand-written because `_roster` seeds from `pgn` — which is also why `knownPlayers` is a
    /// parameter: a type with its own init gets no memberwise one, and a defaulted property is
    /// invisible to callers.
    init(
        pgn: PGN,
        deduplicated: Bool,
        onSave: @escaping (LiveGame.Roster) -> Void,
        knownPlayers: [String] = []
    ) {
        self.pgn = pgn
        self.deduplicated = deduplicated
        self.onSave = onSave
        self.knownPlayers = knownPlayers
        // Seed with form-friendly values ("?" → empty), the live sheets' boundary conversion.
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
    
    var body: some View {
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
                identifierPrefix: AccessibilityID.archiveFormPrefix,
                knownPlayers: knownPlayers
            )
            
            Divider()
            
            HStack {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier(AccessibilityID.archiveDone)
                
                Spacer()
                
                // D61′: safe to gate here — the sheet appears *after* archive, so a disabled Save blocks only
                // the *edit*, never the save. Import stays exempt (D61′'s scope: one door minting them).
                Button("Save Changes") {
                    onSave(normalized(roster))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(roster.seatsNameOnePlayer)
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
        + ", \(pgn.result.rawValue)."
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
