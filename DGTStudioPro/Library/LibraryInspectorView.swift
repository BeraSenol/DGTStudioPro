//
//  LibraryInspectorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import SwiftUI

internal struct LibraryInspectorView: View {

    // MARK: Body
    internal var body: some View {
        List {
            Section {
                Text("No game selected")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Game Details")
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: Previews
#Preview {
    LibraryInspectorView()
        .frame(width: 300, height: 400)
}
