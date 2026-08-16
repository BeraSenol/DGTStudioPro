import SwiftData
import SwiftUI

/// Finder's tag dots (16 Aug 2026, by request): one circle per matching smart tag, before the
/// game's name, later dots overlapping the earlier - Finder's own arrangement, down to the
/// hairline of background separating the overlap and the cap of three.
struct TagDots: View {

    /// Matching tags' colors in sidebar order; the first three render, later ones on top.
    let colors: [Color]

    var body: some View {
        if !colors.isEmpty {
            HStack(spacing: -3) {
                ForEach(Array(colors.prefix(3).enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        // The separating hairline where dots overlap - `.background` so it melts
                        // into whatever the row renders on, selection tint included.
                        .overlay(Circle().strokeBorder(.background, lineWidth: 1))
                        .frame(width: 8, height: 8)
                }
            }
            // Decoration, not an affordance: the dots say "tagged", the sidebar says which.
            .accessibilityHidden(true)
        }
    }
}

/// The per-game fold behind the dots. Its own name so the four Library surfaces cannot each
/// grow a spelling of "which tags match this game".
enum SmartTagMatches {

    /// Colors of the smart tags matching `game`, in the order the sidebar lists them.
    ///
    /// Cost, named for the census: rules evaluate per game per render at every call site - the
    /// `LibraryFilter.matches` family multiplied by the tag count, bounded by personal-scale
    /// tag lists and unmeasured until the Instruments pass like the rest of the family.
    static func colors(for game: PGN, in tags: [SmartTag]) -> [Color] {
        guard !tags.isEmpty else { return [] }
        let record = game.gameRecord
        return tags.filter { $0.matches(record) }.map(\.color)
    }
}

// MARK: Previews

/// One, two, and the cap: four matching tags render three dots, later on top.
#Preview("Dot Counts") {
    VStack(alignment: .leading, spacing: 12) {
        TagDots(colors: [.red])
        TagDots(colors: [.red, .blue])
        TagDots(colors: [.red, .blue, .green, .orange])
    }
    .padding()
}
