//
//  SettingsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 13/04/2026.
//

import SwiftUI

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
        .frame(width: 500)
    }

    // MARK: Instance Methods
    private var generalTab: some View {
        Form {
            LabeledContent("Analysis Depth") {
                Text("20")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Hash Size") {
                Text("128 MB")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Threads") {
                Text("1")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var boardTab: some View {
        VStack(spacing: 0) {
            Text("Style")

            HStack(spacing: 20) {
                ForEach(BoardStyle.allCases, id: \.self) { style in
                    boardStyleButton(style)
                }
            }
            .padding()

            Spacer()
        }
    }

    private func boardStyleButton(_ style: BoardStyle) -> some View {
        let isSelected = boardStyle == style

        return Button {
            boardStyle = style
        } label: {
            VStack {
                boardThumbnail(for: style)
                    .frame(width: 60, height: 60)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor : .secondary.opacity(0.25),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )

                Text(style.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func boardThumbnail(for style: BoardStyle) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(style.dark)

            VStack(spacing: 0) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<2, id: \.self) { col in
                            let radius: CGFloat = 4
                            Rectangle()
                                .fill(
                                    (row + col).isMultiple(of: 2) ? style.light : style.dark
                                )
                                .clipShape(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius:     row == 0 && col == 0 ? radius : 0,
                                        bottomLeadingRadius:  row == 1 && col == 0 ? radius : 0,
                                        bottomTrailingRadius: row == 1 && col == 1 ? radius : 0,
                                        topTrailingRadius:    row == 0 && col == 1 ? radius : 0
                                    )
                                )
                        }
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
