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

// MARK: Previews

#Preview("Misplaced Pieces") {
    var physical = Position.starting
    physical[Squares.g1] = .empty
    physical[Squares.h3] = .whiteKnight    // knight went to the wrong square
    physical[Squares.e7] = .empty          // pawn lifted off the board
    physical[Squares.e4] = .blackPawn      // …and dropped somewhere odd

    return RecoveryGuidanceView(
        guidance: RecoveryGuidance(physical: physical, target: .starting),
        onExportDiagnostics: {}
    )
    .padding()
    .frame(width: 420)
}
