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
                .fill(.tertiary)
            Text(initials)
                .font(.system(size: diameter * 0.4, weight: .semibold, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// One labelled metric in a gallery preview's grid — both galleries carried byte-identical
/// private copies.
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

/// The stat grid of a player preview — shared by the gallery and the columns detail pane.
/// Rated Games is deliberately absent: it needs the histories fold, which neither host receives.
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
                PlayerStatCell(
                    "Uncertainty",
                    rating.map { "±\(Int($0.deviation.rounded()))" } ?? RosterSummary.displayUnknown
                )
                PlayerStatCell("Mates", "\(stats.matesDelivered)")
            }
            GridRow {
                PlayerStatCell("First Played", RosterSummary.displayDate(stats.firstPlayed))
                PlayerStatCell("Last Played", RosterSummary.displayDate(stats.lastPlayed))
            }
        }
    }
}

/// Podium tint: gold, silver, bronze, nothing below third. `init?(rank:)` is the single
/// statement of the podium's depth.
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
    
    /// Style for a rank on a **headline** surface — medal on the podium, `.tint` below. Erased
    /// because the two branches return different style types.
    internal static func style(forRank rank: Int) -> AnyShapeStyle {
        if let medal = RankMedal(rank: rank) {
            AnyShapeStyle(medal.color)
        } else {
            AnyShapeStyle(.tint)
        }
    }

    /// Style for a rank in a **column** — same podium colours, `.secondary` below. The fallbacks
    /// differ on purpose; the podium must not: one colour everywhere or the table and cards disagree.
    internal static func tableStyle(forRank rank: Int) -> AnyShapeStyle {
        if let medal = RankMedal(rank: rank) {
            AnyShapeStyle(medal.color)
        } else {
            AnyShapeStyle(.secondary)
        }
    }
}

/// The ladder position as a chip — one caller (the card) since the table went plain text; kept
/// because a second host wanting a *different colour* is the failure this type prevents.
/// The outer inset stays with the caller: the card needs it, a table cell must not inherit it.
internal struct RankBadge: View {

    internal let rank: Int

    internal var body: some View {
        let style = RankMedal.style(forRank: rank)
        Text("#\(rank)")
            .font(.caption)
            .padding(5)
            .foregroundStyle(.primary)
            .padding(.horizontal, 3)
            .background(Capsule().fill(style))
            .offset(x: 6, y: 6)
    }
}

/// The Players analogue of `LibraryGameCardView` (icons grid, columns detail, gallery
/// filmstrip); `rank` earns the badge.
internal struct PlayerCardView: View {
    
    // MARK: Stored Properties
    let stats: PlayerStats
    let isSelected: Bool
    let onSelect: () -> Void
    /// Ladder position; nil hides the badge.
    var rank: Int? = nil
    /// Presents "Show in Library" when set; optional so previews stay unchanged.
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
            // Capped, no longer reserved (Bera's reversal): uniform card heights bought a blank line under
            // every single-line name.
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
        // Without `.combine`, macOS exposes only the inner texts — the identifier never lands on a
        // tappable element.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.playerCard(stats.name))
        // The conditional Show in Library moved into `PlayerActionsMenu` — this card is the host whose
        // shape the shared type absorbed.
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

/// Monogram edge cases: single names, diacritics, comma forms, and a very long name that must
/// not blow the card's width.
#Preview("Name Edge Cases") {
    let names = ["Bera", "Magnus Carlsen", "Ding Liren",
                 "Nepomniachtchi, Ian", "Šarić, Ivan", "X"]
    return HStack(spacing: 16) {
        ForEach(names, id: \.self) { PlayerMonogram(name: $0) }
    }
    .padding()
}
