//
//  LibraryGameCard.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 29/04/2026.
//

import SwiftUI

internal struct LibraryGameCardView: View {
    let game: PGN
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                resultChip(game.result)
                Spacer()
                Text(game.displayDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(game.white)
                    .font(.callout)
                    .lineLimit(1)
                Text("vs")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(game.black)
                    .font(.callout)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 4)
            HStack(alignment: .bottom) {
                Text(game.event)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Text("#\(game.displayRound)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minWidth: 120, maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .padding(12)
        .libraryGameCard(
            isSelected: isSelected,
            onSelect: onSelect,
            onDelete: onDelete
        )
    }
}

internal struct LibraryGameCardModifier: ViewModifier {
    let isSelected: Bool
    let cornerRadius: CGFloat
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(.regularMaterial)
            .overlay {
                shape.strokeBorder(
                    isSelected ? Color.accentColor : .secondary.opacity(0.2),
                    lineWidth: isSelected ? 2 : 1
                )
            }
            .clipShape(shape)
            .contentShape(shape)
            .onTapGesture(perform: onSelect)
            .contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}

internal func resultChip(_ result: GameResult) -> some View {
    Text(result.rawValue)
        .font(.caption.monospaced())
        .tracking(1)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.tertiary)
        .foregroundStyle(.secondary)
        .clipShape(Capsule())
}

extension View {
    internal func libraryGameCard(
        isSelected: Bool,
        cornerRadius: CGFloat = 8,
        onSelect: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(LibraryGameCardModifier(
            isSelected: isSelected,
            cornerRadius: cornerRadius,
            onSelect: onSelect,
            onDelete: onDelete
        ))
    }
}
