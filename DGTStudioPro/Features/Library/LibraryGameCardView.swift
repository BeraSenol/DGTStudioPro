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
        // Selection is a `simultaneousGesture`, not a second `onTapGesture`: two sequential taps made
        // SwiftUI hold the single click for the full double-click interval. Finder selects on
        // mouse-down; only open waits.
        .onTapGesture(count: 2, perform: onOpen)
        .simultaneousGesture(TapGesture().onEnded { onSelect() })
        // The card's closures are argument-free - it draws one game its hosts close over. Item order
        // comes from `GameActionsMenu`, no longer from here.
        .contextMenu {
            GameActionsMenu(
                games: [game],
                onOpen: { _ in onOpen() },
                onAnalyze: { _ in onAnalyze() },
                onExport: { _ in onExport() },
                onDelete: { _ in onDelete() }
            )
        }
        // Collapse into one addressable element - without `.combine`, macOS exposes only the inner
        // static texts and the identifier never lands on a tappable element.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.gameCard(game.name))
    }
    
    // MARK: Instance Methods
    private var documentIcon: some View {
        ZStack {
            // `doc.fill`, not `doc`: a filled sheet is paper, and the ordinal is written on it.
            Image(systemName: "doc.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white)
                .frame(width: glyphWidth)
            // Rigid, not merely width-pinned: a resizable image under `fit` was the card's one compressible
            // element - the filmstrip squeezed the glyph to half height.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 6)
            
            // `.black` is ink on the explicitly-`.white` sheet - the pair must be stated together or Light
            // Mode gets white on white. 14/60 is the pre-slider pair, so the default renders byte-identically.
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
            // An ordinal is unbounded - shrink rather than clip: a clipped number is a *wrong* number.
                .minimumScaleFactor(0.6)
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
    
    /// The file's ordinal, written on the sheet. The placeholder glyph renders a state that is meant
    /// to be unreachable - not a fourth vocabulary. The `#` prefix and the result went 7 Aug 2026
    /// by request; the result still lives in the list's cell.
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

/// Ordinal widths - what varies is what the card shows; the placeholder is a state, not a width,
/// and lives in the next preview.
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

/// The unnumbered card, previewed **because** it is meant to be unreachable - the branch with
/// no fixture of its own.
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

/// The badge's card-level witness: all three states over both selection tints; the spin only a
/// canvas can answer.
#Preview("Selection States") {
    HStack(spacing: 12) {
        LibraryGameCardView(
            game: sampleGame(),
            analysisState: .unanalyzed,
            isSelected: false,
            onSelect: {},
            onOpen: {},
            onAnalyze: {},
            onExport: {},
            onDelete: {}
        )
        LibraryGameCardView(
            game: sampleGame(),
            analysisState: .analyzed,
            isSelected: true,
            onSelect: {},
            onOpen: {},
            onAnalyze: {},
            onExport: {},
            onDelete: {}
        )
        LibraryGameCardView(
            game: sampleGame(),
            analysisState: .analyzing,
            isSelected: false,
            onSelect: {},
            onOpen: {},
            onAnalyze: {},
            onExport: {},
            onDelete: {}
        )
    }
    .padding()
    .frame(width: 540)
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
