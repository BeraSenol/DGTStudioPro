import SwiftUI
import SwiftData

struct LibraryGameCardView: View {

    // MARK: Stored Properties
    let game: PGN

    /// Document-sheet width. A parameter, not an environment read, so the gallery filmstrip keeps
    /// its own size while the icons grid follows View Options. A `var` with a default - hosts that
    /// pass nothing render as before.
    var glyphWidth: CGFloat = 60

    /// The analysis badge's subject, bottom-trailing on the sheet in every host. Both
    /// production hosts pass state, never the model - no blob decode per card.
    var analysisState: AnalysisGlyph.State = .unanalyzed

    /// What the sheet is inscribed with - the View Options "Icon" picker's choice, passed by
    /// both hosts from `CollectionViewOptions.libraryCardInscription`. Defaulted to the
    /// pre-picker inscription so previews and any future host render as before.
    var inscription: LibraryCardInscription = .index

    let isSelected: Bool
    let onSelect: () -> Void
    /// Double-click's door. The card carries **no context menu since 23 Aug 2026** - it drew
    /// `GameActionsMenu(games: [game])`, so however many cards were selected the menu read
    /// singular ("Export PGN" over a fifty-game selection, Get Info always present) while the
    /// closures underneath acted on the whole set. The menu lives on the hosts now, which own
    /// the selection the labels must count - the columns row's rule ("a per-row menu would
    /// shadow it"), applied to the card.
    let onOpen: () -> Void

