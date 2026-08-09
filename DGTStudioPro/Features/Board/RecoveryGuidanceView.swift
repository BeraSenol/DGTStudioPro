import SwiftUI

/// The square-by-square restore checklist under the status card while recovering. Pure
/// presentation over `RecoveryGuidance`; a checklist, not a dialog — restoring the position is
/// the only resolution (Decision #1).
internal struct RecoveryGuidanceView: View {
    
    // MARK: Stored Properties
    
    internal let guidance: RecoveryGuidance
    
    /// Wired by `SessionSidebarPanel` to `sessionLog.exportViaSavePanel()`.
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
                Button("Export Diagnostics", action: onExportDiagnostics)
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

/// A full scramble — the scrolling / vertical-growth case for a sidebar-pinned
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
