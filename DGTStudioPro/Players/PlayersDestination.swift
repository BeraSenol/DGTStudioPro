//
//  PlayersDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import SwiftUI

internal struct PlayersDestination: View {

    // MARK: Private Properties
    @State private var isInspectorPresented: Bool = false

    // MARK: Body
    internal var body: some View {
        ContentUnavailableView(
            "Players",
            systemImage: "person.2",
            description: Text("Player profiles coming soon.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .inspector(isPresented: $isInspectorPresented) {
            PlayersInspectorView()
                .inspectorColumnWidth(min: 260, ideal: 320, max: 400)
        }
        .inspectorToggle(isPresented: $isInspectorPresented)
    }
}