    // MARK: Body
    var body: some View {
        VStack(spacing: 5) {
            documentIcon
            nameLabel
            Text(game.displayDate)
                .font(.caption)
                .foregroundStyle(.tint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        // Selection is a `simultaneousGesture`, not a second `onTapGesture`: two sequential taps made
        // SwiftUI hold the single click for the full double-click interval. Finder selects on
        // mouse-down; only open waits.
        .onTapGesture(count: 2, perform: onOpen)
        .simultaneousGesture(TapGesture().onEnded { onSelect() })
        // Collapse into one addressable element - without `.combine`, macOS exposes only the inner
        // static texts and the identifier never lands on a tappable element.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.gameCard(game.name))
    }

    // MARK: Instance Methods
    private var documentIcon: some View {
        ZStack {
            // `document.fill`, not `doc`: a filled sheet is paper, and the ordinal is written on it.
            // The `document.*` family, not `doc.*` (21 Aug 2026): one game was drawn with three
            // different symbols across two eras of the catalogue - `doc.fill` here,
            // `text.document.fill` in the columns row, `document.fill` in the inspector - and the
            // card and the inspector sat in the same destination. `document.*` is the current
            // family and already had the majority.
            Image(systemName: "document.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white)
                .frame(width: glyphWidth)
                .fontWeight(.ultraLight)
            // Rigid, not merely width-pinned: a resizable image under `fit` was the card's one compressible
            // element - the filmstrip squeezed the glyph to half height.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 6)

            // `.black` is ink on the explicitly-`.white` sheet - the pair must be stated together or Light
            // Mode gets white on white. 14/60 is the pre-slider pair, so the default renders byte-identically.
            inscriptionText
                .foregroundStyle(.black)
                .frame(maxWidth: glyphWidth * (42.0 / 60.0))
                .offset(x: glyphWidth * (3.0 / 60.0), y: glyphWidth * (4.0 / 60.0))
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.secondary.opacity(isSelected ? 0.15 : 0))
        }
        // Finder's badge corner, on the icon block (name and date stay clear), inset so the chip
        // overlaps the paper's corner rather than floating in the gutter.
        .overlay(alignment: .bottomTrailing) {
            AnalysisStatusBadge(state: analysisState)
                .padding(9)
        }
    }

    @ViewBuilder
    private var nameLabel: some View {
        Text(game.name)
            .font(.callout)
            .lineLimit(3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor : .clear)
            )
            .foregroundStyle(isSelected ? Color.white : .primary)
    }

    /// The inscription, rendered. One `.single` spelling for index, result and round; the date is
    /// the two-tier calendar form - month abbreviated small above, day large below. Every size is
    /// a fraction of `glyphWidth` so the slider scales the writing with the sheet, and the
    /// `.index` arm reproduces the pre-picker card byte-for-byte (7/30 semibold monospaced,
    /// 0.6 shrink floor). The placeholder for an absent value is the derivation's, stated once
    /// at `LibraryCardInscription.content` - the card no longer spells its own.
    @ViewBuilder
    private var inscriptionText: some View {
        let content = inscription.content(
            index: game.libraryIndex,
            result: game.result,
            date: game.date,
            round: game.round
        )
        switch content {
        case .single(let text):
            Text(text)
                .font(
                    .system(
                        size: glyphWidth * (7.0 / 30.0),
                        weight: .semibold,
                        design: .monospaced
                    )
                )
                .lineLimit(1)
            // Unbounded values shrink rather than clip: a clipped number is a *wrong* number.
                .minimumScaleFactor(0.6)
        case .stacked(let top, let bottom):
            VStack(spacing: 0) {
                Text(top)
                    .font(
                        .system(
                            size: glyphWidth * (4.0 / 30.0),
                            weight: .semibold,
                            design: .monospaced
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(bottom)
                    .font(
                        .system(
                            size: glyphWidth * (8.0 / 30.0),
                            weight: .semibold,
                            design: .monospaced
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }
}

// MARK: Previews
private func sampleGame(
    white: String = "Carlsen",
    black: String = "Nepomniachtchi",
    result: GameResult = .whiteWins,
    name: String? = nil,
    index: Int? = 101,
    date: Date? = nil,
    round: Int? = nil
) -> PGN {
    let pgn = PGN(
        event: "World Championship",
        site: "Dubai",
        white: white,
        black: black,
        name: name,
        result: result
    )
    pgn.libraryIndex = index
    pgn.date = date
    pgn.round = round
    return pgn
}

/// Ordinal widths - what varies is what the card shows; the placeholder is a state, not a width,
/// and lives in the next preview.
#Preview("Ordinal Widths") {
    HStack(spacing: 12) {
        ForEach([1, 101, 1024, 12345], id: \.self) { index in
            LibraryGameCardView(
                game: sampleGame(index: index),
                isSelected: false,
                onSelect: {},
                onOpen: {}
            )
        }
    }
    .padding()
    .frame(width: 720, height: 200)
    .modelContainer(for: PGN.self, inMemory: true)
}

/// All four inscriptions side by side, then the two absent-value fallbacks - the stacked date
/// form's proportions (month 4/30 over day 8/30 in a 42/60 slot) are a visual claim only a
/// canvas can check, and the draw card witnesses the compact "½-½" fitting without the shrink
/// floor. The undated and unrounded cards must read the same dash the unnumbered card does.
#Preview("Inscriptions") {
    let dated = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 23))
    return VStack(spacing: 12) {
        HStack(spacing: 12) {
            LibraryGameCardView(
                game: sampleGame(date: dated, round: 7),
                inscription: .index,
                isSelected: false, onSelect: {}, onOpen: {}
            )
            LibraryGameCardView(
                game: sampleGame(result: .draw, date: dated, round: 7),
                inscription: .result,
                isSelected: false, onSelect: {}, onOpen: {}
            )
            LibraryGameCardView(
                game: sampleGame(date: dated, round: 7),
                inscription: .date,
                isSelected: false, onSelect: {}, onOpen: {}
            )
            LibraryGameCardView(
                game: sampleGame(date: dated, round: 7),
                inscription: .round,
                isSelected: false, onSelect: {}, onOpen: {}
            )
        }
        HStack(spacing: 12) {
            LibraryGameCardView(
                game: sampleGame(),
                inscription: .date,
                isSelected: false, onSelect: {}, onOpen: {}
            )
            LibraryGameCardView(
                game: sampleGame(),
                inscription: .round,
                isSelected: true, onSelect: {}, onOpen: {}
            )
        }
    }
    .padding()
    .frame(width: 720, height: 420)
    .modelContainer(for: PGN.self, inMemory: true)
}

/// The unnumbered card, previewed **because** it is meant to be unreachable - the branch with
/// no fixture of its own.
#Preview("No Ordinal") {
    HStack(spacing: 12) {
        LibraryGameCardView(
            game: sampleGame(index: nil),
            isSelected: false,
            onSelect: {},
            onOpen: {}
        )
        LibraryGameCardView(
            game: sampleGame(index: nil),
            isSelected: true,
            onSelect: {},
            onOpen: {}
        )
    }
    .padding()
    .frame(width: 360, height: 200)
    .modelContainer(for: PGN.self, inMemory: true)
}

/// The badge's card-level witness: all three states over both selection tints; the spin only a
/// canvas can answer.
#Preview("Selection States") {
    HStack(spacing: 12) {
        LibraryGameCardView(
            game: sampleGame(),
            analysisState: .unanalyzed,
            isSelected: false,
            onSelect: {},
            onOpen: {}
        )
        LibraryGameCardView(
            game: sampleGame(),
            analysisState: .analyzed,
            isSelected: true,
            onSelect: {},
            onOpen: {}
        )
        LibraryGameCardView(
            game: sampleGame(),
            analysisState: .analyzing,
            isSelected: false,
            onSelect: {},
            onOpen: {}
        )
    }
    .padding()
    .frame(width: 540, height: 200)
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Custom Name") {
    HStack(spacing: 12) {
        LibraryGameCardView(
            game: sampleGame(
                white: "Fischer",
                black: "Spassky",
                name: "Game of the Century But With a Longer Text"
            ),
            isSelected: true,
            onSelect: {},
            onOpen: {}
        )
        LibraryGameCardView(
            game: sampleGame(
                white: "Fischer",
                black: "Spassky",
                name: "Game of the Century"
            ),
            isSelected: true,
            onSelect: {},
            onOpen: {}
        )
    }
    .padding()
    .frame(width: 360, height: 200)
    .modelContainer(for: PGN.self, inMemory: true)
}
