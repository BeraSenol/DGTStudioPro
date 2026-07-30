//
//  RenamePlayerSheet.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 30/07/2026.
//

import SwiftUI

/// Renaming a player (M5, D37′) — one text field over **tag form**, with the
/// display form the app will show derived beneath it.
///
/// **Why the tag and not the name.** `PGN.white` / `PGN.black` store tag form
/// and export writes it byte for byte (D24′); `Player.name` is derived from it
/// through `PlayerName.displayForm`. D23′ forbids the inverse, so a sheet that
/// edited the display name would have nothing legitimate to store. Editing the
/// tag and *showing* the derivation makes the one-way rule visible instead of
/// merely obeyed: type "Şenol, Bera", watch "Bera Şenol" appear, and the
/// relationship between the two forms stops being folklore.
///
/// A value-typed draft with Cancel/Save, the `TagDraft` shape (D12′): nothing
/// is written until Save, and the store door owns every consequence — the
/// rewrite across linked games, the re-resolve, the rehash, and D39′'s
/// refusal. This sheet's only job is to collect a string and say what it will
/// look like.
internal struct RenamePlayerSheet: View {

    // MARK: Static Constants

    /// `DGTConnectionView.Metrics`' HIG-derived spacing, borrowed by name
    /// rather than by number.
    private static let margin: CGFloat = 20
    private static let siblingSpacing: CGFloat = 12
    private static let captionSpacing: CGFloat = 4

    // MARK: Stored Properties

    /// The player's current tag form — `tagName ?? name`, the seat picker's
    /// own fallback (D29′) for a pre-schema row that never got one.
    internal let currentTag: String

    /// How many games the rename will rewrite. Shown because the cost is
    /// real and invisible otherwise: a rename is not a label change, it
    /// rewrites stored movetext metadata and moves those games' content
    /// hashes (D37′'s accepted price).
    internal let gameCount: Int

    internal let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tag: String

    // MARK: Initializers

    internal init(currentTag: String, gameCount: Int, onSave: @escaping (String) -> Void) {
        self.currentTag = currentTag
        self.gameCount = gameCount
        self.onSave = onSave
        _tag = State(initialValue: currentTag)
    }

    // MARK: Derived

    /// What the app will show once this tag is stored — the same transform
    /// every other surface applies, run live so the sheet can't disagree with
    /// the Players list about what it just did.
    private var derivedDisplayName: String {
        PlayerName.displayForm(of: tag)
    }

    /// Save is refused for exactly what the store door refuses: PGN's
    /// placeholder vocabulary. Checking it here as well is not a second
    /// implementation of the rule — the door still enforces it — it is the
    /// difference between a disabled button and a dialog that lets you press
    /// Save and then explains why it did nothing.
    private var canSave: Bool {
        !derivedDisplayName.isEmpty
        && derivedDisplayName != "?"
        && PlayerName.folded(tag) != PlayerName.folded(currentTag)
    }

    // MARK: Body

    internal var body: some View {
        VStack(alignment: .leading, spacing: Self.siblingSpacing) {
            Text("Rename Player")
                .font(.headline)

            VStack(alignment: .leading, spacing: Self.captionSpacing) {
                TextField("Name, as PGN stores it", text: $tag)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier(AccessibilityID.playerRenameTagField)
                Text("PGN tag form — surname first, e.g. “Senol, Bera”.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: Self.captionSpacing) {
                LabeledContent("Shown as", value: derivedDisplayName.isEmpty ? "—" : derivedDisplayName)
                Text(rewriteSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Rename") {
                    onSave(tag)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
                .accessibilityIdentifier(AccessibilityID.playerRenameSave)
            }
        }
        .padding(Self.margin)
        .frame(width: 380, height: 260)
        .accessibilityIdentifier(AccessibilityID.playerRenameSheet)
    }

    /// Names the cost in the sheet rather than in a doc comment nobody reading
    /// the dialog will see.
    private var rewriteSummary: String {
        switch gameCount {
        case 0:  return "This player has no games; only the registry entry changes."
        case 1:  return "Rewrites the name stored in 1 game."
        default: return "Rewrites the name stored in \(gameCount) games."
        }
    }
}

// MARK: Previews

/// The ordinary case, and the one that shows the derivation doing work: a
/// comma tag rendering as "Bera Şenol" beneath the field.
#Preview("Comma Tag") {
    RenamePlayerSheet(currentTag: "Şenol, Bera", gameCount: 42, onSave: { _ in })
}

/// Free text with no comma — `displayForm` folds rather than flips, so the
/// two lines read alike. Worth its own preview because "the preview looks
/// broken, both lines are the same" is the reading to pre-empt.
#Preview("No Comma") {
    RenamePlayerSheet(currentTag: "Bera", gameCount: 1, onSave: { _ in })
}

/// The orphan: a player whose games were all deleted. The summary line says
/// so instead of claiming it will rewrite nothing.
#Preview("No Games") {
    RenamePlayerSheet(currentTag: "Reinaud, Lorenzo", gameCount: 0, onSave: { _ in })
}
