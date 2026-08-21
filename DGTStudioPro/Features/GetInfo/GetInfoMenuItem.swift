import SwiftUI

// MARK: Menu Item

/// The Get Info menu item, everywhere it appears - one type so the label, symbol and key
/// cannot drift across hosts (a `Commands` scene can only *ask* a view to open the window).
struct GetInfoMenuItem: View {

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
    init(request: GetInfoRequest, identifier: String) {
        self.door = .opens(request)
        self.identifier = identifier
    }

    /// The menu-bar form: the item sets a flag the Board observes.
    init(requesting trigger: Binding<Bool>?, identifier: String) {
        self.door = .requests(trigger)
        self.identifier = identifier
    }

    // MARK: Body
    var body: some View {
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
