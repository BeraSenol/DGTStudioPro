//
//  SettingsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 13/04/2026.
//

import SwiftUI

// MARK: Settings View
internal struct SettingsView: View {
    
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
        .frame(width: 450, height: 300)
    }
    
    // MARK: Instance Methods
    private var generalTab: some View {
        Form {
            Text("General settings will go here.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    private var boardTab: some View {
        Form {
            Text("Board style and appearance settings will go here.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
