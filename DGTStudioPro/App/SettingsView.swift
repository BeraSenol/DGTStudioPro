//
//  SettingsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 13/04/2026.
//

import SwiftUI

internal struct SettingsView: View {

    // MARK: Private Properties
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut

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
        .frame(width: 500)
    }

    // MARK: Instance Methods
    private var generalTab: some View {
        Form {
            LabeledContent("Analysis Depth", value: "20")
            LabeledContent("Hash Size", value: "128 MB")
            LabeledContent("Threads", value: "1")
        }
        .formStyle(.grouped)
    }

    private var boardTab: some View {
        VStack {
            Text("Style")
            HStack(spacing: 20) {
                ForEach(BoardStyle.allCases, id: \.self, content: boardStyleButton)
            }
            .padding()
            Spacer()
        }
    }

    private func boardStyleButton(_ style: BoardStyle) -> some View {
        let isSelected = boardStyle == style
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)

        return Button {
            boardStyle = style
        } label: {
            VStack {
                boardThumbnail(for: style)
                    .frame(width: 60, height: 60)
                    .clipShape(shape)
                    .overlay {
                        shape.strokeBorder(
                            isSelected ? Color.accentColor : .secondary.opacity(0.25),
                            lineWidth: isSelected ? 2 : 1
                        )
                    }

                Text(style.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func boardThumbnail(for style: BoardStyle) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { col in
                        Rectangle()
                            .fill((row + col).isMultiple(of: 2) ? style.light : style.dark)
                    }
                }
            }
        }
    }
}

// MARK: Previews
#Preview {
    SettingsView()
}
