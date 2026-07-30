//
//  MergePlayerSheet.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 30/07/2026.
//

import SwiftData
import SwiftUI

/// Folding one player into another (M5, D38′): pick the survivor, and every
/// game the loser holds is retagged to the survivor's stored tag form, then
/// the emptied row is deleted.
///
/// **The direction is fixed and stated, because merges are not symmetric.**
/// The player you opened is the one that disappears; the one you pick is the
/// one whose tag every affected game ends up carrying. Getting that backwards
/// silently rewrites the wrong forty games, so the sheet says which name
/// survives in the same sentence as which name goes.
///
/// Model-bearing by necessity — it lists the other players — which is why it
/// is a sheet of its own rather than a second mode on `RenamePlayerSheet`:
/// that one is a value-typed string editor with no store reach at all, and
/// widening it to sometimes query would cost exactly the property that makes
/// it previewable three ways.
internal struct MergePlayerSheet: View {

    // MARK: Static Constants

    private static let margin: CGFloat = 20
    private static let siblingSpacing: CGFloat = 12
    private static let captionSpacing: CGFloat = 4

    // MARK: Stored Properties

    /// The player being folded away — the row that will not exist afterwards.
    internal let losingName: String
    internal let losingKey: String
    internal let gameCount: Int
    internal let onMerge: (PersistentIdentifier) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Player.name) private var players: [Player]
    @State private var survivorID: PersistentIdentifier?

    // MARK: Derived

    /// Everyone except the player being merged away.
    ///
    /// Filtered on `normalizedName`, not on the model identifier: the caller's
    /// currency throughout the Players destination is the pure stats key
    /// (D10′), and matching on it keeps this sheet from needing a resolved
    /// `Player` it would only use for an equality check.
    private var candidates: [Player] {
        players.filter { $0.normalizedName != losingKey }
    }

    private var survivor: Player? {
        survivorID.flatMap { id in candidates.first { $0.persistentModelID == id } }
    }

    // MARK: Body

    internal var body: some View {
        VStack(alignment: .leading, spacing: Self.siblingSpacing) {
            Text("Merge Player")
                .font(.headline)

            if candidates.isEmpty {
                // The one-player Library. A picker with nothing in it reads as
                // a bug; saying so reads as an answer.
                Text("There is no other player to merge “\(losingName)” into.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: Self.captionSpacing) {
                    Picker("Merge into", selection: $survivorID) {
                        Text("Choose a player…").tag(PersistentIdentifier?.none)
                        ForEach(candidates) { player in
                            Text(player.name).tag(PersistentIdentifier?.some(player.persistentModelID))
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.playerMergePicker)

                    Text(consequence)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Merge") {
                    if let survivorID { onMerge(survivorID) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(survivor == nil)
                .accessibilityIdentifier(AccessibilityID.playerMergeConfirm)
            }
        }
        .padding(Self.margin)
        .frame(width: 400, height: 250)
        .accessibilityIdentifier(AccessibilityID.playerMergeSheet)
    }

    /// Spells out the asymmetry with both names in it, so the sentence is
    /// wrong-looking rather than merely wrong if the direction is misread.
    private var consequence: String {
        guard let survivor else {
            return "“\(losingName)” will be removed once you choose who to merge it into."
        }
        let games = gameCount == 1 ? "1 game" : "\(gameCount) games"
        return "\(games) will be retagged to “\(survivor.tagName ?? survivor.name)”, "
             + "and “\(losingName)” will no longer exist."
    }
}

// MARK: Previews

/// The empty-candidate branch — reachable whenever the Library holds exactly
/// one player, and the only state where the primary control is absent rather
/// than disabled.
#Preview("No Other Players") {
    MergePlayerSheet(
        losingName: "Bera Şenol",
        losingKey: "bera şenol",
        gameCount: 3,
        onMerge: { _ in }
    )
    .modelContainer(for: Player.self, inMemory: true)
}

/// Nothing picked yet: Merge disabled, and the consequence line saying what
/// is still missing rather than describing a merge that has no target.
#Preview("Nothing Chosen") {
    MergePlayerSheet(
        losingName: "L. Reinaud",
        losingKey: "l. reinaud",
        gameCount: 7,
        onMerge: { _ in }
    )
    .modelContainer(for: Player.self, inMemory: true)
}
