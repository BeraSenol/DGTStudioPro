//
//  PlayerCardView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import SwiftUI

/// The monogram avatar, shared by the card, the gallery's large preview,
/// and the inspector header — one initials rule everywhere.
internal struct PlayerMonogram: View {
    
    internal let name: String
    internal var diameter: CGFloat = 64
    
    private var initials: String {
        let words = name.split(separator: " ")
        let first = words.first?.prefix(1) ?? ""
        let last = words.count > 1 ? (words.last?.prefix(1) ?? "") : ""
        return (first + last).uppercased()
    }
    
    internal var body: some View {
        ZStack {
            Circle()
                .fill(.tint.opacity(0.15))
            Text(initials)
                .font(.system(size: diameter * 0.4, weight: .semibold, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(.tint)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// One labelled metric in a gallery preview's grid. Both galleries carried a
/// byte-identical private `statCell` — the `PlayerMonogram` precedent: shared
/// presentation for the Players/Rankings pair lives here, once.
internal struct PlayerStatCell: View {
    
    internal let label: String
    internal let value: String
    
    internal init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
    
    internal var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospacedDigit())
        }
    }
}

/// The Players analogue of `LibraryGameCardView`, used by the icons grids,
/// the columns details, and the gallery filmstrips of *both* Players and
/// Rankings — the latter passes `rank` (M-prs.4) and gets the badge.
/// Players have no destructive actions (D9′ — the registry is
/// machine-managed); the one non-selection affordance is M-prs.6's
/// optional "Show in Library" context menu, threaded from the
/// destinations so the card stays sidebar-unaware.
internal struct PlayerCardView: View {
    
    // MARK: Stored Properties
    let stats: PlayerStats
    let isSelected: Bool
    let onSelect: () -> Void
    /// Ladder position; nil outside Rankings.
    var rank: Int? = nil
    /// Presents the "Show in Library" context menu when set (M-prs.6).
    /// Optional so previews and any selection-only context stay unchanged.
    var onShowInLibrary: (() -> Void)? = nil
    
    // MARK: Body
    var body: some View {
        VStack(spacing: 4) {
            PlayerMonogram(name: stats.name, diameter: 64)
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.secondary.opacity(isSelected ? 0.15 : 0))
                }
                .overlay(alignment: .topLeading) {
                    if let rank {
                        rankBadge(rank)
                    }
                }
            
            Text(stats.name)
                .font(.callout)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.vertical, 2)
                .frame(width: 94)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.accentColor : .clear)
                )
            
            Text("\(stats.games) games")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        // Same trap as `LibraryGameCardView`: without `.combine`, macOS
        // exposes only the inner texts and the identifier never lands on
        // a tappable element.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.playerCard(stats.name))
        .contextMenu {
            if let onShowInLibrary {
                Button {
                    onShowInLibrary()
                } label: {
                    Label("Show in Library", systemImage: "books.vertical")
                }
                .accessibilityIdentifier(AccessibilityID.contextShowInLibrary)
            }
        }
    }
    
    // MARK: Instance Methods
    private func rankBadge(_ rank: Int) -> some View {
        Text("#\(rank)")
            .font(.caption2.weight(.bold).monospacedDigit())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(.tint.opacity(0.2)))
            .foregroundStyle(.tint)
            .padding(4)
    }
}

// MARK: Previews

#Preview("Selection States") {
    HStack(spacing: 20) {
        PlayerCardView(stats: PreviewFixtures.topStats(), isSelected: false, onSelect: {})
        PlayerCardView(stats: PreviewFixtures.topStats(), isSelected: true, onSelect: {})
    }
    .padding()
}

#Preview("Rank Badges") {
    HStack(spacing: 20) {
        ForEach(PreviewFixtures.rankedPlayers().prefix(4), id: \.id) { ranked in
            PlayerCardView(
                stats: ranked.stats,
                isSelected: false,
                onSelect: {},
                rank: ranked.rank,
                onShowInLibrary: {}
            )
        }
    }
    .padding()
}

/// Monogram edge cases — the initials derivation is the interesting part:
/// single names, diacritics, comma-form display names, and a very long name
/// that must not blow the card's width.
#Preview("Name Edge Cases") {
    let names = ["Bera", "Magnus Carlsen", "Ding Liren",
                 "Nepomniachtchi, Ian", "Šarić, Ivan", "X"]
    return HStack(spacing: 16) {
        ForEach(names, id: \.self) { PlayerMonogram(name: $0) }
    }
    .padding()
}
