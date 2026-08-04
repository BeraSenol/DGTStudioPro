//
//  LibraryGameCardView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 29/04/2026.
//

import SwiftUI
import SwiftData

internal struct LibraryGameCardView: View {
    
    // MARK: Stored Properties
    let game: PGN
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
            Image(systemName: "doc")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white)
                .frame(width: 60)
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
                .fontWeight(.ultraLight)
                .padding(.leading, 6)
            
            Text(displayResult(game.result))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .tracking(game.result == .draw ? 2 : 1)
                .offset(x: 2, y: 4)
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
    
    private func displayResult(_ result: GameResult) -> String {
        switch result {
        case .whiteWins: return "1-0"
        case .blackWins: return "0-1"
        case .draw:      return "1/2"
        case .ongoing:   return "*"
        }
    }
}

// MARK: Previews
private func sampleGame(
    white: String = "Carlsen",
    black: String = "Nepomniachtchi",
    result: GameResult = .whiteWins,
    name: String? = nil
) -> PGN {
    PGN(
        event: "World Championship",
        site: "Dubai",
        white: white,
        black: black,
        name: name,
        result: result
    )
}

#Preview("All Results") {
    HStack(spacing: 12) {
        LibraryGameCardView(
            game: sampleGame(result: .whiteWins),
            isSelected: false,
            onSelect: {},
            onOpen: {},
            onAnalyze: {},
            onExport: {},
            onDelete: {}
        )
        LibraryGameCardView(
            game: sampleGame(result: .blackWins),
            isSelected: false,
            onSelect: {},
            onOpen: {},
            onAnalyze: {},
            onExport: {},
            onDelete: {}
        )
        LibraryGameCardView(
            game: sampleGame(result: .draw),
            isSelected: false,
            onSelect: {},
            onOpen: {},
            onAnalyze: {},
            onExport: {},
            onDelete: {}
        )
        LibraryGameCardView(
            game: sampleGame(result: .ongoing),
            isSelected: false,
            onSelect: {},
            onOpen: {},
            onAnalyze: {},
            onExport: {},
            onDelete: {}
        )
    }
    .padding()
    .frame(width: 720)
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
