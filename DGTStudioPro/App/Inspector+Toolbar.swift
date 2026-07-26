//
//  Inspector+Toolbar.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 29/04/2026.
//

import SwiftUI

/// The identifier is deliberately **required**, with no default: a shared
/// fallback would hand two destinations' toolbars the same identifier the
/// moment a host forgot to pass one, and a parameter default is invisible to
/// the registry's `grep accessibilityIdentifier("` enforcement (the
/// `board.connectButton` lesson, second occurrence). Required means forgetting
/// is a compile error.
internal struct InspectorToggleModifier: ViewModifier {
    @Binding var isPresented: Bool
    let identifier: String
    
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
        identifier: String
    ) -> some View {
        modifier(InspectorToggleModifier(isPresented: isPresented, identifier: identifier))
    }
}
