import SwiftUI

// MARK: - Menu Item

/// The Get Info menu item, everywhere it appears.
///
/// **One type rather than a line per context menu** — D26′'s argument applied
/// to a verb instead of a glyph. A hand-written item in each of the six context
/// menus is six chances to disagree about label, symbol, shortcut, or — worst
/// and least visible — which subject the request names.
///
/// It owns `openWindow` rather than taking a closure, the arrangement
/// `PlayersInspectorView` and `PlayersColumnsView` already use for the
/// game-window route.
///
/// Two doors because a `Commands` scene has no `openWindow`: the menu-bar item
/// can only *ask* a view to open one (`SmartTagCommands`' trigger-binding
/// shape). ⌘I is attached here so the shortcut travels with the item.
internal struct GetInfoMenuItem: View {

    // MARK: Door

    /// How this item reaches the window. Not a public distinction: callers
    /// pick an initializer and never name this.
    private enum Door {
        /// A view that can open the window itself.
        case opens(GetInfoRequest)
        /// A command menu that must ask one to. Nil means no front-tab
        /// subject, which is the item's own disabled condition.
        case requests(Binding<Bool>?)
    }

    // MARK: Stored Properties
    private let door: Door
    private let identifier: String

    // MARK: Private Properties
    @Environment(\.openWindow) private var openWindow

    // MARK: Initializers

    /// The context-menu form: this item owns the window route.
    internal init(request: GetInfoRequest, identifier: String) {
        self.door = .opens(request)
        self.identifier = identifier
    }

    /// The menu-bar form: the item sets a flag the Board observes.
    internal init(requesting trigger: Binding<Bool>?, identifier: String) {
        self.door = .requests(trigger)
        self.identifier = identifier
    }

    // MARK: Body
    internal var body: some View {
        Button {
            switch door {
            case .opens(let request):   openWindow(value: request)
            case .requests(let trigger): trigger?.wrappedValue = true
            }
        } label: {
            Label("Get Info", systemImage: "info.circle")
        }
        .keyboardShortcut("i", modifiers: .command)
        .disabled(isDisabled)
        .accessibilityIdentifier(identifier)
    }

    /// Only the menu-bar form can be disabled: a context menu is raised *from*
    /// the row it describes, so its subject exists by construction.
    private var isDisabled: Bool {
        if case .requests(let trigger) = door { return trigger == nil }
        return false
    }
}
