import AppKit
import Testing
@testable import DGTStudioPro

/// The companion-window collection-behaviour transform.
///
/// **Nonisolated deliberately, and the nonisolation is load-bearing.**
/// `NSWindow` is `@MainActor`, but `NSWindow.CollectionBehavior` is a value
/// type *nested* inside it, and a global actor isolates a type's members
/// rather than the types nested in it (D44′, SE-0449's own example). This
/// suite compiling at all is the witness for that claim; if a future SDK
/// isolates the option set, this file stops building and says so, which is the
/// right severity for an isolation fact. A tidy-up that adds `@MainActor` here
/// removes the only thing checking it.
///
/// What is *not* witnessed here: that the window actually stops going full
/// screen. That needs a real window in a real space and is on the manual-check
/// list. This suite pins the one part of the change that is a pure value
/// question — and pins it because the tempting one-line spelling gets it
/// wrong in a way nothing else would report.
@Suite("Full-screen auxiliary behaviour")
struct FullScreenAuxiliaryTests {

    /// The pair, both directions, from the state SwiftUI actually hands over.
    @Test func aPrimaryWindowBecomesAuxiliary() {
        let result = FullScreenAuxiliary.auxiliary([.fullScreenPrimary])
        #expect(result.contains(.fullScreenAuxiliary))
        #expect(result.contains(.fullScreenPrimary) == false)
    }

    /// Idempotent, because `viewDidMoveToWindow` fires again whenever the view
    /// is re-attached — a window restored from a saved session, or a tab torn
    /// off and re-merged. A transform that only worked on a virgin window
    /// would fail exactly there and nowhere a first launch would show it.
    @Test func applyingItTwiceChangesNothingTheSecondTime() {
        let once = FullScreenAuxiliary.auxiliary([.fullScreenPrimary])
        #expect(FullScreenAuxiliary.auxiliary(once) == once)
    }

    /// **The test this suite exists for.** `behavior = [.fullScreenAuxiliary]`
    /// passes both assertions above and silently drops every unrelated flag
    /// the framework set. `.managed` is the expensive one — a window that
    /// leaves Mission Control reads as an OS bug, not as our line of code —
    /// so the pin is on the flags the transform must leave alone rather than
    /// on the two it moves.
    @Test func unrelatedFlagsSurvive() {
        let original: NSWindow.CollectionBehavior = [
            .fullScreenPrimary, .managed, .participatesInCycle
        ]
        let result = FullScreenAuxiliary.auxiliary(original)
        #expect(result.contains(.managed))
        #expect(result.contains(.participatesInCycle))
    }

    /// A window that never claimed the full-screen role still gains the
    /// auxiliary one. The main `WindowGroup` is not passed through here at
    /// all — this is about a companion whose behaviour SwiftUI happened to
    /// hand over already stripped, which is a framework detail we do not
    /// control and should not depend on either way.
    @Test func anAlreadyNonPrimaryWindowStillGainsTheAuxiliaryRole() {
        let result = FullScreenAuxiliary.auxiliary([.managed])
        #expect(result.contains(.fullScreenAuxiliary))
        #expect(result.contains(.managed))
    }
}
