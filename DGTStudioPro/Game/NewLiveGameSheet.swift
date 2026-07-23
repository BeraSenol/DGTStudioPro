//
//  NewLiveGameSheet.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 02/07/2026.
//

import SwiftUI
import SwiftData

// MARK: Placeholder Normalization

/// PGN uses `"?"` as the unknown-tag placeholder. The forms show *empty*
/// fields (with prompts) instead — friendlier to type into — and convert
/// at the boundary: `"?"` → `""` when seeding a form, trimmed `""` → `"?"`
/// when committing one. Keeping both directions next to each other makes
/// the round-trip obviously symmetric. `internal` (not `private`): M5's
/// `EditGameInfoSheet` stages the same round-trip for an archived PGN.
internal func formValue(_ tag: String) -> String {
    tag == "?" ? "" : tag
}

internal func tagValue(_ field: String) -> String {
    let trimmed = field.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "?" : trimmed
}

/// Applies `tagValue` normalization across a whole roster before it leaves
/// a form (game start, details save, or the archive sheet's Save Changes).
internal func normalized(_ roster: LiveGame.Roster) -> LiveGame.Roster {
    var result = roster
    result.event = tagValue(roster.event)
    result.site  = tagValue(roster.site)
    result.white = tagValue(roster.white)
    result.black = tagValue(roster.black)
    return result
}

// MARK: Roster Form

/// The seven-tag roster form, minus Result (the game tracks it — Decision
/// #4). Shared verbatim by the new-game sheet (M3.4) and the edit-details
/// sheet (M3.3), and reused again by M5's archive-confirmation sheet, so
/// the field set can never drift between the three.
internal struct LiveGameRosterForm: View {
    
    // MARK: Bound State
    
    @Binding internal var roster: LiveGame.Roster
    
    /// Accessibility-identifier prefix for the six fields. The live sheets
    /// use the default; M5's archive-confirmation sheet passes
    /// `AccessibilityID.archiveFormPrefix` so its fields test under the
    /// documented `archive.form.*` names without duplicating the form.
    /// Declared after `roster` (and defaulted) so existing call sites
    /// compile unchanged.
    internal var identifierPrefix = AccessibilityID.liveFormPrefix
    
    /// Known-player display names for the seat pickers (M-lib.1, D16′).
    /// Empty — the default — renders plain text fields, so the edit and
    /// archive sheets compile and behave unchanged; the New Game sheet
    /// passes the `Player` registry. Free text always works: the menu
    /// only fills the field, and picking creates nothing —
    /// `resolvePlayer` stays the single creation door, at archive time.
    internal var knownPlayers: [String] = []
    
    /// `Roster.date` is optional (a PGN date can be unknown), but the v1
    /// dialog always supplies one (default today — the locked decision), so
    /// the picker binds through a non-optional facade.
    private var dateBinding: Binding<Date> {
        Binding(
            get: { roster.date ?? .now },
            set: { roster.date = $0 }
        )
    }
    
    /// The seat picker: a borderless menu of known players trailing the
    /// text field — the combo-box shape, in SwiftUI terms (no AppKit
    /// needed: a `Menu` filling a `TextField`'s binding is the whole
    /// behavior). Hidden when the host supplies no players.
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
    
