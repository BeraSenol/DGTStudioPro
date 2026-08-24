/// The inspector headline: "Reviewing 1. X vs Y" / "Recording …". Carries the
/// **pairing**, not `PGN.name`; activity raw values are the user-facing verbs; an absent round
/// omits the number; a blank seat folds to `?`.
enum GameHeadline {
    
    /// What the tab is doing with the game. Raw values are the user-facing
    /// verbs, so a new activity cannot be added without naming it.
    enum Activity: String, Sendable {
        case reviewing = "Reviewing"
        case recording = "Recording"
    }
    
    /// The placeholder for a seat with no usable name - the `"?"` the PGN
    /// tag convention and `displayRound` already use.
    private static let unknownPlayer = "?"
    
    /// Takes **raw tag form** - the display transform happens here, so the two call sites can't drift.
    ///
    /// **`round:` is a display slot, not `Roster.round`.** Both callers pass the *library ordinal* -
    /// "Recording 112." for the game that will archive as 112 - since 17 Aug 2026, when round 12
    /// against Lorenzo headlined a 111-game library as "Recording 12.". The parameter kept its name,
    /// so a third caller wiring `roster.round` here would re-introduce that report.
    static func text(
        _ activity: Activity,
        round: Int?,
        white: String,
        black: String
    ) -> String {
        let pairing = "\(displayName(white)) vs \(displayName(black))"
        guard let round else { return "\(activity.rawValue) \(pairing)" }
        return "\(activity.rawValue) \(round). \(pairing)"
    }
    
    /// `PlayerName.displayForm(of:)` with an empty result folded to the
    /// placeholder: a blank seat must not collapse the sentence into
    /// "Recording  vs Bob".
    private static func displayName(_ raw: String) -> String {
        let display = PlayerName.displayForm(of: raw)
        return display.isEmpty ? unknownPlayer : display
    }
}
