//
//  LibraryGameCard.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 29/04/2026.
//

import SwiftUI

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
