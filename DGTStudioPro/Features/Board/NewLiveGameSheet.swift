import SwiftUI
import SwiftData

// MARK: Placeholder Normalization

/// PGN's `"?"` ↔ empty-field boundary: `"?"` → `""` seeding a form, trimmed `""` → `"?"`
/// committing one. Kept adjacent so the round trip is obviously symmetric; not private,
/// because `EditGameInfoSheet` stages the same round trip.
func formValue(_ tag: String) -> String {
    tag == "?" ? "" : tag
}

func tagValue(_ field: String) -> String {
    let trimmed = field.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "?" : trimmed
}

/// Normalizes a whole roster before it leaves any form.
func normalized(_ roster: LiveGame.Roster) -> LiveGame.Roster {
    var result = roster
    result.event = tagValue(roster.event)
    result.site  = tagValue(roster.site)
    result.white = tagValue(roster.white)
    result.black = tagValue(roster.black)
    return result
}

// MARK: Roster Form

/// The roster form minus Result (the game tracks it — Decision #4). Shared by the new-game,
/// edit-details and archive-confirmation sheets, so the field set cannot drift.
struct LiveGameRosterForm: View {
    
    // MARK: Bound State
    
    @Binding var roster: LiveGame.Roster
    
    /// Identifier prefix for the six fields — the archive sheet passes `archive.form.*`.
    var identifierPrefix = AccessibilityID.liveFormPrefix
    
    /// Known-player **tag forms** for the seat pickers (D16′/D29′ — the picker inserts
    /// `Player.tagName`, never `name`). The menu only fills; picking creates nothing.
    var knownPlayers: [String] = []
    
    /// `Roster.date` is optional but the dialog always supplies one (default today), so the picker
    /// binds through a non-optional facade.
    private var dateBinding: Binding<Date> {
        Binding(
            get: { roster.date ?? .now },
            set: { roster.date = $0 }
        )
    }
    
