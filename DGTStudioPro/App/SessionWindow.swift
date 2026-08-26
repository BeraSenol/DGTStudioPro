import SwiftUI

/// The session surface - the single home for connection and session messaging (D15′), and its own
/// scene since D84′, because a surface consulted over the board is a window.
///
/// **The load-error card deliberately did not come along.** It read `TabState.boardLoadError`,
/// which is per-tab, and an app-global window cannot honestly show one tab's failure to open a
/// game; it is an `.alert` on `BoardDestination` instead. A load error is not session info.
struct SessionWindow: View {
    
    /// A singleton `Window` opened by id - View Options' and Board Connection's shape: one session,
    /// one surface, no wrapper type to mint.
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
                        onNewGame: { openWindow(id: NewLiveGameWindow.sceneID) },
                        onRetryArchive: { session.retryArchive() }
                    )
                }
                
                // The empty-guidance guard covers the window where the board is fixed but the
                // settle has not exited yet.
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
                        // On cancellation `try?` falls through to the same dismissal, which is the
                        // wanted cleanup either way.
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation { showsRestoredFlash = false }
                    }
                }
            } else {
                // **A window must render something.** Producing no view is right for an inset in a
                // stack and impossible for a scene, where an empty window reads as a defect.
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
    
    /// Chooses between the content and the quiet state; it no longer *gates* the surface, since a
    /// scene renders either way.
    ///
    /// **Does not count `recoveryGuidance`**, which the body renders as a third branch. Unreachable
    /// today - recovery always carries a phase - but the two must move together.
    ///
    /// **Open item.** As an inset this surface appeared the moment it had something to report; as a
    /// window it appears when asked for, so a desync during a watched game announces itself only in
    /// the toolbar subtitle. Auto-opening on `needsRecovery` is deliberately not written: a window
    /// that opens itself is a decision about interruption.
    private var hasContent: Bool {
        hudPhase != nil || showsRestoredFlash
    }
    
    /// Status-card phase, priority-ordered by `SessionPhase.current` - connection truth
    /// first, a pulled cable outranking everything. The ordering is the content, and the toolbar
    /// subtitle reads the same function, so neither surface re-spells it.
    ///
    /// **`.playing` is filtered to nil: the card stands down during the game itself**, because the
    /// toolbar subtitle and the board already say whose move it is. Every arrival, exception and
    /// exit still shows - setup, corrections, recovery, reconnects, the result, a failed archive.
    /// Visibility policy only; the subtitle deliberately keeps `.playing`, whose words are its job.
    private var hudPhase: SessionPhase? {
        guard let phase = SessionPhase.current(
            isReconnecting: connection.isReconnecting,
            isConnected: connection.isConnected,
            session: session
        ) else { return nil }
        if case .playing = phase { return nil }
        return phase
    }
    
    /// The restore checklist while recovering; recomputed per observable change so rows disappear
    /// live. `BoardDestination` computes its own for the *overlays* - two 64-square diffs per
    /// render is cheap.
    private var recoveryGuidance: RecoveryGuidance? {
        .current(session: session, connection: connection)
    }
}

// MARK: Show Command

/// View ▸ Show Session. **No keyboard shortcut**: the surface is consulted, not driven, and the
/// View menu's one claimed key (⌘J) is View Options'. Always enabled, unlike its neighbour - a
/// disabled item would leave "is something wrong with the board" unanswerable exactly when it is
/// asked.
struct SessionWindowCommands: Commands {
    
    var body: some Commands {
        CommandGroup(after: .toolbar) {
            ShowSessionWindowButton()
        }
    }
}

/// The shared button for the menu and any surface wanting the door - the *wording* must not fork.
/// Carries label and action, deliberately not the shortcut: `ShowViewOptionsButton`'s rule, that a
/// key equivalent claims the verb globally and only the menu may claim it.
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

/// The empty state is the only canvas-reachable arm - `DGTConnection.status` is `private(set)`, so
/// phase cards preview on `LiveGameHUDView` and the checklist on `RecoveryGuidanceView`.
#Preview("Nothing to Report") {
    SessionWindow()
        .environment(DGTConnection())
        .environment(DGTLiveSession())
        .environment(DGTSessionLog())
}
