import SwiftUI
import SwiftData

// MARK: New Game Window

/// The New Game dialog as its own window (16 Aug 2026; it was `BoardDestination`'s sheet - the
/// everything-is-a-window pass). A singleton by id: one session, one offer. `BoardDestination`
/// translates the session's auto-offer and the panel's manual request into `openWindow`;
/// closing the window is "Not Now" - `onDisappear` dismisses the offer, so the next
/// start-position settle can raise it again.
struct NewLiveGameWindow: View {
    
    static let sceneID = "newLiveGame"
    
    @Environment(DGTLiveSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NewLiveGameSheet(
            onStart: { roster in
                // (A dismiss-then-defer arrangement stood here for a few hours on 17 Aug 2026,
                // hypothesizing the dialog's teardown frame co-caused the full-screen toolbar
                // fault. Superseded the same day by the real trigger - the inspector column's
                // List↔bare flip, see `InspectorEmptyState.scrollBacked()` - so the plain
                // synchronous shape returned rather than surviving on a dead why.)
                session.startNewGame(roster: roster)
                dismiss()
            },
            onNotNow: { dismiss() },
            // A resumable draft counts as unfinished: starting fresh overwrites its file, so same
            // destructive confirmation (a *corrupt* file is not a game).
            replacesUnfinishedGame: session.liveGame?.isFinished == false
            || session.resumableDraft != nil
        )
        // A game beginning under the dialog - this window's own Start, or play simply beginning
        // on the board - makes it stale; close rather than offer a second game over a first.
        .onChange(of: session.liveGame != nil) { _, hasGame in
            if hasGame { dismiss() }
        }
        .onDisappear {
            if session.shouldOfferNewGame { session.dismissNewGameOffer() }
        }
    }
}

// MARK: New Game Sheet

/// The dialog body: start-position detection (`shouldOfferNewGame`) or the session panel's
/// manual button reach it through `NewLiveGameWindow` since 16 Aug 2026.
struct NewLiveGameSheet: View {
    
    // MARK: Stored Properties
    
    /// Called with the normalized roster on start; the caller owns `startNewGame` and dismissal.
    let onStart: (LiveGame.Roster) -> Void
    
    /// "Not Now" - dismiss without starting (no re-prompt until the board leaves and returns).
    let onNotNow: () -> Void
    
    /// True when starting would replace an unfinished game - gates the destructive confirmation.
    let replacesUnfinishedGame: Bool
    
    // MARK: Persisted Defaults
    
    /// Built-in fallbacks (Bera, 16 Aug 2026): the board's own name and the room it lives in,
    /// already in Site's required shape. Absent keys only - a stored value, including a
    /// deliberately cleared one, still wins, and Start writes back whatever was typed.
    @AppStorage(StorageKeys.defaultEvent) private var defaultEvent = "DGT USB eBoard"
    @AppStorage(StorageKeys.defaultSite) private var defaultSite = "Hasselt, Limburg BEL"
    @AppStorage(StorageKeys.defaultWhitePlayer) private var defaultWhite = ""
    
    // MARK: Round Prefill
    /// The picker's source and resolution set. Matching only - the dialog never creates a `Player`.
    @Query(sort: \Player.name) private var players: [Player]
    
    /// Library games projected for the pairing fold. An unhealed row projects nil seats and simply
    /// doesn't inform - degrades to no suggestion, never a wrong one. Unfiltered, and re-folded on
    /// every seat keystroke: one of the deferred known costs, measured at M17, not scale-critical
    /// at personal size.
    @Query private var games: [PGN]
    
    /// The last value the prefill wrote, so it only overwrites its own suggestion - a typed round is
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
            
            // Tag form into the field, `name` fallback - display form is still a valid tag, just not
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
                
                // Cannot start with one player on both sides or a malformed site. The form says
                // why; this stops the gesture. Each guard is one predicate, called twice (the remedy).
                Button("Start Game", action: startTapped)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(roster.seatsNameOnePlayer || roster.siteViolatesFormat)
                    .accessibilityIdentifier(AccessibilityID.liveNewGameStart)
            }
            .padding()
        }
        // Sized for the window scene (16 Aug 2026): under `.contentSize` a window opens at its
        // content's *ideal* size, and a `Form` reports an enormous one - without an explicit
        // idealHeight this opened as a screen-swallowing floating window. A sheet never showed
        // the gap because sheets size themselves.
        .frame(minWidth: 400, idealWidth: 440, maxWidth: 560,
               minHeight: 380, idealHeight: 470, maxHeight: 700)
        .accessibilityIdentifier(AccessibilityID.liveNewGameSheet)
        .onAppear {
            prefillFromDefaults()
            // The persisted White default may itself resolve - a returning pair sees its round on open.
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
    
    /// Both seats resolved → suggest the pairing's next round. The guard confines it to an
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
    
    /// A seat resolves iff its text matches a known player under the fold, routed through
    /// `displayForm` first exactly like `resolvePlayer` - the field carries tag form.
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

// MARK: Previews

/// The scratch suite is not decoration here: `start()` **writes** the three defaults, so a Start
/// pressed on canvas would otherwise overwrite the real stored Event, Site and White. Board is the
/// only folder whose previews had never adopted the spelling Players, Library and Engine use.
/// The two roster-form guard previews moved to `LiveGameRosterForm.swift` with their type (M16).
#Preview("New Game") {
    NewLiveGameSheet(
        onStart: { _ in },
        onNotNow: {},
        replacesUnfinishedGame: false
    )
    .modelContainer(for: [PGN.self, Player.self], inMemory: true)
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}
