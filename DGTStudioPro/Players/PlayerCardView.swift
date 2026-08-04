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

/// The five-fact stat grid of a player preview — Games / Record / Win Rate,
/// then Rating / Mates. Extracted from `PlayersGalleryView` when the columns
/// detail pane became its second host (the 2 Aug 2026 Finder-column
/// redesign): the D48′ note this grid carried records the two retired
/// galleries disagreeing on spacing and saying Wins twice, which is exactly
/// the drift two private copies would reopen. Record's first component
/// absorbs Wins here as it does in the inspector.
internal struct PlayerStatsGrid: View {

    internal let stats: PlayerStats
    internal let rating: Glicko1.Rating?

    internal var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
            GridRow {
                PlayerStatCell("Games", "\(stats.games)")
                PlayerStatCell("Record", "\(stats.wins)–\(stats.draws)–\(stats.losses)")
                PlayerStatCell("Win Rate", stats.winRate.formatted(.percent.precision(.fractionLength(0))))
            }
            GridRow {
                PlayerStatCell("Rating", rating?.displaySummary ?? RosterSummary.displayUnknown)
                PlayerStatCell("Mates", "\(stats.matesDelivered)")
            }
        }
    }
}

/// The podium tint for a ladder position: gold, silver, bronze, and nothing
/// below third. `init?(rank:)` is the single statement of the podium's depth,
/// so no surface can decide the top four are special.
///
/// The literals are mid-luminance on purpose. Metallic gold (#D4AF37) and
/// silver (#C0C0C0) are near-white and disappear against a light window,
/// while darkening them enough to read there turns them muddy in dark mode;
/// these sit in the middle so one literal serves both appearances and no
/// asset is needed. If per-appearance tuning is ever wanted, that is a colour
/// set in the catalog — and the mapping stays an exhaustive `switch self`
/// either way, the `BoardStyle` argument: a new case should be a compile
/// error, not a blank swatch.
internal enum RankMedal: String, CaseIterable, Identifiable, Sendable {
    case gold, silver, bronze
    
    internal init?(rank: Int) {
        switch rank {
        case 1:  self = .gold
        case 2:  self = .silver
        case 3:  self = .bronze
        default: return nil
        }
    }
    
    internal var id: String { rawValue }
    
    internal var color: Color {
        switch self {
        case .gold:   Color(red: 0.78, green: 0.60, blue: 0.13)
        case .silver: Color(red: 0.60, green: 0.62, blue: 0.65)
        case .bronze: Color(red: 0.72, green: 0.45, blue: 0.20)
        }
    }
    
    /// The style for *any* rank — the medal on the podium, `.tint` below it.
    /// Erased rather than `Color?` with an `.accentColor` fallback, because
    /// the unmedalled badge has always been `.tint` and therefore follows a
    /// host's `.tint()`; collapsing it to `.accentColor` would be a silent
    /// behaviour change for every rank from fourth down.
    internal static func style(forRank rank: Int) -> AnyShapeStyle {
        if let medal = RankMedal(rank: rank) {
            AnyShapeStyle(medal.color)
        } else {
            AnyShapeStyle(.tint)
        }
    }
}

/// The ladder position as a chip — one rendering behind the icons badge and
/// the table's Rank column, so the podium can't be gold in one and blue in
/// the other.
///
/// The outer inset deliberately stays with the caller: the card needs it to
/// hold the chip off its corner, and a table cell must not inherit it.
internal struct RankBadge: View {
    
    internal let rank: Int
    
    internal var body: some View {
        let style = RankMedal.style(forRank: rank)
        Text("#\(rank)")
            .font(.caption2.weight(.bold).monospacedDigit())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(style.opacity(0.2)))
            .foregroundStyle(style)
    }
}

/// The Players analogue of `LibraryGameCardView`, used by the icons grid,
/// the columns details, and the gallery filmstrip. `rank` (M-prs.4) earns
/// the badge — passed by the Players hosts since D48′ put the ladder in
/// every mode; before the merge it was Rankings' distinguishing input.
/// Players have no destructive actions (D9′ — the registry is
/// machine-managed); the one non-selection affordance is M-prs.6's
/// optional "Show in Library" context menu, threaded from the
/// destinations so the card stays sidebar-unaware.
internal struct PlayerCardView: View {
    
    // MARK: Stored Properties
    let stats: PlayerStats
    let isSelected: Bool
    let onSelect: () -> Void
    /// Ladder position; nil hides the badge (previews, rank-free contexts).
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
                        RankBadge(rank: rank)
                            .padding(4)
                    }
                }
            
            Text(stats.name)
                .font(.callout)
            // Capped, no longer reserved (Bera, 1 Aug — reversing the
            // earlier call this comment used to justify). The reservation
            // bought uniform card heights across the two differently-sorted
            // destinations, at the price of a blank line under every
            // one-line name — which is most of them — and the empty band
            // read worse than the ragged rows it prevented. Accepted: the
            // same player can be two heights in two grids; the grid's own
            // row alignment absorbs it.
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
        // The conditional Show in Library — and the reason Get Info sits
        // outside it — moved into `PlayerActionsMenu`, which is where all
        // three Players hosts now get their menu. This card is the host that
        // *had* the conditional, so it is the one whose shape the shared type
        // had to grow an optional to keep.
        //
        // The closure is adapted rather than re-typed: a card is handed a
        // no-argument action because it draws exactly one player and the host
        // already closed over which. Widening it to take a key would make
        // every caller pass back the id the card was built from.
        .contextMenu {
            PlayerActionsMenu(
                key: stats.id,
                onShowInLibrary: onShowInLibrary.map { show in { _ in show() } }
            )
        }
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
