//
//  PlayersDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import SwiftUI

internal struct PlayersDestination: View {

    // MARK: Tab State (lives on enclosing `ContentView`)
    @Bindable internal var tabState: TabState

    // MARK: Body
    internal var body: some View {
        ContentUnavailableView(
            "Players",
            systemImage: "person.2",
            description: Text("Player profiles coming soon.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("players.content")
        .navigationTitle("Players")
        .inspector(isPresented: $tabState.playersInspectorPresented) {
            PlayersInspectorView()
                .inspectorColumnWidth(min: 260, ideal: 320, max: 400)
        }
        .inspectorToggle(
            isPresented: $tabState.playersInspectorPresented,
            identifier: "players.inspectorToggle"
        )
    }
}

// MARK: - Previews

#Preview {
    PlayersDestination(tabState: TabState())
}
