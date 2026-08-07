import SwiftUI
import SwiftData

internal struct LibraryGameCardView: View {
    
    // MARK: Stored Properties
    let game: PGN

    /// The document sheet's width.
    ///
    /// **A parameter rather than an environment read**, so the gallery
    /// filmstrip can keep its own size while the icons grid follows the View
    /// Options slider — two hosts, two answers, and neither has to know about
    /// the other's. It is also what keeps both previews and the gallery free
    /// of a `CollectionViewOptions` they have no other use for.
    ///
    /// `var`, unlike every `let` around it, and not by accident: a `let` with
    /// an initial value is excluded from the memberwise init entirely, so the
    /// default would be unreachable and all six call sites would have to state
    /// 60 by hand — which is the constant-in-six-places shape this default
    /// exists to prevent. The value is the pre-slider width, so a host that
    /// passes nothing renders exactly as before.
    var glyphWidth: CGFloat = 60

    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onAnalyze: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void
    
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
        // Selection is a `simultaneousGesture`, not a second `onTapGesture`,
        // so it can never be the *loser* in gesture disambiguation. Two
        // sequential taps made SwiftUI hold the single click for the full
        // double-click interval before it could rule out a second — and that
        // is not what AppKit does: `NSTableView` and Finder select on
        // mouse-down and only the open action waits. Simultaneous recognition
        // restores that shape; `onOpen` still fires on the second click.
        //
        // Consequence: a double-click runs `onSelect` first (and possibly
        // again on the second tap). Every call site assigns
        // `selectedPGNs = [game.id]`, so it is idempotent by construction —
        // and select-then-open is Finder's order anyway.
        .onTapGesture(count: 2, perform: onOpen)
        .simultaneousGesture(TapGesture().onEnded { onSelect() })
        // The card's closures are argument-free — it draws one game and its
        // hosts already close over it — so the adaptation drops the payload
        // rather than building one.
        //
        // Item *order* now comes from `GameActionsMenu` and no longer from
        // here. This host had been reordered by hand (Get Info raised, Open
        // lowered) while the other two kept Open first, which is the same
        // divergence in a new place: changing the order in one menu changed
        // one view mode. It is one line in the shared type now.
        .contextMenu {
            GameActionsMenu(
                games: [game],
                onOpen: { _ in onOpen() },
                onAnalyze: { _ in onAnalyze() },
                onExport: { _ in onExport() },
                onDelete: { _ in onDelete() }
            )
        }
        // Collapse the card into a single addressable element for UI
        // tests. Without `.combine`, macOS exposes only the inner static
        // texts and the identifier never lands on a tappable element.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.gameCard(game.name))
    }
    
    // MARK: Instance Methods
    private var documentIcon: some View {
        ZStack {
            // `doc.fill`, not `doc` (7 Aug 2026). The outline carried the
            // result in white-on-nothing; a filled sheet is paper, and the
            // ordinal is written on it. `.fontWeight(.ultraLight)` went with
            // the outline rather than being kept — it thinned strokes that no
            // longer exist, so leaving it would have been a modifier
            // describing the symbol this line replaced.
            Image(systemName: "doc.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white)
                .frame(width: glyphWidth)
            // Rigid, not merely width-pinned (4 Aug 2026): a resizable
            // image under `fit` was the one compressible element in this
            // card, so a short host — the gallery filmstrip — squeezed
            // the glyph to roughly half height while the icons grid
            // showed it full size. Ideal height now follows the 80 pt
            // width whatever the proposal, which is what
            // `PlayerMonogram`'s rigid frame always did for the Players
            // card. Hosts size themselves to the card, never the
            // reverse — see the gallery strip's height.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 6)

            // `.black`, and it is not a theme colour that forgot to be
            // semantic. The sheet above is explicitly `.white`, so this is ink
            // on that paper — the pair has to be stated together or a Light
            // Mode reader gets white on white. If the sheet ever becomes
            // `.tint` or a material, this line moves with it.
            // Every number here is a *ratio* of the sheet, taken from the
            // pre-slider pair so the default renders byte-identically: 14/60
            // for the type, 42/60 for the label's bound, and the offsets that
            // centre it in the sheet's body rather than in its bounding box —
            // a `doc` glyph's fold sits top-trailing, so the visual centre is
            // low and leading of the geometric one. Stated as fractions
            // because a slider that scaled the paper and not the writing on it
            // would look like a rendering bug at both ends of the range.
            Text(displayIndex)
                .font(
                    .system(
                        size: glyphWidth * (14.0 / 60.0),
                        weight: .semibold,
                        design: .monospaced
                    )
                )
                .foregroundStyle(.black)
                .lineLimit(1)
            // The old result was three characters forever, so it needed no
            // bound. An ordinal is unbounded — the folder decides — and a
            // five-digit game would render past the sheet's edge with nothing
            // to stop it. Shrink rather than clip, because a clipped number is
            // a *wrong* number and a small one is only a small one.
                .minimumScaleFactor(0.6)
                .frame(maxWidth: glyphWidth * (42.0 / 60.0))
                .offset(x: glyphWidth * (2.0 / 60.0), y: glyphWidth * (4.0 / 60.0))
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.secondary.opacity(isSelected ? 0.15 : 0))
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
    
    /// The ordinal the game's file carried (D58′), written on the sheet.
    ///
    /// **The em dash is a rendering of a state that is meant to be
    /// unreachable, and it is deliberately not a fourth vocabulary.** The
    /// intent is that every game has an ordinal; three doors currently produce
    /// nil anyway — a paste-imported game, a file whose name carries no
    /// `<digits>.` run, and `PGNStore.archive`, whose `flatMap` hands the
    /// *first* game archived into an empty Library no ordinal at all. Until
    /// those close, this renders what the `#` column and Get Info's File tab
    /// already render for the same value (D55′'s house glyph), so one state
    /// has one mark across three surfaces rather than a card that reads as
    /// broken.
    ///
    /// `displayResult(_:)` was deleted here — the sheet carried `1-0` / `0-1`
    /// / `1/2` / `*` until 7 Aug 2026. The result is not gone from the
    /// destination: it is a sortable table column and a Get Info field. What
    /// it stopped being is the thing a card is identified by.
    ///
    /// **The `#` prefix went 7 Aug 2026, by request**, and the card was the only
    /// surface carrying one: the table's `#` column and Get Info's File tab both
    /// render the bare number, because the *column header* is where the sigil
    /// belongs and a cell that repeats its own header is saying it twice. A card
    /// has no header, so the argument for a prefix here was that the number
    /// would otherwise be unlabelled — but it is written on a document glyph, at
    /// a size that reads as a filing mark, and nothing else numeric appears on
    /// the sheet for it to be confused with. This is now the same spelling as
    /// `LibraryListView`'s cell, deliberately.
    private var displayIndex: String {
        game.libraryIndex.map(String.init) ?? RosterSummary.displayUnknown
    }
}

// MARK: Previews
private func sampleGame(
    white: String = "Carlsen",
    black: String = "Nepomniachtchi",
    result: GameResult = .whiteWins,
    name: String? = nil,
    index: Int? = 101
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
    return pgn
}

/// **Was *All Results* until 7 Aug 2026, and the rename is the point.** It
/// rendered four cards differing only in a value the sheet no longer shows —
/// four identical cards, witnessing an arrangement the app had retired, which
/// reads as evidence that something is still checked. What varies now is what
/// the card actually varies by.
///
/// The four columns are the widths that decide whether this fits: one digit,
/// the three the old result occupied, four, and the five-digit case that is
/// the only reason `minimumScaleFactor` is on the label. The em dash is in the
/// *next* preview rather than here — it is a state, not a width.
#Preview("Ordinal Widths") {
    HStack(spacing: 12) {
        ForEach([1, 101, 1024, 12345], id: \.self) { index in
            LibraryGameCardView(
                game: sampleGame(index: index),
                isSelected: false,
                onSelect: {},
                onOpen: {},
                onAnalyze: {},
                onExport: {},
                onDelete: {}
            )
        }
    }
    .padding()
    .frame(width: 720)
    .modelContainer(for: PGN.self, inMemory: true)
}

