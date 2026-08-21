import SwiftUI

// MARK: Edit Details Sheet

/// Edits a running (or archived-pending) game's roster. Staged on a local copy so Cancel
/// genuinely discards; Save hands the normalized roster back.
///
/// **Its own file since 21 Aug 2026.** It was declared at the bottom of `NewLiveGameSheet.swift`
/// while its sibling `EditGameInfoSheet` - the same round trip against the archive rather than the
/// live game - had a file of its own, so one of a matched pair was findable by filename and the
/// other was not. The three placeholder helpers it uses (`formValue`, `tagValue`, `normalized`) and
/// `LiveGameRosterForm` stay where they are: they are shared by three sheets, and the file that
/// declares them is the one that names the form.
struct EditLiveGameDetailsSheet: View {

    // MARK: Stored Properties

    let onSave: (LiveGame.Roster) -> Void

    // MARK: Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: View State

    @State private var roster: LiveGame.Roster

    // MARK: Initializer

    init(
        initialRoster: LiveGame.Roster,
        onSave: @escaping (LiveGame.Roster) -> Void
    ) {
        self.onSave = onSave
        // Seed with form-friendly values ("?" → empty).
        var seed = initialRoster
        seed.event = formValue(initialRoster.event)
        seed.site  = formValue(initialRoster.site)
        seed.white = formValue(initialRoster.white)
        seed.black = formValue(initialRoster.black)
        _roster = State(initialValue: seed)
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            // "Edit Details", matching the seven controls that open it (21 Aug 2026). The control
            // said one thing and the surface said another; the label a reader clicked should be the
            // heading they land on.
            Text("Edit Details")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.horizontal, .top])

            LiveGameRosterForm(roster: $roster)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier(AccessibilityID.liveEditDetailsCancel)

                Spacer()

                // Gated since 16 Aug 2026 - this Save was the one roster door with *no* guard: the
                // shared form drew the seat warning here and nothing stopped the gesture, so an
                // edit could mint by hand what the self-play guard scoped out. Site joins under the same rule.
                Button("Save") {
                    onSave(normalized(roster))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(roster.seatsNameOnePlayer || roster.siteViolatesFormat)
                .accessibilityIdentifier(AccessibilityID.liveEditDetailsSave)
            }
            .padding()
        }
        .frame(minWidth: 400, idealWidth: 440, minHeight: 360)
        .accessibilityIdentifier(AccessibilityID.liveEditDetailsSheet)
    }
}

// MARK: Previews

#Preview("Edit Details") {
    EditLiveGameDetailsSheet(
        initialRoster: .init(
            event: "Club Night",
            site: "?",
            round: 3,
            white: "Alice",
            black: "?"
        ),
        onSave: { _ in }
    )
}
