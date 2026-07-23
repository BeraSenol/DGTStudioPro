//
//  GameHeadline.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 23/07/2026.
//

/// The Board inspector's section headline: "Reviewing 1. Magnus Carlsen vs
/// Ian Nepomniachtchi" over an archived game, "Recording 101. …" over a live
/// one (M-ux.3, D20′).
///
/// A pure formatter with a suite, in the `RecoveryGuidance` mould. The two
/// inspectors are different views onto the same grammar, and the grammar —
/// what an absent round does, how a placeholder seat reads, whose display
/// transform applies — is the part worth pinning; the views stay dumb.
///
/// It deliberately carries the **pairing**, not `PGN.name`: the verb + round
/// + players grammar is fixed, and a custom name ("Club Championship, board
/// 3") would break it mid-sentence. Nothing is lost — a custom name is the
/// window's `navigationTitle`, one glance up.
internal enum GameHeadline {
    
    /// What the tab is doing with the game. Raw values are the user-facing
    /// verbs, so a new activity cannot be added without naming it.
    internal enum Activity: String, Sendable {
        case reviewing = "Reviewing"
        case recording = "Recording"
    }
    
    /// The placeholder for a seat with no usable name — the `"?"` the PGN
    /// tag convention and `displayRound` already use.
    private static let unknownPlayer = "?"
    
    /// Formats the headline. `white`/`black` take **raw tag form**: the
    /// "Last, First" → "First Last" transform happens here, so the review
    /// and live call sites can't drift apart on it.
    ///
    /// An absent round omits the number entirely rather than printing a
    /// placeholder — "Reviewing ?. Alice vs Bob" reads like a defect, and
    /// the Round row directly below already states the gap.
    internal static func text(
        _ activity: Activity,
        round: Int?,
        white: String,
        black: String
    ) -> String {
        let pairing = "\(displayName(white)) vs \(displayName(black))"
        guard let round else { return "\(activity.rawValue) \(pairing)" }
        return "\(activity.rawValue) \(round). \(pairing)"
    }
    
    /// `PGN.displayPlayerName` with an empty result folded to the
    /// placeholder: a blank seat must not collapse the sentence into
    /// "Recording  vs Bob".
    private static func displayName(_ raw: String) -> String {
        let display = PGN.displayPlayerName(raw)
        return display.isEmpty ? unknownPlayer : display
    }
}
