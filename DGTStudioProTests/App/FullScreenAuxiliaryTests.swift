import AppKit
import Testing
@testable import DGTStudioPro

/// The collection-behaviour transform. Nonisolated, load-bearing. Not witnessed: that the
/// window actually stops claiming a space — that is the manual list; this pins the pure transform.
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

    /// **The test this suite exists for**: a plain assignment passes the two obvious assertions and
    /// silently drops every unrelated flag — `.managed` is the expensive one (Mission Control).
    @Test func unrelatedFlagsSurvive() {
        let original: NSWindow.CollectionBehavior = [
            .fullScreenPrimary, .managed, .participatesInCycle
        ]
        let result = FullScreenAuxiliary.auxiliary(original)
        #expect(result.contains(.managed))
        #expect(result.contains(.participatesInCycle))
    }

    /// A window that never claimed the full-screen role still gains the auxiliary one — the
    /// pre-stripped shape is a framework detail we must not depend on.
    @Test func anAlreadyNonPrimaryWindowStillGainsTheAuxiliaryRole() {
        let result = FullScreenAuxiliary.auxiliary([.managed])
        #expect(result.contains(.fullScreenAuxiliary))
        #expect(result.contains(.managed))
    }
}
