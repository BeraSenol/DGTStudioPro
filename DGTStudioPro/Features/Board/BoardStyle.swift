import SwiftUI

/// The four board woods. `String`-backed because `@AppStorage` stores a `RawRepresentable` directly -
/// five call sites bind `StorageKeys.boardStyle` to this type, and none of them go through `Codable`,
/// which no code in the tree uses.
///
/// **The two switches below are deliberately not collapsed** into one returning a pair. Each is
/// exhaustive, so adding a wood is two compile errors that name exactly what is missing; a single
/// switch over tuples, or a dictionary, trades that for a runtime shrug. Recorded in the project's
/// "not every duplicate should be collapsed" list, and stated here because a constraint every
/// instance obeys and nothing explains reads as an oversight worth fixing.
enum BoardStyle: String, CaseIterable, Codable, Sendable {
    case leather
    case rosewood
    case walnut
    case wenge

    // MARK: Computed Properties

    /// Works only because every case is a single lowercase word - `.capitalized` would render a
    /// camelCase case as "Blondemaple". A two-word wood needs a switch here, not a fifth case.
    var displayName: String {
        self.rawValue.capitalized
    }

    /// Asset-catalog symbols: `.leatherLight` is `LeatherLight.colorset`, generated, so a renamed or
    /// missing colorset is a build error rather than a blank square.
    var light: Color {
        switch self {
        case .leather:  .leatherLight
        case .rosewood: .rosewoodLight
        case .walnut:   .walnutLight
        case .wenge:    .wengeLight
        }
    }

    var dark: Color {
        switch self {
        case .leather:  .leatherDark
        case .rosewood: .rosewoodDark
        case .walnut:   .walnutDark
        case .wenge:    .wengeDark
        }
    }
}
