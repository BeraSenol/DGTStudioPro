import Testing
import SwiftUI
@testable import DGTStudioPro

/// Pins `Binding(present:)`'s dismissal contract (M18 Phase 1). `@MainActor` the way its call
/// sites are - every consumer is view code handing the result to a presentation modifier.
/// The helper itself is slated for deletion when `.alert(item:)` ships (the register's
/// compiler-warning waiver); until then its semantic is load-bearing at eleven call sites,
/// and the third pin below is the subtle half nothing else states as a check.
@MainActor
@Suite("Binding Present")
struct BindingPresentTests {

    /// A tiny reference box so the tests observe writes the way SwiftUI would - a `Binding`
    /// over a local `var` captures the copy, not the storage.
    private final class Box<T> {
        var value: T?
        init(_ value: T?) { self.value = value }
    }

    private func binding<T>(over box: Box<T>) -> Binding<T?> {
        Binding(get: { box.value }, set: { box.value = $0 })
    }

    @Test func presentReadsNonNilAsTrue() {
        let box = Box<String>("subject")
        let present = Binding(present: binding(over: box))
        #expect(present.wrappedValue)
    }

    @Test func presentReadsNilAsFalse() {
        let box = Box<String>(nil)
        let present = Binding(present: binding(over: box))
        #expect(!present.wrappedValue)
    }

    /// Dismissal clears the source - the whole point of the helper.
    @Test func settingFalseClearsTheSource() {
        let box = Box<String>("subject")
        let present = Binding(present: binding(over: box))
        present.wrappedValue = false
        #expect(box.value == nil)
    }

    /// The asymmetry, stated as a check: `true` is not a command. The setter cannot invent a
    /// value for an empty source, and it must not disturb a live one - presentation state
    /// flows from the optional, never into it.
    @Test func settingTrueNeitherInventsNorDisturbs() {
        let empty = Box<String>(nil)
        let emptyPresent = Binding(present: binding(over: empty))
        emptyPresent.wrappedValue = true
        #expect(empty.value == nil)

        let live = Box<String>("subject")
        let livePresent = Binding(present: binding(over: live))
        livePresent.wrappedValue = true
        #expect(live.value == "subject")
    }
}
