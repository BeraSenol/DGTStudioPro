//
//  Inspector+Toolbar.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 29/04/2026.
//

import SwiftUI

internal struct InspectorToggleModifier: ViewModifier {
    @Binding var isPresented: Bool
    var identifier: String = "inspector.toggle"

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem {
                Button {
                    isPresented.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .accessibilityIdentifier(identifier)
            }
        }
    }
}

extension View {
    internal func inspectorToggle(
        isPresented: Binding<Bool>,
        identifier: String = "inspector.toggle"
    ) -> some View {
        modifier(InspectorToggleModifier(isPresented: isPresented, identifier: identifier))
    }
}