/// The unnumbered card, previewed **because** it is meant to be unreachable.
///
/// Three doors produce a nil ordinal today (see `displayIndex`), so this is
/// the branch a reader hits by accident and the one with no fixture of its
/// own. A branch nobody has rendered has layout nobody has checked — the
/// lesson the galleries' empty-selection arm cost on 4 Aug, applied at minting
/// rather than after the first production render.
#Preview("No Ordinal") {
    HStack(spacing: 12) {
        LibraryGameCardView(
            game: sampleGame(index: nil),
            isSelected: false,
            onSelect: {},
            onOpen: {},
            onAnalyze: {},
            onExport: {},
            onDelete: {}
        )
        LibraryGameCardView(
            game: sampleGame(index: nil),
            isSelected: true,
            onSelect: {},
            onOpen: {},
            onAnalyze: {},
            onExport: {},
            onDelete: {}
        )
    }
    .padding()
    .frame(width: 360)
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Selection States") {
    HStack(spacing: 12) {
        LibraryGameCardView(
            game: sampleGame(),
            isSelected: false,
            onSelect: {},
            onOpen: {},
            onAnalyze: {},
            onExport: {},
            onDelete: {}
        )
        LibraryGameCardView(
            game: sampleGame(),
            isSelected: true,
            onSelect: {},
            onOpen: {},
            onAnalyze: {},
            onExport: {},
            onDelete: {}
        )
    }
    .padding()
    .frame(width: 360)
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
            onOpen: {},
            onAnalyze: {},
            onExport: {},
            onDelete: {}
        )
        LibraryGameCardView(
            game: sampleGame(
                white: "Fischer",
                black: "Spassky",
                name: "Game of the Century"
            ),
            isSelected: true,
            onSelect: {},
            onOpen: {},
            onAnalyze: {},
            onExport: {},
            onDelete: {}
        )
    }
    .padding()
    .frame(width: 360)
    .modelContainer(for: PGN.self, inMemory: true)
}