    /// The seat picker: a borderless menu trailing the field — the combo-box shape, no AppKit
    /// needed. Hidden when the host supplies no players.
    @ViewBuilder
    private func playerMenu(for field: Binding<String>, identifier: String) -> some View {
        if !knownPlayers.isEmpty {
            Menu {
                ForEach(knownPlayers, id: \.self) { name in
                    Button(name) { field.wrappedValue = name }
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down")
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
            .help("Choose a known player")
            .accessibilityIdentifier(identifier)
        }
    }
    
    // MARK: Body
    
    var body: some View {
        Form {
            Section("Players") {
                HStack {
                    TextField(
                        "White",
                        text: $roster.white,
                        prompt: Text("White player")
                    )
                    .accessibilityIdentifier(
                        AccessibilityID.formWhite(identifierPrefix)
                    )
                    playerMenu(
                        for: $roster.white,
                        identifier: AccessibilityID.formWhitePicker(identifierPrefix)
                    )
                }
                
                HStack {
                    TextField(
                        "Black",
                        text: $roster.black,
                        prompt: Text("Black player")
                    )
                    .accessibilityIdentifier(AccessibilityID.formBlack(identifierPrefix))
                    playerMenu(
                        for: $roster.black,
                        identifier: AccessibilityID.formBlackPicker(identifierPrefix)
                    )
                }

                // D61′'s guard: the two seats are one `Roster`, so the check needs no drafts to compare.
                // A warning line plus a disabled Start — the alert belongs to Get Info's commit model.
                if roster.seatsNameOnePlayer {
                    Label(
                        "\(PlayerName.displayForm(of: roster.white)) can’t play both sides. "
                        + "Give one seat a different name, or clear it to “\(RosterSummary.unknownTag)”.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier(
                        AccessibilityID.formSeatConflict(identifierPrefix)
                    )
                }
            }
            
            Section("Event") {
                TextField(
                    "Event",
                    text: $roster.event,
                    prompt: Text("Casual Game")
                )
                .accessibilityIdentifier(AccessibilityID.formEvent(identifierPrefix))
                
                TextField(
                    "Site",
                    text: $roster.site,
                    prompt: Text("Home")
                )
                .accessibilityIdentifier(AccessibilityID.formSite(identifierPrefix))
                
                DatePicker(
                    "Date",
                    selection: dateBinding,
                    displayedComponents: .date
                )
                .accessibilityIdentifier(AccessibilityID.formDate(identifierPrefix))
                
                TextField(
                    "Round",
                    value: $roster.round,
                    format: .number,
                    prompt: Text("Optional")
                )
                .accessibilityIdentifier(AccessibilityID.formRound(identifierPrefix))
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: New Game Sheet

/// The new-game dialog: presented on start-position detection (`shouldOfferNewGame`) or the
/// HUD's manual button.
struct NewLiveGameSheet: View {
    
    // MARK: Stored Properties
    
    /// Called with the normalized roster on start; the caller owns `startNewGame` and dismissal.
    let onStart: (LiveGame.Roster) -> Void
    
    /// "Not Now" — dismiss without starting (no re-prompt until the board leaves and returns).
    let onNotNow: () -> Void
    
    /// True when starting would replace an unfinished game — gates the destructive confirmation.
    let replacesUnfinishedGame: Bool
    
    // MARK: Persisted Defaults
    
    @AppStorage(StorageKeys.defaultEvent) private var defaultEvent = ""
    @AppStorage(StorageKeys.defaultSite) private var defaultSite = ""
    @AppStorage(StorageKeys.defaultWhitePlayer) private var defaultWhite = ""
    
    // MARK: Round Prefill (D16′)
    /// The picker's source and resolution set. Matching only — the dialog never creates a `Player` (D9′).
    @Query(sort: \Player.name) private var players: [Player]
    
    /// Library games projected for the pairing fold. An unhealed row projects nil seats and simply
    /// doesn't inform — degrades to no suggestion, never a wrong one.
    @Query private var games: [PGN]
    
    /// The last value the prefill wrote, so it only overwrites its own suggestion — a typed round is
    /// never touched.
    @State private var prefilledRound: Int?
    
    // MARK: View State
    
    @State private var roster = LiveGame.Roster(
        event: "", site: "", white: "", black: ""
    )
    @State private var isConfirmingReplace = false
    
    // MARK: Body
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Game")
                    .font(.title2.bold())
                Text("Details land on the archived game, edit them any time.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.horizontal, .top])
            
            // D29′: tag form into the field, `name` fallback — display form is still a valid tag, just not
            // the remembered one.
            LiveGameRosterForm(
                roster: $roster,
                knownPlayers: players.map { $0.tagName ?? $0.name }
            )
            
            Divider()
            
            HStack {
                Button("Not Now", action: onNotNow)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier(AccessibilityID.liveNewGameNotNow)
                
                Spacer()
                
                // D61′: cannot start with one player on both sides. The form says why; this stops the gesture.
                // Both read `roster.seatsNameOnePlayer` — one predicate, called twice (D40′'s remedy).
                Button("Start Game", action: startTapped)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(roster.seatsNameOnePlayer)
                    .accessibilityIdentifier(AccessibilityID.liveNewGameStart)
            }
            .padding()
        }
        .frame(minWidth: 400, idealWidth: 440, minHeight: 380)
        .accessibilityIdentifier(AccessibilityID.liveNewGameSheet)
        .onAppear {
            prefillFromDefaults()
            // The persisted White default may itself resolve — a returning pair sees its round on open.
            updateRoundPrefill()
        }
        .onChange(of: roster.white) { _, _ in updateRoundPrefill() }
        .onChange(of: roster.black) { _, _ in updateRoundPrefill() }
        .confirmationDialog(
            "Replace the current game?",
            isPresented: $isConfirmingReplace
        ) {
            Button("Replace Game", role: .destructive, action: start)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The unfinished game will be discarded and can't be recovered.")
        }
    }
    
    // MARK: Actions
    
    private func prefillFromDefaults() {
        roster.event = defaultEvent
        roster.site  = defaultSite
        roster.white = defaultWhite
    }
    
    /// D16′: both seats resolved → suggest the pairing's next round. The guard confines it to an
    /// empty Round or our own suggestion; a typed value survives both directions.
    private func updateRoundPrefill() {
        guard roster.round == nil || roster.round == prefilledRound else { return }
        
        guard
            let whiteKey = resolvedKey(for: roster.white),
            let blackKey = resolvedKey(for: roster.black),
            let next = PairingRound.nextRound(
                between: whiteKey, and: blackKey,
                in: games.map(\.gameRecord)
            )
        else {
            if roster.round == prefilledRound { roster.round = nil }
            prefilledRound = nil
            return
        }
        
        roster.round = next
        prefilledRound = next
    }
    
    /// A seat resolves iff its text matches a known player under the D9′ fold, routed through
    /// `displayForm` first exactly like `resolvePlayer` — the field carries tag form (D29′).
    private func resolvedKey(for field: String) -> String? {
        let display = PlayerName.displayForm(of: field)
        guard !display.isEmpty, display != "?" else { return nil }
        let key = Player.normalizedKey(for: display)
        return players.contains { $0.normalizedName == key } ? key : nil
    }
    
    private func startTapped() {
        if replacesUnfinishedGame {
            isConfirmingReplace = true
        } else {
            start()
        }
    }
    
    private func start() {
        // Written back exactly as typed (trimmed), so clearing a field clears the stored default.
        defaultEvent = roster.event.trimmingCharacters(in: .whitespacesAndNewlines)
        defaultSite  = roster.site.trimmingCharacters(in: .whitespacesAndNewlines)
        defaultWhite = roster.white.trimmingCharacters(in: .whitespacesAndNewlines)
        
        onStart(normalized(roster))
    }
}

// MARK: Edit Details Sheet

/// Edits a running (or archived-pending) game's roster. Staged on a local copy so Cancel
/// genuinely discards; Save hands the normalized roster back.
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
            Text("Edit Game Details")
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
                
                Button("Save") {
                    onSave(normalized(roster))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(AccessibilityID.liveEditDetailsSave)
            }
            .padding()
        }
        .frame(minWidth: 400, idealWidth: 440, minHeight: 360)
        .accessibilityIdentifier(AccessibilityID.liveEditDetailsSheet)
    }
}

// MARK: Previews

#Preview("New Game") {
    NewLiveGameSheet(
        onStart: { _ in },
        onNotNow: {},
        replacesUnfinishedGame: false
    )
    .modelContainer(for: [PGN.self, Player.self], inMemory: true)
}

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

/// D61′'s seat guard, which nothing else renders. The two seats are spelled differently on
/// purpose — tag form against display form, one player under D23′ — proving the fold, not `==`.
#Preview("Roster Form, Seats Collide") {
    @Previewable @State var roster = LiveGame.Roster(
        event: "Club Night",
        white: "Lopez, Ruy",
        black: "Ruy Lopez"
    )

    LiveGameRosterForm(roster: $roster)
        .frame(width: 420, height: 380)
}
