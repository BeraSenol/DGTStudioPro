import AppKit
import SwiftUI

/// Why a companion window stops hijacking the full-screen space.
///
/// SwiftUI gives every `WindowGroup` window `.fullScreenPrimary` — "this
/// window is a candidate to *be* the full-screen window." Open one while a
/// sibling already owns a full-screen space and AppKit obliges: the graph, the
/// info window and the queue each arrive full-screen rather than at the
/// `.defaultSize` their scene declares. `.fullScreenAuxiliary` is the other
/// half of that pair — "this window may *join* someone else's full-screen
/// space as an ordinary window" — which is what a companion surface is.
///
/// **AppKit because SwiftUI cannot reach it.** As of macOS 26.2 / Xcode 26.x
/// there is no scene modifier for collection behaviour. `.windowLevel`,
/// `.windowResizability` and `.windowManagerRole` all exist and none of them
/// is this. Checked rather than assumed; if a `2027` SDK grows one, this file
/// is a deletion rather than a migration.
///
/// **Scoped per scene, never applied through `NSApp.windows`.** The main
/// `WindowGroup` must keep `.fullScreenPrimary` — it is the window that is
/// *supposed* to go full screen, and a sweep over every window would take it
/// with the others.
internal enum FullScreenAuxiliary {

    /// The transform, extracted from the view purely so it can be pinned.
    ///
    /// **Mutating rather than assigning is the whole content.** The obvious
    /// spelling is `behavior = [.fullScreenAuxiliary]`, which is one line and
    /// silently discards every other flag the window arrived with —
    /// `.managed`, `.participatesInCycle`, whatever the framework set when it
    /// built the window. Those are not ours to clear, the loss is invisible
    /// (a window that stops appearing in Mission Control looks like a Mission
    /// Control bug), and no test that only checks the two full-screen flags
    /// would notice. Hence a pure function over the option set, and a pin on
    /// the flags it must *not* touch.
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

    /// Marks this scene's window as a companion: it joins a full-screen space
    /// rather than claiming one.
    ///
    /// Applied to the three companion scenes (evaluation graph, Get Info,
    /// analysis queue) and deliberately not to the main `WindowGroup`.
    ///
    /// **Accepted cost, stated rather than discovered:** the green button on
    /// these windows becomes zoom rather than full-screen, because a window
    /// without `.fullScreenPrimary` has nothing to offer. That is the right
    /// trade for a 460 × 520 info panel and it is a visible change, so it is
    /// named here rather than left to be noticed.
    internal func fullScreenAuxiliary() -> some View {
        background(FullScreenAuxiliaryConfigurator())
    }
}

/// The one place this app reaches an `NSWindow`, and the first
/// `NSViewRepresentable` in it.
///
/// **`viewDidMoveToWindow`, not `onAppear`.** Configuring the window from
/// `onAppear` re-triggers the render that called it, which is a documented
/// infinite loop; and `NSApp.windows.last` is a guess that is wrong whenever
/// two companions open in the same runloop turn. A view in the hierarchy knows
/// its own window and is told exactly once when it gets one.
///
/// Zero-size and in `.background`, so it contributes no layout. `NSView` is
/// `@MainActor`, so the override needs no isolation of its own.
private struct FullScreenAuxiliaryConfigurator: NSViewRepresentable {

    internal func makeNSView(context: Context) -> NSView { ConfiguringView() }

    /// Nothing to update: the behaviour is a property of the window, set once
    /// when the view is attached. If SwiftUI is ever found to reset
    /// `collectionBehavior` after we write it, *this* is the method that would
    /// have to grow a body — and that is a measurement, not a precaution.
    internal func updateNSView(_ nsView: NSView, context: Context) { }

    private final class ConfiguringView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // Fires with a nil window on detach too, which is not our edge.
            guard let window else { return }
            window.collectionBehavior = FullScreenAuxiliary.auxiliary(
                window.collectionBehavior
            )
        }
    }
}