    internal var body: some View {
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

/// The full-roster new-game dialog (M3.4). Presented when the session
/// detects the start position (`shouldOfferNewGame`) or via the HUD's
/// manual "New Game…" button.
///
/// The recurring tags pre-fill from persisted defaults and write back on
/// Start (Event, Site, White — the `StorageKeys` trio from the roadmap).
/// Starting while an *unfinished* game exists replaces it behind a
/// destructive confirmation; unreachable from M3's entry points (the offer
/// only fires while idle, the manual button only shows while
/// idle/finished) but honored so a future entry point can't skip it.
internal struct NewLiveGameSheet: View {
    
    // MARK: Stored Properties
    
    /// Called with the normalized roster when the user starts the game.
    /// The caller owns `startNewGame` and sheet dismissal.
    internal let onStart: (LiveGame.Roster) -> Void
    
    /// Called by "Not Now" — dismiss without starting (the session won't
    /// re-prompt until the board leaves and returns to the start).
    internal let onNotNow: () -> Void
    
    /// True when starting would replace an unfinished game — gates the
    /// destructive confirmation.
    internal let replacesUnfinishedGame: Bool
    
    // MARK: Persisted Defaults
    
    @AppStorage(StorageKeys.defaultEvent) private var defaultEvent = ""
    @AppStorage(StorageKeys.defaultSite) private var defaultSite = ""
    @AppStorage(StorageKeys.defaultWhitePlayer) private var defaultWhite = ""
    
    // MARK: Round Prefill (M-lib.1, D16′)
    
    /// The picker's source and the resolution set. Matching only — the
    /// dialog never creates a `Player` (D9′'s one door stands).
    @Query(sort: \Player.name) private var players: [Player]
    
    /// Every Library game, projected per evaluation to `GameRecord` for
    /// the pairing fold. Relies on the player-link backfill having run
    /// (any Library/Players/Rankings visit); an unhealed row projects nil
    /// seats and simply doesn't inform the prefill — degrades to no
    /// suggestion, never to a wrong one.
    @Query private var games: [PGN]
    
    /// The last value the prefill wrote, so it only ever overwrites its
    /// own suggestion — a user-typed round is never touched or cleared
    /// (sub-decision recorded with D16′).
    @State private var prefilledRound: Int?
    
    // MARK: View State
    
    @State private var roster = LiveGame.Roster(
        event: "", site: "", white: "", black: ""
    )
    @State private var isConfirmingReplace = false
    
    // MARK: Body
    
    internal var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Game")
                    .font(.title2.bold())
                Text("Details land on the archived game — edit them any time.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.horizontal, .top])
            
            LiveGameRosterForm(roster: $roster, knownPlayers: players.map(\.name))
            
            Divider()
            
            HStack {
                Button("Not Now", action: onNotNow)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier(AccessibilityID.liveNewGameNotNow)
                
                Spacer()
                
                Button("Start Game", action: startTapped)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier(AccessibilityID.liveNewGameStart)
            }
            .padding()
        }
        .frame(minWidth: 400, idealWidth: 440, minHeight: 380)
        .accessibilityIdentifier(AccessibilityID.liveNewGameSheet)
        .onAppear {
            prefillFromDefaults()
            // The persisted White default may itself resolve — a
            // returning pair should see its round the moment the sheet
            // opens with Black filled in.
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
    
    /// D16′: once both seats resolve to known players, suggest the
    /// pairing's next round. Runs on every seat edit; the guard confines
    /// it to a Round field that is empty or still carrying our own
    /// suggestion. When the pair stops resolving (or has no numbered
    /// history), the suggestion is withdrawn — a typed value survives
    /// both directions.
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
    
    /// A seat resolves iff its trimmed text matches a known player under
    /// the D9′ identity fold (case and whitespace folded, diacritics
    /// preserved). Placeholders and empties resolve to no player, as
    /// everywhere.
    private func resolvedKey(for field: String) -> String? {
        let display = field.trimmingCharacters(in: .whitespacesAndNewlines)
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
        // Write back the recurring defaults exactly as typed (trimmed), so
        // clearing a field clears the stored default too.
        defaultEvent = roster.event.trimmingCharacters(in: .whitespacesAndNewlines)
        defaultSite  = roster.site.trimmingCharacters(in: .whitespacesAndNewlines)
        defaultWhite = roster.white.trimmingCharacters(in: .whitespacesAndNewlines)
        
        onStart(normalized(roster))
    }
}

// MARK: Edit Details Sheet

/// Edits a running (or, from M5, an archived-pending) game's roster —
/// Decision #4's "editable afterwards". Edits are staged on a local copy
/// so Cancel genuinely discards them; Save hands the normalized roster
/// back to the caller (`DGTLiveSession.updateRoster` in M3).
internal struct EditLiveGameDetailsSheet: View {
    
    // MARK: Stored Properties
    
    internal let onSave: (LiveGame.Roster) -> Void
    
    // MARK: Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: View State
    
    @State private var roster: LiveGame.Roster
    
    // MARK: Initializer
    
    internal init(
        initialRoster: LiveGame.Roster,
        onSave: @escaping (LiveGame.Roster) -> Void
    ) {
        self.onSave = onSave
        // Seed with form-friendly values ("?" placeholders → empty fields).
        var seed = initialRoster
        seed.event = formValue(initialRoster.event)
        seed.site  = formValue(initialRoster.site)
        seed.white = formValue(initialRoster.white)
        seed.black = formValue(initialRoster.black)
        _roster = State(initialValue: seed)
    }
    
    // MARK: Body
    
    internal var body: some View {
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
