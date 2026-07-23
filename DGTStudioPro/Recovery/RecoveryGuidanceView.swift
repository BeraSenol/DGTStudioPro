//
//  RecoveryGuidanceView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/07/2026.
//

import SwiftUI

/// The square-by-square restore checklist shown under the status card in
/// the sidebar's `SessionSidebarPanel` while the session is `recovering`
/// (M6.2; re-homed by D15′ — the panel owns outer spacing now). Pure
/// presentation: the panel hands
/// in a freshly computed `RecoveryGuidance` on every physical board change,
/// so rows disappear live as the player fixes squares. Discard Game remains
/// available in the inspector as the escape hatch — this panel is guidance,
/// not a dialog (Decision #1: restoring the position is the only
/// resolution, so there is nothing to confirm).
///
/// Also the home of "Export Diagnostics…" (M6.3), wiring the long-built
/// `DGTSessionLog.exportViaSavePanel()`: a real desync is exactly the
/// moment the session log is worth saving, so the affordance lives here
/// rather than in a buried menu.
internal struct RecoveryGuidanceView: View {
    
    // MARK: Stored Properties
    
    internal let guidance: RecoveryGuidance
    
    /// Wired by the destination to `sessionLog.exportViaSavePanel()`.
    internal let onExportDiagnostics: () -> Void
    
    // MARK: Body
    
    internal var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Restore these squares")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(guidance.items.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityID.liveRecoveryCount)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(guidance.items) { item in
                        Text(item.message)
                            .font(.callout)
                            .accessibilityIdentifier(
                                AccessibilityID.liveRecoveryItem(item.square.algebraicNotation)
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 140)
            
            HStack {
                Spacer()
                Button("Export Diagnostics…", action: onExportDiagnostics)
                    .controlSize(.small)
                    .accessibilityIdentifier(AccessibilityID.liveRecoveryExport)
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            // A whisper of the recovery tint, matching the HUD banner.
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.red.opacity(0.35))
        }
        .accessibilityIdentifier(AccessibilityID.liveRecoveryPanel)
    }
}

/// The common case in anger: one piece lifted, one square to fix. The
/// 20 July field session desynced twice, both single-piece diffs.
#Preview("Single Fix") {
    var physical = Position.starting
    physical[Squares.e2] = .empty
    
    return RecoveryGuidanceView(
        guidance: RecoveryGuidance(physical: physical, target: .starting),
        onExportDiagnostics: {}
    )
    .padding()
    .frame(width: 420)
}

/// Wrong piece on the right square — the `replace` action, which is
/// attention-only in the highlight split (no target square).
#Preview("Wrong Piece") {
    var physical = Position.starting
    physical[Squares.d1] = .whiteKnight    // queen replaced by a knight
    
    return RecoveryGuidanceView(
        guidance: RecoveryGuidance(physical: physical, target: .starting),
        onExportDiagnostics: {}
    )
    .padding()
    .frame(width: 420)
}

/// A full scramble — the scrolling/垂直 growth case for a sidebar-pinned
/// panel, where the checklist must not push the panel past its inset.
#Preview("Scrambled Board") {
    var physical = Position.empty
    physical[Squares.e4] = .whiteKing
    physical[Squares.a8] = .blackKing
    physical[Squares.h1] = .whiteRook
    
    return RecoveryGuidanceView(
        guidance: RecoveryGuidance(physical: physical, target: .starting),
        onExportDiagnostics: {}
    )
    .padding()
    .frame(width: 420, height: 520)
}

/// Already fixed: an empty guidance renders nothing. The panel guards on
/// `!guidance.isEmpty`, so this pins that the view itself degrades cleanly.
#Preview("Resolved") {
    RecoveryGuidanceView(
        guidance: RecoveryGuidance(physical: .starting, target: .starting),
        onExportDiagnostics: {}
    )
    .padding()
    .frame(width: 420, height: 120)
}
