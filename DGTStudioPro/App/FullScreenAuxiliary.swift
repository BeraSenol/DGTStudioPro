import AppKit
import SwiftUI

/// Why a companion window stops hijacking the full-screen space: SwiftUI gives every window
/// `.fullScreenPrimary`, and cannot reach the flag — AppKit, scoped per scene, never through
/// `NSApp.windows` (the main group must keep its primary flag).
internal enum FullScreenAuxiliary {

    /// The transform, extracted to be pinned. **Mutating, not assigning**: assignment would clear
    /// flags AppKit set when it built the window — an invisible loss no two-flag test catches.
    internal static func auxiliary(
        _ behavior: NSWindow.CollectionBehavior
    ) -> NSWindow.CollectionBehavior {
        var result = behavior
        result.remove(.fullScreenPrimary)
        result.insert(.fullScreenAuxiliary)
        return result
    }
}

extension View {

    /// Marks this scene's window as a companion: joins a full-screen space rather than claiming one.
    /// Applied to the companion scenes, never the main group.
    internal func fullScreenAuxiliary() -> some View {
        background(FullScreenAuxiliaryConfigurator())
    }
}

/// The app's one `NSWindow` reach. **`viewDidMoveToWindow`, not `onAppear`** — a view knows its
/// own window and is told exactly once; `NSApp.windows.last` is a guess.
private struct FullScreenAuxiliaryConfigurator: NSViewRepresentable {

    internal func makeNSView(context: Context) -> NSView { ConfiguringView() }

    /// Nothing to update: the behaviour is a window property, set once. If SwiftUI ever resets it,
    /// this grows a body — a measurement, not a precaution.
    internal func updateNSView(_ nsView: NSView, context: Context) { }

    private final class ConfiguringView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // Fires with a nil window on detach too — not our edge.
            guard let window else { return }
            window.collectionBehavior = FullScreenAuxiliary.auxiliary(
                window.collectionBehavior
            )
        }
    }
}
