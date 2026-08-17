import SwiftUI

/// The monogram avatar, shared by the card, the gallery's large preview, and the columns
/// detail pane - one initials rule everywhere. ("The inspector header" stood in this sentence
/// as a third consumer and never was one; corrected 16 Aug 2026 - the named-consumer claim
/// that doesn't consume, again.)
struct PlayerMonogram: View {

    let name: String
    /// Side of the bounding square. Was `diameter` while the shape was a circle; renamed with
    /// the squircle (16 Aug 2026) so the signature doesn't describe a retired shape.
    var side: CGFloat = 64
    
    private var initials: String {
        let words = name.split(separator: " ")
        let first = words.first?.prefix(1) ?? ""
        let last = words.count > 1 ? (words.last?.prefix(1) ?? "") : ""
        return (first + last).uppercased()
    }
    
    var body: some View {
        ZStack {
            // Squircle, not a circle (Bera's call, 16 Aug 2026). The continuous corner style is
            // what makes it a squircle rather than a rounded rect; 22.5% of the side is roughly
            // the app-icon curve, and the ratio keeps the 64 pt card and 96 pt previews agreeing.
            RoundedRectangle(cornerRadius: side * 0.225, style: .continuous)
                .fill(.tertiary)
            Text(initials)
                .font(.system(size: side * 0.4, weight: .semibold, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .frame(width: side, height: side)
    }
}

/// One labelled metric in a gallery preview's grid - both galleries carried byte-identical
/// private copies.
struct PlayerStatCell: View {
    
    let label: String
    let value: String
    
    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospacedDigit())
        }
    }
}

/// The stat grid of a player preview - shared by the gallery and the columns detail pane.
/// Rated Games is deliberately absent: it needs the histories fold, which neither host receives.
struct PlayerStatsGrid: View {

    let stats: PlayerStats
    let rating: Glicko1.Rating?

    var body: some View {
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
enum RankMedal: String, CaseIterable, Identifiable, Sendable {
    case gold, silver, bronze
    
    init?(rank: Int) {
        switch rank {
        case 1:  self = .gold
        case 2:  self = .silver
        case 3:  self = .bronze
        default: return nil
        }
    }
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .gold:   Color(red: 0.78, green: 0.60, blue: 0.13)
        case .silver: Color(red: 0.60, green: 0.62, blue: 0.65)
        case .bronze: Color(red: 0.72, green: 0.45, blue: 0.20)
        }
    }
    
    /// Style for a rank on a **headline** surface - medal on the podium, `.tint` below. Erased
    /// because the two branches return different style types.
    static func style(forRank rank: Int) -> AnyShapeStyle {
        if let medal = RankMedal(rank: rank) {
            AnyShapeStyle(medal.color)
        } else {
            AnyShapeStyle(.tint)
        }
    }

    /// Style for a rank in a **column** - same podium colours, `.secondary` below. The fallbacks
    /// differ on purpose; the podium must not: one colour on every surface that tints - the table
    /// and both headline previews - or they disagree. (The card left that set 16 Aug 2026; it
    /// prints its rank plain and tints nothing.)
    static func tableStyle(forRank rank: Int) -> AnyShapeStyle {
        if let medal = RankMedal(rank: rank) {
            AnyShapeStyle(medal.color)
        } else {
            AnyShapeStyle(.secondary)
        }
    }
}

// `RankBadge` - the tinted capsule overlaid on the monogram's corner - was deleted 16 Aug 2026
// (Bera's request): the card renders its rank as a plain secondary prefix on the name now, so
// the capsule lost its one caller. Its own doc had already recorded the shape of this ending -
// "one caller (the card) since the table went plain text". The podium colours survive where they
// still have consumers: `style(forRank:)` on the gallery and columns headline ranks,
// `tableStyle(forRank:)` on the table.

/// The Players analogue of `LibraryGameCardView` (icons grid, columns detail, gallery
/// filmstrip); `rank` prefixes the name line.
struct PlayerCardView: View {
    
