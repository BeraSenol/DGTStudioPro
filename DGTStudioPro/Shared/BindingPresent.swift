import SwiftUI

// MARK: Presentation Bindings

extension Binding where Value == Bool {
    /// Presentation flag over optional state: true while present; dismissal clears the source.
    /// `BoardDestination`'s offer bindings look identical and are deliberately not folded in — they ignore dismissal.
    /// Waived warning ×2: non-Sendable `Binding` captured in `@Sendable` closures; expires by deletion when
    /// `.alert(item:)` ships (the register's one compiler-warning waiver).
    init<T>(present source: Binding<T?>) {
        self.init(
            get: { source.wrappedValue != nil },
            set: { if !$0 { source.wrappedValue = nil } }
        )
    }
}
