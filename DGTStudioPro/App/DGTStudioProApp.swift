//
//  DGTStudioProApp.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/03/2026.
//

import SwiftUI
import SwiftData

@main
internal struct DGTStudioProApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: PGN.self)

        Settings {
            SettingsView()
        }
    }
}
