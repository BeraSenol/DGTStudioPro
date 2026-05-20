//
//  TabBarView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/05/2026.
//

import SwiftUI

/// Horizontal strip of open tabs, shown above the board when at least
/// one game is open. Active tab is accented; the close button reveals on
/// hover or when active.
///
/// Sized at ~36 points tall; chips truncate long display names to 200
/// points wide with middle-truncation so both ends of an event title
/// remain visible.
internal struct TabBarView: View {
    
    // MARK: Stored Properties
    
    internal let tabs: [GameTab]
    internal let activeTabID: GameTab.ID?
    internal let onActivate: (GameTab.ID) -> Void
    internal let onClose: (GameTab.ID) -> Void
    
    // MARK: Body
    
    internal var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tabs) { tab in
                    TabChip(
                        title: tab.displayName,
                        isActive: tab.id == activeTabID,
                        onActivate: { onActivate(tab.id) },
                        onClose:    { onClose(tab.id) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}

// MARK: - Tab Chip

private struct TabChip: View {
    
    let title: String
    let isActive: Bool
    let onActivate: () -> Void
    let onClose: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 200, alignment: .leading)
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .opacity(isActive || isHovered ? 1 : 0)
            .help("Close tab")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActive ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(
                    isActive ? Color.accentColor.opacity(0.45) : Color.clear,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onActivate)
        .onHover { isHovered = $0 }
    }
}
