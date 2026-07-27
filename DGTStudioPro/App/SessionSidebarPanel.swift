//
//  SessionSidebarPanel.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 21/07/2026.
//

import SwiftUI

/// M-ux.3 (D15′): the sidebar's session surface — the single home for
/// connection and session messaging, pinned under the sidebar list of
/// every tab. Everything that used to render above (or over) the board
/// lives here now: the status card (`LiveGameHUDView`), the recovery
/// checklist, the restored flash, and the per-tab load-error card. The
/// stage above the board stays clear by invariant; on-board overlays
/// (last move, check, ghost rook, recovery attention/target) are
/// unaffected — they are the mirror's, not messaging.
///
/// Placement: `safeAreaInset(edge: .bottom)` on the sidebar `List` — the
/// platform's status-footer shape — so the panel never scrolls with the
/// tags and never steals a selection row. One panel per tab (`ContentView`
/// owns it beside `TabState`): session state is app-global and simply
/// renders identically in every tab's sidebar, while the load error is
/// genuinely per-tab.
///
/// Rejected (recorded with D15′): a floating HUD over the board (occludes
/// the star; the sidebar already owns session identity) and the split
/// brain of some status above the board, some in the inspector.
internal struct SessionSidebarPanel: View {
    
    // MARK: Environment
    
    @Environment(DGTConnection.self) private var connection
    @Environment(DGTLiveSession.self) private var session
    @Environment(DGTSessionLog.self) private var sessionLog
    
    // MARK: Stored Properties
    
    /// Read for the per-tab `boardLoadError`; `@Observable` tracks the read.
    internal let tabState: TabState
    
    /// Navigates to Board and requests the new-game sheet. The sheet's
    /// presenter stays `BoardDestination` — only the *affordance* re-homed
    /// (see `ContentView`'s wiring for the why).
    internal let onNewGame: () -> Void
    
    /// Clears the tab's bound game ID — the real resolution for a failed
    /// load (see `loadErrorCard`'s doc).
    internal let onDismissLoadError: () -> Void
    
    // MARK: View State
    
    /// True for a beat after recovery auto-resolves, flashing "Position
    /// restored — play continues." (M6.2). Transient by design; living on
    /// the panel it now also survives destination switches, which is
    /// strictly less surprising than the old vanish-on-round-trip.
    @State private var showsRestoredFlash = false
    
    // MARK: Body
    
    internal var body: some View {
        // The empty guard keeps a disconnected, error-free sidebar exactly
        // as it was — no blank inset at the bottom of every tab. All
        // transitions that matter happen while `hudPhase` is non-nil, so
        // the `onChange` below is always installed when it can fire.
        if hasContent {
            VStack(alignment: .leading, spacing: 8) {
                if let phase = hudPhase {
                    LiveGameHUDView(
                        phase: phase,
                        onNewGame: onNewGame,
                        onRetryArchive: { session.retryArchive() }
                    )
                }
                
                // M6.2 — the restore checklist, under the status card
                // while recovering; M6.3's Export Diagnostics… rides on
                // it (a desync is when the log is worth saving). The
                // empty-guidance guard covers the brief window where the
                // board is already fixed but the session's next settle
                // hasn't exited recovery yet.
                if let guidance = recoveryGuidance, !guidance.isEmpty {
                    RecoveryGuidanceView(
                        guidance: guidance,
                        onExportDiagnostics: { sessionLog.exportViaSavePanel() }
                    )
                }
                
                if showsRestoredFlash {
                    Label(
                        "Position restored — play continues.",
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
                        // Auto-dismiss; cancellation on disappear is the
                        // cleanup.
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
                // Flash only on a genuine auto-exit back into play —
                // discard / new-game also clear the flag, but they change
                // the whole surface, where a flash is noise.
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
    
    /// The load-error card (M8.2, re-homed by D15′ — behavior unchanged,
    /// only the surface moved; the identifiers were renamed with it, a
    /// deliberate breaking change executed through the registry). Dismiss
    /// clears the tab's `loadedGameID`, converting the tab into an honest
    /// live tab: `loadIfNeeded()`'s nil branch then clears the error and
    /// the caches. Merely clearing the error string would leave the dead
    /// ID bound and the card would return on the next Board visit —
    /// unbinding is the real resolution, and matches Erase Library's
    /// "open tabs revert to the live board" intent.
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
    
    /// Derives the status-card phase from session + connection state, in
    /// priority order: connection truth first — a pulled cable outranks
    /// everything, and M7.3 splits it: an active auto-reconnect loop reads
    /// as "reconnecting…", while plain disconnected is nil (no card at
    /// all) — then recovery, then the gentle correction nudge, then setup,
    /// then the game itself, then the idle invitation.
    ///
    /// Why nil instead of a `disconnected` phase: the message carried no
    /// action, and with no board there is never a live game, so the live
    /// inspector's empty state is free to say it. `reconnecting` can't
    /// make the same move — it co-occurs with a live game, whose inspector
    /// is showing that game — so it stays a card. (Moved verbatim from
    /// `BoardDestination.hudPhase` by D15′.)
    private var hudPhase: LiveGameHUDView.Phase? {
        if connection.isReconnecting { return .reconnecting }
        guard connection.isConnected else { return nil }
        
        if session.needsRecovery {
            return .recovering(lastSAN: session.liveGame?.sanMoves.last)
        }
        if let hint = session.correctionHint {
            return .correction(message: hint.message)
        }
        if session.awaitingPhysicalSetup {
            return .awaitingSetup
        }
        if let game = session.liveGame {
            if game.isFinished {
                // A failed archive outranks the plain finished banner: the
                // player must Retry or discard before anything else (M5).
                if case .failed(let message) = session.archiveOutcome {
                    return .archiveFailed(result: game.result, message: message)
                }
                return .finished(result: game.result)
            }
            return .playing(
                sideToMove: game.currentState.activeColor,
                lastSAN: game.sanMoves.last,
                ply: game.plyCount
            )
        }
        return .idle
    }
    
    /// The restore checklist while `recovering`, nil otherwise. Recomputed
    /// on every observable change of `connection.physicalBoard`, so rows
    /// disappear live as squares are fixed. `BoardDestination` computes the
    /// same diff for the board's attention/target *overlays* (which stay on
    /// the board by invariant) — two 64-square diffs per render is still
    /// cheap; the original `.task(id:)` memoization note stands.
    private var recoveryGuidance: RecoveryGuidance? {
        .current(session: session, connection: connection)
    }
}

// MARK: Previews

/// Only the load-error arm is reachable: `DGTConnection.status` is
/// `private(set)`, so a preview can't reach `.connected` and `hudPhase`
/// stays nil. The phase card previews live on `LiveGameHUDView` ("All
/// Phases") and the checklist on `RecoveryGuidanceView` — this preview
/// covers what's genuinely this view's own: the M8.2 card, re-homed by D15′.
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

/// The empty guard: disconnected and error-free renders *nothing* — no
/// blank inset at the bottom of every tab. The canvas should be empty.
#Preview("Empty Guard") {
    SessionSidebarPanel(tabState: TabState(), onNewGame: {}, onDismissLoadError: {})
        .frame(width: 260, height: 80)
        .environment(DGTConnection())
        .environment(DGTLiveSession())
        .environment(DGTSessionLog())
}
