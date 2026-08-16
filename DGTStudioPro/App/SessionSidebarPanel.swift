import SwiftUI

/// The session surface - the single home for connection and session messaging, pinned atop the
/// Board inspector since 16 Aug 2026 (it hung under every tab's sidebar list before, hence the
/// name, kept so the move stays one commit). The stage above the board stays clear; only the
/// recovery *overlays* stay on the board (they are the mirror's, not messaging).
struct SessionSidebarPanel: View {
    
    // MARK: Environment
    
    @Environment(DGTConnection.self) private var connection
    @Environment(DGTLiveSession.self) private var session
    @Environment(DGTSessionLog.self) private var sessionLog
    
    // MARK: Stored Properties
    
    /// Read for the per-tab `boardLoadError`.
    let tabState: TabState
    
    /// Navigates to Board and requests the new-game sheet - only the affordance re-homed; the
    /// presenter stays `BoardDestination`.
    let onNewGame: () -> Void
    
    /// Clears the tab's bound game ID - unbinding is the real resolution.
    let onDismissLoadError: () -> Void
    
    // MARK: View State
    
    /// A beat's "Position restored" flash after recovery auto-resolves. Transient by design.
    @State private var showsRestoredFlash = false
    
    // MARK: Body
    
    var body: some View {
        // The empty guard keeps a disconnected, error-free sidebar exactly as it was - no blank inset.
        if hasContent {
            VStack(alignment: .leading, spacing: 8) {
                if let phase = hudPhase {
                    LiveGameHUDView(
                        phase: phase,
                        onNewGame: onNewGame,
                        onRetryArchive: { session.retryArchive() }
                    )
                }
                
                // The restore checklist under the status card; Export Diagnostics rides on it. The empty-
                // guidance guard covers the window where the board is fixed but the settle hasn't exited yet.
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
                
                if let message = tabState.boardLoadError {
                    loadErrorCard(message)
                }
            }
            .padding(10)
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
    }
    
    private var hasContent: Bool {
        hudPhase != nil
        || showsRestoredFlash
        || tabState.boardLoadError != nil
    }
    
    // MARK: Load Error
    
    /// The load-error card (re-homed by identifiers renamed with it). Dismiss clears
    /// `loadedGameID` - the tab becomes an honest live tab.
    private func loadErrorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Couldn't open the game")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
            }
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Button("Dismiss", action: onDismissLoadError)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(AccessibilityID.sidebarLoadErrorDismiss)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.sidebarLoadError)
    }
    
    // MARK: Phase Derivation
    
    /// Status-card phase, priority-ordered: connection truth first (a pulled cable outranks
    /// everything; reconnecting reads as its own card). Delegates to `SessionPhase.current` -
    /// the ordering is the content, and two surfaces must agree on it.
    private var hudPhase: LiveGameHUDView.Phase? {
        .current(session: session, connection: connection)
    }
    
    /// The restore checklist while recovering; recomputed per observable change so rows disappear
    /// live. `BoardDestination` computes its own diff for the *overlays* - two 64-square diffs per
    /// render is cheap.
    private var recoveryGuidance: RecoveryGuidance? {
        .current(session: session, connection: connection)
    }
}

// MARK: Previews

/// Only the load-error arm is canvas-reachable (`DGTConnection.status` is private(set)); phase
/// cards preview on `LiveGameHUDView`, the checklist on `RecoveryGuidanceView`.
#Preview("Load Error") {
    let tabState = TabState()
    tabState.boardLoadError = "The game could not be found in the library."
    
    return SessionSidebarPanel(
        tabState: tabState,
        onNewGame: {},
        onDismissLoadError: {}
    )
    .frame(width: 260)
    .environment(DGTConnection())
    .environment(DGTLiveSession())
    .environment(DGTSessionLog())
}

/// The empty guard: disconnected and error-free renders *nothing* - the canvas should be empty.
#Preview("Empty Guard") {
    SessionSidebarPanel(tabState: TabState(), onNewGame: {}, onDismissLoadError: {})
        .frame(width: 260, height: 80)
        .environment(DGTConnection())
        .environment(DGTLiveSession())
        .environment(DGTSessionLog())
}
