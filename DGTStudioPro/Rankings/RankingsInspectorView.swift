//
//  RankingsInspectorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import SwiftUI

// MARK: - Rankings Inspector View
internal struct RankingsInspectorView: View {

    // MARK: - Body
    internal var body: some View {
        List {
            Section {
                Text("No rankings loaded")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Rankings")
            }
        }
        .listStyle(.sidebar)
    }
}

#Preview {
    RankingsInspectorView()
        .frame(width: 300, height: 400)
}