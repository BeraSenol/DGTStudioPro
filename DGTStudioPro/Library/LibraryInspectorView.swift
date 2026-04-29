//
//  LibraryInspectorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import SwiftUI

internal struct LibraryInspectorView: View {
    
    // MARK: Stored Properties
    internal let pgn: PGN?
    
    // MARK: Initializers
    internal init(pgn: PGN? = nil) {
        self.pgn = pgn
    }
    
    // MARK: Body
    internal var body: some View {
        List {
            if let pgn {
                LoadedSection(pgn: pgn)
            } else {
                emptySection
            }
        }
        .listStyle(.sidebar)
    }
    
    // MARK: Instance Methods
    private var emptySection: some View {
        Section {
            Text("No game selected")
                .foregroundStyle(.secondary)
        } header: {
            Text("Game Details")
        }
    }
}

private struct LoadedSection: View {
    
    // MARK: Stored Properties
    @Bindable var pgn: PGN
    
    // MARK: Private Properties
    @FocusState private var isNameFieldFocused: Bool
    @State private var isEditingName: Bool = false
    @State private var draftName: String = ""
    
    // MARK: Body
    var body: some View {
        Section {
            nameRow
            LabeledContent("Event",  value: pgn.event)
            LabeledContent("Site",   value: pgn.site)
            LabeledContent("Date",   value: pgn.displayDate)
            LabeledContent("Round",  value: pgn.displayRound)
            LabeledContent("White",  value: pgn.white)
            LabeledContent("Black",  value: pgn.black)
            LabeledContent("Result", value: pgn.result.rawValue)
        } header: {
            Text("Game Details")
        }
    }
    
    // MARK: Instance Methods
    @ViewBuilder
    private var nameRow: some View {
        if isEditingName {
            HStack(spacing: 6) {
                TextField("Name", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFieldFocused)
                    .onSubmit { commitEdit() }
                Button("Done") { commitEdit() }
                    .buttonStyle(.borderless)
            }
        } else {
            HStack(spacing: 6) {
                Text(pgn.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button {
                    beginEdit()
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Rename")
            }
        }
    }
    
    private func beginEdit() {
        draftName = pgn.name
        isEditingName = true
        isNameFieldFocused = true
    }
    
    private func commitEdit() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            pgn.name = trimmed
        }
        isEditingName = false
    }
}

// MARK: Previews
#Preview("With Game") {
    LibraryInspectorView(
        pgn: PGN(
            event: "World Championship",
            site: "Dubai",
            round: 7,
            white: "Carlsen",
            black: "Nepomniachtchi",
            result: .ongoing
        )
    )
    .frame(width: 300, height: 500)
}

#Preview("Custom Name") {
    LibraryInspectorView(
        pgn: PGN(
            event: "World Championship",
            site: "Reykjavik",
            round: 6,
            white: "Fischer",
            black: "Spassky",
            name: "Game of the Century",
            result: .whiteWins
        )
    )
    .frame(width: 300, height: 500)
}

#Preview("Empty") {
    LibraryInspectorView()
        .frame(width: 300, height: 400)
}
