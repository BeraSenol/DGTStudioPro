/// Which material the board cues are made of. One set holds all four cues,
/// so switching is one choice rather than four, and a set is internally consistent
/// by construction - a felt move cannot end up beside a marble capture.
///
/// Ordered soft → hard, which is the order a picker should offer them in: the list
/// reads as a scale rather than as three unrelated names.
enum BoardSoundSet: String, CaseIterable, Identifiable, Sendable {
    case felt
    case wood
    case marble

    var id: Self { self }

    /// Written out rather than derived from `rawValue.capitalized`. It would work
    /// today for all three, which is exactly why it is worth pinning: the first set
    /// whose name is two words or carries an accent would break silently, and
    /// `SpecialCheckmate.displayName` records that same tripwire.
    var displayName: String {
        switch self {
        case .felt:   "Felt"
        case .wood:   "Wood"
        case .marble: "Marble"
        }
    }

    /// The bundled sample for one cue in this set - `wood-capture`, `felt-move`.
    ///
    /// The set owns this rather than `BoardCue` because the set is the axis that
    /// varies: a cue is one of four fixed questions, a set is a growing list, and
    /// the naming convention should live with the thing that grows. Spelled off
    /// both `rawValue`s, so renaming either case is a **bundle** rename and the two
    /// cannot drift apart in silence.
    func resourceName(for cue: BoardCue) -> String {
        "\(rawValue)-\(cue.rawValue)"
    }
}
