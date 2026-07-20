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
                .font(.system(size: diameter * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(.tint)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// The Players analogue of `LibraryGameCardView`, used by the icons grid,
/// the columns detail, and the gallery filmstrip. Selection-only in the
/// POC: players have no destructive or open actions yet (D9′ — the
/// registry is machine-managed; "Show in Library" arrives in M-prs.6).
internal struct PlayerCardView: View {
    
    // MARK: Stored Properties
    let stats: PlayerStats
    let isSelected: Bool
    let onSelect: () -> Void
    
    // MARK: Body
    var body: some View {
        VStack(spacing: 6) {
            PlayerMonogram(name: stats.name, diameter: 64)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.secondary.opacity(isSelected ? 0.15 : 0))
                }
            
            Text(stats.name)
                .font(.callout)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
            
            Text("\(stats.wins)–\(stats.draws)–\(stats.losses) · \(stats.games) games")
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
    }
}
