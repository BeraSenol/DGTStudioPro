//
//  LibraryInspectorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import SwiftUI

internal struct LibraryInspectorView: View {
    internal let pgn: PGN?

    internal init(pgn: PGN? = nil) {
        self.pgn = pgn
    }

    internal var body: some View {
        List {
            if let pgn {
                loadedSection(pgn: pgn)
            } else {
                emptySection
            }
        }
        .listStyle(.sidebar)
    }

    private var emptySection: some View {
        Section {
            Text("No game selected")
                .foregroundStyle(.secondary)
        } header: {
            Text("Game Details")
        }
    }

    private func loadedSection(pgn: PGN) -> some View {
        Section {
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
    .frame(width: 300, height: 400)
}

#Preview {
    LibraryInspectorView()
        .frame(width: 300, height: 400)
}
