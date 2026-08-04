//
//  AnalysisGlyph.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 02/08/2026.
//

import SwiftUI

/// The analysis-state glyph (2 Aug 2026, retiring the state-blind
/// `wand.and.stars` everywhere): a gear with a checkmark for a game that
/// has been analyzed, a gear with an xmark for one that hasn't. One home
/// for both symbol names *and* for the predicate, because the glyph made a
/// latent fork visible: the inspector's Re-analyze keyed off
/// `evaluations.contains { $0 != nil }` while the search filter keyed off
/// `!evaluations.isEmpty` — different answers for a non-empty all-nil
/// array. Both now route here. (D33′'s bar/graph presence gate stays its
/// own `evaluations.isEmpty` deliberately: it asks "is there anything to
/// draw", not "did an analysis pass run".)
internal enum AnalysisGlyph {

    /// "Has been analyzed", spelled once: any ply carries a recorded
    /// evaluation.
    internal static func isAnalyzed(_ game: PGN) -> Bool {
        game.evaluations.contains { $0 != nil }
    }

    internal static func name(analyzed: Bool) -> String {
        analyzed ? "gear.badge.checkmark" : "gear.badge.xmark"
    }

    /// The per-game convenience the three single-game call sites read.
    internal static func name(for game: PGN) -> String {
        name(analyzed: isAnalyzed(game))
    }

    // MARK: Badge Tint (3 Aug 2026)

    /// The badge's colour: green for analyzed, red for not.
    ///
    /// Here rather than at the six render sites for the reason this type
    /// exists at all — it already owns *which* symbol and *what counts as
    /// analyzed*, and a colour decided per site is the twin-read-site
    /// pattern with a `Color` in it. Six sites agreeing today is not the
    /// same as six sites that cannot disagree.
    ///
    /// Semantic rather than literal (`.green` / `.red`, not hex), so the
    /// badges follow the system's accessibility settings — including
    /// Increase Contrast and the differentiate-without-colour work Apple
    /// does to these two hues specifically. The glyph shape is already
    /// carrying the meaning; the colour is reinforcement, which is the only
    /// way a red/green pair is defensible.
    internal static func tint(analyzed: Bool) -> Color {
        analyzed ? .green : .red
    }

    /// The action's title. "Analyzed" once it has been, "Analyze" before.
    ///
    /// The button still re-runs the pass when clicked — a past participle on
    /// a live control is a deliberate choice of *state over verb*, on the
    /// grounds that the common reason to look at it is to find out whether
    /// the game has been done, not to do it again. Recorded because it reads
    /// like a disabled control and isn't one; "Re-analyze" was the previous
    /// answer and said the opposite thing.
    internal static func actionTitle(analyzed: Bool) -> String {
        analyzed ? "Analyzed" : "Analyze"
    }
}

// MARK: Label

/// The analysis glyph beside its title, with the badge tinted and **the text
/// left alone**.
///
/// This type exists because the modifier it replaces got that wrong. Applying
/// `.foregroundStyle(tint, .foreground)` to a whole `Label` styles the label's
/// *text* with the primary argument too, so every "Analyze" came out green or
/// red — visible in the columns detail and the inspector at once. Palette
/// rendering has to reach the `Image` and nothing else, which means building
/// the `Label` from its two closures rather than from a `systemImage:` string.
///
/// A view rather than a modifier for the reason the modifier failed: the
/// correct arrangement is a *structure*, and a structure cannot be applied
/// after the fact by a call site that has already flattened it.
internal struct AnalysisLabel: View {

    internal let title: String
    internal let analyzed: Bool

    /// The title defaults to `AnalysisGlyph.actionTitle`, so the five action
    /// sites read the same word without restating the ternary. The token
    /// chips pass their own, because "Not Analyzed" is a filter's name rather
    /// than a verb.
    internal init(analyzed: Bool, title: String? = nil) {
        self.analyzed = analyzed
        self.title = title ?? AnalysisGlyph.actionTitle(analyzed: analyzed)
    }

    internal var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: AnalysisGlyph.name(analyzed: analyzed))
                .symbolRenderingMode(.palette)
                .foregroundStyle(AnalysisGlyph.tint(analyzed: analyzed), .foreground)
        }
    }
}

// MARK: Rendering Notes
//
// `View.analysisGlyphTint(analyzed:)` lived here for one build. It applied
// `.symbolRenderingMode(.palette)` and `.foregroundStyle(tint, .foreground)`
// to whatever it was attached to, which at every call site was a whole
// `Label` — and a `Label`'s text takes the primary foreground style along
// with the symbol, so the tint leaked onto the word. `AnalysisLabel` above
// replaces it by building the label from its icon and title closures, which
// is the only way to scope palette rendering to the `Image`.
//
// Two findings from that build are worth keeping, because they cost a render
// each and neither is guessable:
//
// **Layer order.** In `gear.badge.checkmark` / `gear.badge.xmark` the badge
// is layer 1 and the gear is layer 2 — the opposite of the obvious reading,
// where the base symbol comes first and the badge decorates it. The first
// version had them the other way round and produced a green gear with a plain
// checkmark.
//
// **Palette, not multicolor.** `.multicolor` would probably give the same two
// colours from Apple's own definitions, and "probably" is the problem: it is
// a promise about a symbol's built-in layers that changes when SF Symbols
// does. Palette says what it means.
//
// **It will not take everywhere.** macOS renders symbols in menus and some
// toolbar contexts as monochrome templates regardless of rendering mode.
// `AnalysisLabel` is used at those sites anyway: it costs nothing where it is
// ignored, and the alternative is a rule about which call sites get the
// treatment that nobody would remember.

// MARK: Previews

/// The defect this type exists to prevent is **visual and nothing else** — a
/// tint leaking from the symbol onto the word beside it — so a preview is not
/// a nicety here, it is the only witness that can fail. Neither the compiler
/// nor a unit test can see a green "Analyze".
///
/// Both tints, both title forms, on one canvas: the claim is that all four
/// titles render in the *default* foreground while the badges differ. If the
/// modifier this replaced ever comes back, two of these words turn colour and
/// the row above stays put, which is what makes the pairing worth the space.
///
/// The counted plural is here rather than only at the call site because it is
/// the form where the leak was most visible — a long green string rather than
/// one word.
#Preview("Both Tints, Both Titles") {
    VStack(alignment: .leading, spacing: 12) {
        AnalysisLabel(analyzed: false, title: nil)
        AnalysisLabel(analyzed: true, title: nil)
        AnalysisLabel(analyzed: false, title: "Analyze 3 Games")
        AnalysisLabel(analyzed: true, title: "Analyze 3 Games")
    }
    .padding()
    .frame(width: 220, alignment: .leading)
}
