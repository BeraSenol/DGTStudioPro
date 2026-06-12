//
//  LiveGameRosterSheet.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/06/2026.
//

import SwiftUI

/// The roster form behind both halves of M3.4 / M3.3: starting a new live
/// game (the full seven-tag roster minus Result, which the game tracks as it
/// plays) and editing the roster of a game already underway. One form, two
/// intents — so the new-game dialog and "Edit Details" can never drift apart,
/// and M5's archive-confirmation sheet has a form to reuse.
///
/// Create intent: Event, Site, and White pre-fill from the persisted defaults
/// (`StorageKeys.defaultEvent` / `defaultSite` / `defaultWhitePlayer`) and the
/// entered values are written back when the game starts, so the recurring tags
/// survive across launches. The edit intent never touches the defaults —
/// correcting one game's site to "Friend's house" must not change every
/// future game's pre-fill.
///
/// Empty fields commit as PGN's "?" placeholder (matching
/// `LiveGame.Roster`'s own defaults); "?" round-trips back to an empty field
/// on edit so the prompt shows instead of a literal question mark. Round is
/// a free-text field parsed to `Int?` on commit — non-numeric input simply
/// means "no round", mirroring `PGN.round: Int?`.
internal struct LiveGameRosterSheet: View {
    
    // MARK: Intent
    
    internal enum Intent {
        /// The new-game dialog: Start Game / Not Now, defaults pre-fill and
        /// write back. Declining is the *presenter's* concern (it clears the
        /// session's pending offer in the sheet's `onDismiss`, which also
        /// catches Esc and click-outside).
        case create
        /// Edit the running game's roster: Save / Cancel, no defaults I/O.
        case edit
    }
    
    // MARK: Stored Properties
    
    internal let intent: Intent
    /// Pre-fill for `.edit`; ignored for `.create`, where the persisted
    /// defaults win.
    internal let initialRoster: LiveGame.Roster?
    /// Receives the composed roster on Start/Save. The sheet dismisses
    /// itself afterwards.
    internal let onCommit: (LiveGame.Roster) -> Void
    
    // MARK: Initializer
    
    internal init(
        intent: Intent,
        initialRoster: LiveGame.Roster? = nil,
        onCommit: @escaping (LiveGame.Roster) -> Void
    ) {
        self.intent = intent
        self.initialRoster = initialRoster
        self.onCommit = onCommit
    }
    
    // MARK: Persisted Defaults (create intent only)
    
    @AppStorage(StorageKeys.defaultEvent) private var defaultEvent = ""
    @AppStorage(StorageKeys.defaultSite) private var defaultSite = ""
    @AppStorage(StorageKeys.defaultWhitePlayer) private var defaultWhitePlayer = ""
    
    // MARK: Form State
    
    @Environment(\.dismiss) private var dismiss
    @State private var event = ""
    @State private var site = ""
    @State private var date: Date = .now
    @State private var roundText = ""
    @State private var white = ""
    @State private var black = ""
    
    // MARK: Body
    
    internal var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .horizontal], 16)
            
            Form {
                TextField("Event", text: $event, prompt: Text("Casual Game"))
                    .accessibilityIdentifier("live.roster.event")
                TextField("Site", text: $site, prompt: Text("Home"))
                    .accessibilityIdentifier("live.roster.site")
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .accessibilityIdentifier("live.roster.date")
                TextField("Round", text: $roundText, prompt: Text("Optional"))
                    .accessibilityIdentifier("live.roster.round")
                TextField("White", text: $white, prompt: Text("White player"))
                    .accessibilityIdentifier("live.roster.white")
                TextField("Black", text: $black, prompt: Text("Black player"))
                    .accessibilityIdentifier("live.roster.black")
            }
            .formStyle(.grouped)
            .frame(height: 300)
            
            Divider()
            
            HStack {
                Spacer()
                Button(secondaryTitle) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier(secondaryIdentifier)
                Button(primaryTitle) { commit() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(primaryIdentifier)
            }
            .padding(16)
        }
        .frame(width: 460)
        .onAppear(perform: seed)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("live.roster.sheet")
    }
    
    // MARK: Intent-Dependent Chrome
    
    private var title: String {
        intent == .create ? "New Game" : "Edit Game Details"
    }
    
    private var primaryTitle: String {
        intent == .create ? "Start Game" : "Save"
    }
    
    private var secondaryTitle: String {
        intent == .create ? "Not Now" : "Cancel"
    }
    
    private var primaryIdentifier: String {
        intent == .create ? "live.roster.start" : "live.roster.save"
    }
    
    private var secondaryIdentifier: String {
        intent == .create ? "live.roster.notnow" : "live.roster.cancel"
    }
    
    // MARK: Seeding / Committing
    
    private func seed() {
        switch intent {
        case .create:
            event = defaultEvent
            site = defaultSite
            white = defaultWhitePlayer
            black = ""
            date = .now
            roundText = ""
        case .edit:
            let roster = initialRoster ?? LiveGame.Roster()
            event = display(roster.event)
            site = display(roster.site)
            white = display(roster.white)
            black = display(roster.black)
            date = roster.date ?? .now
            roundText = roster.round.map(String.init) ?? ""
        }
    }
    
    private func commit() {
        if intent == .create {
            // Write back the recurring tags as typed (trimmed) — an empty
            // field stays empty next time, never a literal "?".
            defaultEvent = event.trimmingCharacters(in: .whitespaces)
            defaultSite = site.trimmingCharacters(in: .whitespaces)
            defaultWhitePlayer = white.trimmingCharacters(in: .whitespaces)
        }
        
        let roster = LiveGame.Roster(
            event: sanitized(event),
            site: sanitized(site),
            date: date,
            round: Int(roundText.trimmingCharacters(in: .whitespaces)),
            white: sanitized(white),
            black: sanitized(black)
        )
        onCommit(roster)
        dismiss()
    }
    
    /// "?" (the PGN placeholder) displays as an empty field so the prompt
    /// shows instead of a literal question mark.
    private func display(_ tag: String) -> String {
        tag == "?" ? "" : tag
    }
    
    /// Empty / whitespace-only fields commit as the PGN "?" placeholder.
    private func sanitized(_ field: String) -> String {
        let trimmed = field.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "?" : trimmed
    }
}

// MARK: - Previews

#Preview("New Game") {
    LiveGameRosterSheet(intent: .create) { _ in }
}

#Preview("Edit Details") {
    LiveGameRosterSheet(
        intent: .edit,
        initialRoster: .init(
            event: "Club Night",
            site: "Antwerp",
            round: 3,
            white: "Heylen, Christophe",
            black: "Brouns, Reinaud"
        )
    ) { _ in }
}