    // MARK: Stored Properties
    let stats: PlayerStats
    let isSelected: Bool
    let onSelect: () -> Void
    /// Ladder position; nil leaves the name unprefixed.
    var rank: Int? = nil
    /// The caption under the name (16 Aug 2026, by request - it replaced the games count, which
    /// lives in the profile grid). Nil renders the placeholder; provisional keeps its `*`.
    var rating: Glicko1.Rating? = nil
    /// Presents "Show in Library" when set; optional so previews stay unchanged.
    var onShowInLibrary: (() -> Void)? = nil
    /// Double-click - the matchup window's door (17 Aug 2026). Defaulted so previews and any
    /// host with no window to offer stay valid.
    var onOpen: () -> Void = {}

    /// Monogram side. A parameter, not an environment read - the Library card's `glyphWidth`
    /// reason: the gallery filmstrip keeps its own size while the icons grid follows View
    /// Options. Hosts that pass nothing render as before. (Until 16 Aug 2026 this was a
    /// hardcoded 64, so the icon-size slider grew the *cell* and the squircle stood still -
    /// the slider read as padding.)
    var monogramSide: CGFloat = 64

    // MARK: Derived
    /// "#12 Magnus Carlsen" as one run - a styled `Text` interpolated into the outer `Text`,
    /// which keeps a two-style line a single wrapping, centring, highlightable element.
    /// (`Text` concatenation's `+` did the same job and is deprecated in macOS 26.)
    private var nameLine: Text {
        if let rank {
            // Medal colours for the PODIUM only (17 Aug 2026, second pass the same evening):
            // #1-#3 wear gold/silver/bronze, everything below keeps the card's own
            // `.secondary` - the headline surfaces' `.tint` fallback is deliberately not
            // copied here, "not tinted" being the request's exact words.
            let rankStyle = RankMedal(rank: rank).map { AnyShapeStyle($0.color) }
                ?? AnyShapeStyle(.secondary)
            return Text("\(Text("#\(rank)").foregroundStyle(rankStyle).monospacedDigit()) \(stats.name)")
        } else {
            return Text(stats.name)
        }
    }

    // MARK: Body
    var body: some View {
        VStack(spacing: 4) {
            PlayerMonogram(name: stats.name, side: monogramSide)
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.secondary.opacity(isSelected ? 0.15 : 0))
                }

            // The rank prefixes the name (Bera, 16 Aug 2026 - fourth placement that day: tinted
            // overlay capsule → plain row below the squircle → inside it → in front of the name).
            // One `Text` (styled prefix interpolated in) so prefix and name wrap, centre and
            // highlight as one block; the prefix stays secondary so the name carries the line.
            // Still no podium tint.
            nameLine
                .font(.callout)
            // Capped, no longer reserved (Bera's reversal): uniform card heights bought a blank line under
            // every single-line name.
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.vertical, 2)
                // Tracks the monogram (94 at the 64 default) - a fixed 94 under a grown squircle
                // would truncate names into cells with room to spare.
                .frame(width: monogramSide + 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.accentColor : .clear)
                )
            
            Text(rating?.displaySummary ?? RosterSummary.displayUnknown)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        // The Library card's gesture arrangement, copied exactly: selection is a
        // `simultaneousGesture`, not a second `onTapGesture` - two sequential taps made
        // SwiftUI hold the single click for the full double-click interval. Select on
        // mouse-down; only open waits.
        .onTapGesture(count: 2, perform: onOpen)
        .simultaneousGesture(TapGesture().onEnded { onSelect() })
        // Without `.combine`, macOS exposes only the inner texts - the identifier never lands on a
        // tappable element.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.playerCard(stats.name))
        // The conditional Show in Library moved into `PlayerActionsMenu` - this card is the host whose
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

#Preview("Rank Prefixes") {
    HStack(spacing: 20) {
        ForEach(PreviewFixtures.rankedPlayers().prefix(4), id: \.id) { ranked in
            PlayerCardView(
                stats: ranked.stats,
                isSelected: false,
                onSelect: {},
                rank: ranked.rank,
                rating: ranked.rating,
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
