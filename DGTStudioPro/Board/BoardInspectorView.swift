//
//  BoardInspectorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/04/2026.
//

import SwiftUI

// MARK: - Board Inspector View
internal struct BoardInspectorView: View {

    // MARK: - Body
    internal var body: some View {
        List {
            metadataSection
            Divider()
            Spacer()
        }
        .listStyle(.sidebar)
    }

    // MARK: - Instance Methods
    private var metadataSection: some View {
        Section {
            LabeledContent("White", value: "—")
            LabeledContent("Black", value: "—")
            LabeledContent("Event", value: "—")
            LabeledContent("Date", value: "—")
            LabeledContent("Result", value: "*")
        } header: {
            Text("Game")
        } footer: {
            Text("Connect a DGT board to begin.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

    }
}

#Preview {
    BoardInspectorView()
        .frame(width: 300, height: 400)
}
