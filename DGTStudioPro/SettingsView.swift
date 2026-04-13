//
//  SettingsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 13/04/2026.
//

import SwiftUI

// MARK: Settings View
internal struct SettingsView: View {
    
    // MARK: Private Properties
    @AppStorage("boardStyle") private var boardStyle: BoardStyle = .walnut
    
    // MARK: Body
    internal var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                generalTab
            }
            
            Tab("Board", systemImage: "checkerboard.rectangle") {
                boardTab
            }
        }
        .frame(width: 450, height: 300)
    }
    
    // MARK: Instance Methods
    private var generalTab: some View {
        Form {
            Text("General settings will go here.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    private var boardTab: some View {
        Form {
            LabeledContent("Board Style") {
                HStack(spacing: 12) {
                    ForEach(BoardStyle.allCases, id: \.self) { style in
                        boardStyleButton(style)
                    }
                }
            }
        }
        .padding()
    }
    
    private func boardStyleButton(_ style: BoardStyle) -> some View {
        Button {
            boardStyle = style
        } label: {
            VStack(spacing: 6) {
                boardPreview(for: style)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                boardStyle == style ? Color.accentColor : .secondary.opacity(0.3),
                                lineWidth: boardStyle == style ? 2 : 1
                            )
                    )
                
                Text(style.displayName)
                    .font(.caption)
                    .foregroundStyle(boardStyle == style ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func boardPreview(for style: BoardStyle) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle().fill(style.light)
                Rectangle().fill(style.dark)
            }
            HStack(spacing: 0) {
                Rectangle().fill(style.dark)
                Rectangle().fill(style.light)
            }
        }
    }
}

#Preview {
    SettingsView()
}
