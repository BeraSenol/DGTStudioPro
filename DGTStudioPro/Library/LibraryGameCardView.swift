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
    let onDelete: () -> Void
    
    // MARK: Body
    var body: some View {
        VStack(spacing: 4) {
            documentIcon
            nameLabel
            Text(game.displayDate)
                .font(.caption)
                .foregroundStyle(.tint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: Instance Methods
    private var documentIcon: some View {
        ZStack {
            Image(systemName: "doc")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .fontWeight(.thin)
            
            Text(displayResult(game.result))
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .tracking(game.result == .draw ? 4 : 2)
                .offset(y: 4)
        }
        .padding(6)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.secondary.opacity(isSelected ? 0.15 : 0))
        }
    }
    
    @ViewBuilder
    private var nameLabel: some View {
        Text(game.name)
            .font(.callout)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isSelected ? Color.accentColor : .clear)
            )
            .foregroundStyle(isSelected ? Color.white : .primary)
    }
    
    private func displayResult(_ result: GameResult) -> String {
        switch result {
        case .whiteWins: return "1-0"
        case .blackWins: return "0-1"
        case .draw:      return "½-½"
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
            onDelete: {}
        )
        LibraryGameCardView(
            game: sampleGame(result: .blackWins),
            isSelected: false,
            onSelect: {},
            onDelete: {}
        )
        LibraryGameCardView(
            game: sampleGame(result: .draw),
            isSelected: false,
            onSelect: {},
            onDelete: {}
        )
        LibraryGameCardView(
            game: sampleGame(result: .ongoing),
            isSelected: false,
            onSelect: {},
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
            onDelete: {}
        )
        LibraryGameCardView(
            game: sampleGame(),
            isSelected: true,
            onSelect: {},
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
                name: "Game of the Century"
            ),
            isSelected: false,
            onSelect: {},
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
            onDelete: {}
        )
    }
    .padding()
    .frame(width: 360)
    .modelContainer(for: PGN.self, inMemory: true)
}
