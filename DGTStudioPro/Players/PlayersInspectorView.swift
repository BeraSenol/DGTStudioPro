//
//  PlayersInspectorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import SwiftUI

// MARK: - Players Inspector View
internal struct PlayersInspectorView: View {

    // MARK: - Body
    internal var body: some View {
        List {
            Section {
                Text("No player selected")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Player Profile")
            }
        }
        .listStyle(.sidebar)
    }
}

#Preview {
    PlayersInspectorView()
        .frame(width: 300, height: 400)
}