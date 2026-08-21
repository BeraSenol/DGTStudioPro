import SwiftUI

/// The session surface - the single home for connection and session messaging.
///
/// **Its own window since 18 Aug 2026 (D84′), and the fourth home is the last one.** It hung
/// under every tab's sidebar list until 16 Aug (hence the old `SessionSidebarPanel` name), sat
/// atop the Board inspector for a day, floated over the board as an `.overlay` for another, and
/// is a scene now. The overlay was right about the cause and wrong about the remedy: it dodged
/// window layout by not participating in it, but it still drew inside the main window, and the
/// app had already decided in the 16 Aug everything-is-a-window pass that a surface consulted
/// over the board is a window. This finishes that pass rather than opening a new argument.
///
/// D15′'s stage-clear rule is not narrowed after all - it is **kept, and honoured harder**. The
/// stage above the board carries nothing, because session messaging is no longer in that window.
///
/// **What did not come along: the load-error card.** It read `TabState.boardLoadError`, which is
/// per-tab, and an app-global window cannot honestly show one tab's failure to open a game. It is
/// an `.alert` on `BoardDestination` now. That is a correction, not a loss: a load error is not
/// session info, and D15′ made this surface the master of session info specifically.
struct SessionWindow: View {

    /// A singleton `Window` opened by id - the View Options and Board Connection shape: one
    /// session, one surface, no wrapper type to mint.
    static let sceneID = "session"

    // MARK: Environment

    @Environment(DGTConnection.self) private var connection
    @Environment(DGTLiveSession.self) private var session
    @Environment(DGTSessionLog.self) private var sessionLog
    @Environment(\.openWindow) private var openWindow

    // MARK: View State

    /// A beat's "Position restored" flash after recovery auto-resolves. Transient by design.
    @State private var showsRestoredFlash = false

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hasContent {
                if let phase = hudPhase {
                    LiveGameHUDView(
                        phase: phase,
                        // Straight to the door. The old `tabState.manualNewGameRequested` hop
                        // existed only because this surface lived inside the tab's hierarchy and
                        // could not reach `openWindow`; a scene can, so the flag and its
                        // `onChange` consumer went with the move.
                        onNewGame: { openWindow(id: NewLiveGameWindow.sceneID) },
                        onRetryArchive: { session.retryArchive() }
                    )
                }

                // The restore checklist under the status card; Export Diagnostics rides on it. The
                // empty-guidance guard covers the window where the board is fixed but the settle
                // hasn't exited yet.
                if let guidance = recoveryGuidance, !guidance.isEmpty {
                    RecoveryGuidanceView(
                        guidance: guidance,
                        onExportDiagnostics: { sessionLog.exportViaSavePanel() }
                    )
                }

                if showsRestoredFlash {
                    Label(
                        "Position restored, play continues.",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(.regularMaterial, in: Capsule())
                    .transition(.opacity)
                    .accessibilityIdentifier(AccessibilityID.liveRecoveryRestoredFlash)
                    .task {
                        // Auto-dismiss; cancellation on disappear is the cleanup.
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation { showsRestoredFlash = false }
                    }
                }
            } else {
                // **A window must render something.** The panel's old empty guard produced no
                // view at all, which is right for an inset in a stack and impossible for a scene -
                // an empty window reads as a defect. The quiet state is stated instead.
                ContentUnavailableView(
                    "Nothing to Report",
                    systemImage: "checkmark.circle",
                    description: Text("Connection and session messages appear here.")
                )
                .accessibilityIdentifier(AccessibilityID.sessionWindowEmpty)
            }
        }
        .padding(10)
        .frame(minWidth: 280, idealWidth: 320, minHeight: 140, idealHeight: 200, alignment: .top)
        .animation(.default, value: session.needsRecovery)
        .onChange(of: session.needsRecovery) { wasRecovering, isRecovering in
            // Flash only on a genuine auto-exit - discard / new-game change the whole surface.
            if wasRecovering, !isRecovering,
               let game = session.liveGame, !game.isFinished {
                withAnimation { showsRestoredFlash = true }
            }
        }
        .accessibilityIdentifier(AccessibilityID.sessionPanel)
    }

    // MARK: Content Derivation

    /// Whether the surface has anything to say. It no longer *gates* the surface - a scene renders
    /// either way - so its only job now is choosing between the content and the quiet state.
    ///
    /// **Open item, named rather than left to be discovered.** As an inset, this surface appeared
    /// by itself the moment it had something to report; as a window it appears when asked for. A
    /// desync during a game the reader is watching now announces itself only in the toolbar
    /// subtitle unless the window is already open. Auto-opening on `needsRecovery` is the obvious
    /// remedy and is deliberately **not** written yet: a window that opens itself is a decision
    /// about interruption, not a detail of this move.
    private var hasContent: Bool {
        hudPhase != nil || showsRestoredFlash
    }

    /// Status-card phase, priority-ordered: connection truth first (a pulled cable outranks
    /// everything; reconnecting reads as its own card). Delegates to `SessionPhase.current` -
    /// the ordering is the content, and two surfaces must agree on it.
    ///
    /// **`.playing` is filtered to nil (17 Aug 2026, by request): the card stands down during
    /// the game itself.** The reasoning survives the move to a window and gets stronger: a
    /// surface repeating whose move it is - which the toolbar subtitle and the board already
    /// say - was chrome over the board, and is now a whole window earning its space by saying
    /// nothing new. Every arrival, exception and exit still shows: setup, corrections, recovery,
    /// reconnects, the result, a failed archive. Visibility policy only - the *ordering* stays
    /// `SessionPhase.current`'s, and the subtitle deliberately keeps `.playing`, whose words are
    /// its main job.
    private var hudPhase: LiveGameHUDView.Phase? {
        guard let phase = LiveGameHUDView.Phase.current(
            session: session, connection: connection
        ) else { return nil }
        if case .playing = phase { return nil }
        return phase
    }

    /// The restore checklist while recovering; recomputed per observable change so rows disappear
    /// live. `BoardDestination` computes its own diff for the *overlays* - two 64-square diffs per
    /// render is cheap.
    private var recoveryGuidance: RecoveryGuidance? {
        .current(session: session, connection: connection)
    }
}

// MARK: Show Command

/// View ▸ Show Session. **No keyboard shortcut**: the surface is consulted, not driven, and the
/// View menu's one claimed key (⌘J) is View Options'. Always enabled, unlike its neighbour - the
/// session exists whether or not a destination publishes anything, and a disabled item would
/// leave "is something wrong with the board" unanswerable exactly when it is asked.
struct SessionWindowCommands: Commands {

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            ShowSessionWindowButton()
        }
    }
}

/// The shared button for the menu and any surface that wants the door - the *wording* must not
/// fork. Carries label and action, deliberately not the shortcut: `ShowViewOptionsButton`'s rule,
/// a key equivalent is a claim to own the verb globally and only the menu may make it.
struct ShowSessionWindowButton: View {

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Show Session") {
            openWindow(id: SessionWindow.sceneID)
        }
        .accessibilityIdentifier(AccessibilityID.showSessionWindow)
    }
}

// MARK: Previews

/// The empty state, which is the only arm reachable from the canvas - `DGTConnection.status` is
/// `private(set)`, so phase cards preview on `LiveGameHUDView` and the checklist on
/// `RecoveryGuidanceView`, exactly as they did before the move.
#Preview("Nothing to Report") {
    SessionWindow()
        .environment(DGTConnection())
        .environment(DGTLiveSession())
        .environment(DGTSessionLog())
}
