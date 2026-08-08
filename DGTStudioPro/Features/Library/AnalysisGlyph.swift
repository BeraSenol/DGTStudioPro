import SwiftData
import SwiftUI

/// The analysis-state glyph: a gear badged with a checkmark when analyzed, an
/// xmark when not, bare while the engine has it.
///
/// One home for the symbol and the tint. **The predicate moved to
/// `PGN.hasScoredPly` on 7 Aug 2026** and this type forwards to it.
///
/// The paragraph that stood here recorded the two spellings — `contains
/// { $0 != nil }` against `!isEmpty` — noted that they "disagreed on a
/// non-empty all-nil array", and concluded that D33′'s bar/graph gate "keeps
/// its own `isEmpty` on purpose: it asks 'is there anything to draw', not
/// 'did a pass run'."
///
/// **The reasoning was right and the conclusion was backwards.** An all-nil
/// array has nothing to draw — every point on the curve it produces comes
/// from the `?? 0.5` fallback, so the gate that claimed to ask "is there
/// anything to draw" was the one drawing a fabricated line. `!isEmpty` asks
/// whether the array exists, which stopped being a proxy for anything the
/// moment `GameAnalysisDriver` began resetting it to full-length nils before
/// the walk. Both gates ask `hasScoredPly` now, and the divergence this
/// paragraph documented as deliberate is closed rather than explained.
///
/// Left visible rather than deleted: a comment that names a divergence and
/// argues it is intentional is the hardest kind to re-examine, because it has
/// already answered the question a reader would ask.
internal enum AnalysisGlyph {

    // MARK: State

    /// What the glyph says about a game, or about a whole selection.
    ///
    /// Three states rather than a `Bool`: `isAnalyzed` is true for *any* scored
    /// ply and the driver writes plies as it walks, so a `Bool` went green at
    /// ply one. "Some plies are scored" and "the pass finished" are different
    /// questions; the array only answers the first.
    ///
    /// No `waiting` case — a queued game is genuinely unanalyzed, and the queue
    /// window says where it stands better than a third glyph would.
    internal enum State: Equatable {
        /// Nothing scored, nothing working on it. Queued games sit here too.
        case unanalyzed
        /// On the engine now. Beats the array, which is mid-write underneath.
        case analyzing
        /// A pass left evaluations and nothing is running. Says nothing about
        /// *coverage* — a skipped batch still reads analyzed; the Analysis
        /// Data window's per-ply rows are where that shows (D73′ — this
        /// pointed at Get Info's "48 of 58" row until that section was
        /// removed 8 Aug 2026).
        case analyzed
    }

    /// "Has been analyzed", spelled once — on `PGN`, which owns the question.
    ///
    /// A forwarding accessor, not a second rule: the `LiveGame.Roster`
    /// → `Player.seatsNameOnePlayer` shape. Kept rather than replaced at the
    /// call sites because the glyph's own vocabulary reads better here, and
    /// because a type that renders "analyzed?" should be able to say the word.
    internal static func isAnalyzed(_ game: PGN) -> Bool {
        game.hasScoredPly
    }

    /// The glyph's state for the games a caller is rendering.
    ///
    /// **Running wins, then all-or-nothing.** Running first because a pass in
    /// flight is a fact about now while `evaluations` is written underneath it.
    /// The checkmark means no work left in this set, so one unanalyzed game
    /// denies it. Singular callers pass a one-element array so the per-game and
    /// aggregate answers cannot fork; an empty set reads `.unanalyzed`.
    ///
    /// **Membership is asked of `games`, so `games` must be the caller's real
    /// subject and not a list something else can narrow.** The Library toolbar
    /// once resolved its selection through `filteredGames`: with the Not
    /// Analyzed chip on, ply one made the running game analyzed, the chip
    /// dropped it from the list, this `contains` stopped matching, and the
    /// button fell back to red-x mid-batch. A question about identity must not
    /// be routed through a filterable collection — an aggregate caller should
    /// compare ids against `runningID` directly, which is O(1) and owes nothing
    /// to what is on screen.
    internal static func state(
        of games: [PGN],
        runningID: PersistentIdentifier?
    ) -> State {
        if let runningID, games.contains(where: { $0.persistentModelID == runningID }) {
            return .analyzing
        }
        return !games.isEmpty && games.allSatisfy(isAnalyzed) ? .analyzed : .unanalyzed
    }

    /// The per-row spelling, fed from the destination's memoized projection
    /// (D72′) — `isAnalyzed` arrives as `GameRecord.hasAnalysis` rather than
    /// being asked of the model here.
    ///
    /// **Exists so a row badge cannot cost a blob decode.** The array overload
    /// above reads `hasScoredPly`, which decodes `evaluations`; right for a
    /// context menu that opens once, wrong for a badge on every visible row of
    /// every mode on every render — the exact per-row cost D70′ took out of
    /// the folds, which the badges must not smuggle back in. The two overloads
    /// answer identically because `GameRecord.hasAnalysis` is built *from*
    /// `hasScoredPly` (`PGN+GameRecord`), so this is one spelling read off a
    /// cache, not a second opinion — pinned by
    /// `theProjectionOverloadAgreesWithTheModelOverload`.
    ///
    /// Running still wins, and the running comparison is still by identifier
    /// against the caller's own subject — the membership trap on the array
    /// overload does not arise, because a single game *is* its own subject.
    internal static func state(
        of game: PGN,
        isAnalyzed: Bool,
        runningID: PersistentIdentifier?
    ) -> State {
        if game.persistentModelID == runningID { return .analyzing }
        return isAnalyzed ? .analyzed : .unanalyzed
    }

    /// The symbol. Bare `gear` while analyzing: a badge is a *verdict* and an
    /// unfinished pass has not reached one. It also keeps the three states as
    /// three silhouettes, legible where motion and colour are dropped — menus
    /// render symbols as monochrome templates whatever we ask for.
    internal static func name(_ state: State) -> String {
        switch state {
        case .unanalyzed: "gear.badge.xmark"
        case .analyzing:  "gear"
        case .analyzed:   "gear.badge.checkmark"
        }
    }

    /// The *corner-badge* symbol — plain verdict marks, no gear (D72′
    /// postscript, 8 Aug 2026, by request: "only a green check mark or red x
    /// in the icon view … only a gear icon during analysis").
    ///
    /// A second vocabulary beside `name(_:)`, which D72′ originally rejected —
    /// overruled with a reason worth keeping: on a *card corner* the glyph is
    /// pure status and the gear silhouette read as chrome around the mark that
    /// mattered, while on the action surfaces (the Analyze column's button,
    /// the chips, the menus) the gear **is** the meaning — "engine work" — and
    /// stays. The gear is shared for `.analyzing` deliberately, so "the engine
    /// has this one" is one silhouette everywhere it appears.
    ///
    /// The `.fill` circles are the queue window's own finished-row vocabulary
    /// (`checkmark.circle.fill` green), so the badge agrees with the surface
    /// that reports the same verdict in prose.
    internal static func badgeName(_ state: State) -> String {
        switch state {
        case .unanalyzed: "xmark.circle.fill"
        case .analyzing:  "gear"
        case .analyzed:   "checkmark.circle.fill"
        }
    }

    // MARK: Badge Tint

    /// The badge's colour: green analyzed, red not, **nil while running** —
    /// no badge to colour and no verdict to report.
    ///
    /// Here rather than at the render sites, for the reason this type exists:
    /// a colour decided per site is the twin-read-site pattern with a `Color`
    /// in it. Semantic rather than hex, so the badges follow Increase Contrast
    /// and differentiate-without-colour; the shape already carries the meaning
    /// and the colour only reinforces it, which is what makes a red/green pair
    /// defensible.
    ///
    /// Nil means more than "no colour": the running gear takes **no foreground
    /// style at all** and inherits its host's. A third hue would fight
    /// `.borderedProminent`, which supplies its own and would be right to.
    internal static func tint(_ state: State) -> Color? {
        switch state {
        case .unanalyzed: .red
        case .analyzing:  nil
        case .analyzed:   .green
        }
    }

    /// "Analyze", "Analyzing…", "Analyzed".
    ///
    /// A past participle on a live control is *state over verb*: the common
    /// reason to look is to find out whether it has been done. It reads like a
    /// disabled control and isn't one — clicking re-runs the pass, and clicking
    /// while analyzing is safe because `AnalysisQueue.enqueue` skips an id
    /// already running.
    internal static func actionTitle(_ state: State) -> String {
        switch state {
        case .unanalyzed: "Analyze"
        case .analyzing:  "Analyzing…"
        case .analyzed:   "Analyzed"
        }
    }

    /// "Not Analyzed", "Analyzing", "Analyzed" — the *status* vocabulary, for
    /// surfaces that state rather than act (the badge's accessibility label).
    ///
    /// Separate from `actionTitle` because the first word differs in kind:
    /// "Analyze" is a verb on a control and reads wrong on a passive badge,
    /// while "Not Analyzed" matches `LibrarySearchToken.unanalyzed`'s chip —
    /// deliberately, so the badge and the filter that finds badged games speak
    /// one phrase.
    internal static func statusLabel(_ state: State) -> String {
        switch state {
        case .unanalyzed: "Not Analyzed"
        case .analyzing:  "Analyzing"
        case .analyzed:   "Analyzed"
        }
    }
}

// MARK: Ambient Queue State

extension EnvironmentValues {

    /// The game on the engine right now, or nil.
    ///
    /// **The app's first custom environment value.** The glyph needs one fact
    /// from the queue and the sites drawing it are leaves — `GameActionsMenu`
    /// across three hosts, `LibraryColumnsView`'s detail button, the list's
    /// Analysis column. A parameter would reach four view types and ~10 preview
    /// call sites, nearly all passing nil. `OpenGamesRegistry` is the
    /// precedent; this is its narrow form.
    ///
    /// **An id, not the controller.** A leaf holding the controller could
    /// enqueue, and would observe its per-ply progress — re-rendering every
    /// Library row once per ply. This changes once per game. Nil is the honest
    /// default for every context with no queue: previews, and Get Info.
    @Entry internal var analysisRunningGameID: PersistentIdentifier?
}

// MARK: Running Gear

/// The badgeless gear, turning — one spelling of "work is happening now",
/// drawn by the queue toolbar item and by `AnalysisLabel`, which must not
/// choose different motions.
///
/// **`.rotate` is confirmed to turn `gear`; that it *repeats* is not.** The
/// field run that answered the first question had a state bug pulling the glyph
/// out from under the effect, so "stopped spinning" and "stopped being a gear"
/// were one event. On the manual-check list. If it turns once and stops, the
/// replacement is a `.rotationEffect` with a repeating animation — and it
/// belongs in this one body.
///
/// No foreground style: a running pass has no verdict, and the two drawers sit
/// in different chrome (a toolbar button, a `Label`'s icon slot), so inheriting
/// is the only thing right in both.
internal struct AnalyzingGear: View {

    internal var body: some View {
        Image(systemName: AnalysisGlyph.name(.analyzing))
            .symbolEffect(.rotate, options: .repeat(.continuous))
    }
}

// MARK: Label

/// The analysis glyph beside its title — badge tinted where there is a badge,
/// spinning where there is not, and **the text left alone** in every case.
///
/// A view rather than a modifier, because the modifier it replaced could not be
/// right: `.foregroundStyle(tint, .foreground)` applied to a whole `Label`
/// styles the *text* with the primary argument too, so every "Analyze" came out
/// green or red. Palette rendering has to reach the `Image` and nothing else,
/// which means building the `Label` from its two closures — a *structure*, and
/// a structure cannot be applied after the fact by a flattened call site.
internal struct AnalysisLabel: View {

    internal let title: String
    internal let state: AnalysisGlyph.State

    /// Defaults to `AnalysisGlyph.actionTitle` so action sites read the same
    /// word without restating the switch. The token chips pass their own —
    /// "Not Analyzed" is a filter's name, not a verb.
    internal init(state: AnalysisGlyph.State, title: String? = nil) {
        self.state = state
        self.title = title ?? AnalysisGlyph.actionTitle(state)
    }

    internal var body: some View {
        Label {
            Text(title)
        } icon: {
            icon
        }
    }

    private var icon: some View {
        AnalysisGlyphIcon(state: state)
    }
}

// MARK: Icon

/// The glyph alone — badge tinted where there is a badge, spinning where there
/// is not. Extracted from `AnalysisLabel` when the D72′ row badges briefly
/// drew it too; the postscript moved those to `AnalysisBadgeIcon`'s plain
/// marks the same day, so this is back to one drawer. Kept extracted rather
/// than re-inlined: the palette arrangement's layer order (badge first, gear
/// second — see Rendering Notes) is the part that was got wrong once already,
/// and a named home is what keeps a second drawer from re-learning it.
///
/// Branches on `tint`'s optional rather than a second switch on the state,
/// so one source decides both the colour and whether there is one.
///
/// **The running gear takes no foreground style at all** — not `.primary`,
/// which would override a host supplying its own (a `.borderedProminent`
/// button, a selected row), and not a third palette hue on a state with no
/// verdict. Motion lives in `AnalyzingGear`, shared with the queue toolbar.
///
/// **macOS ignores symbol effects in menu items**, so a menu's copy is a
/// still gear by construction — legible anyway, since the badgeless
/// silhouette already differs from both badged forms.
internal struct AnalysisGlyphIcon: View {

    internal let state: AnalysisGlyph.State

    internal var body: some View {
        if let tint = AnalysisGlyph.tint(state) {
            Image(systemName: AnalysisGlyph.name(state))
                .symbolRenderingMode(.palette)
                .foregroundStyle(tint, .foreground)
        } else {
            AnalyzingGear()
        }
    }
}

// MARK: Badge Icon

/// The plain-mark icon behind both D72′ badge surfaces — the card corner
/// (wrapped in `AnalysisStatusBadge`'s chip) and the columns row (bare).
///
/// One view so the two surfaces cannot pick different marks; the branch shape
/// is `AnalysisGlyphIcon`'s. The `.fill` circles carry their own colour whole
/// — no palette split, the mark is knocked out of the disc — and the running
/// arm is the shared `AnalyzingGear`, taking no foreground style for that
/// type's stated reason.
internal struct AnalysisBadgeIcon: View {

    internal let state: AnalysisGlyph.State

    internal var body: some View {
        if let tint = AnalysisGlyph.tint(state) {
            Image(systemName: AnalysisGlyph.badgeName(state))
                .foregroundStyle(tint)
        } else {
            AnalyzingGear()
        }
    }
}

// MARK: Status Badge

/// The analysis state as a corner badge — bottom-trailing on the Library's
/// cards (D72′, by request; plain marks per the postscript).
///
/// **A backing chip, and it is load-bearing rather than chrome.** The card's
/// document sheet is explicitly `.white` in both appearances, and the running
/// gear inherits `.foreground` — white in dark mode, which over that sheet is
/// a glyph that vanishes in exactly the state worth watching. The material
/// circle supplies its own adaptive contrast, so the icon needs no special
/// casing per host — and it earns its keep for the verdicts too, holding the
/// green and red discs off the white paper.
///
/// Status, not a control: it takes no action and swallows no clicks
/// (`allowsHitTesting(false)`), so the card's own tap and menu targets are
/// exactly what they were before it existed. The accessibility label speaks
/// `statusLabel`'s vocabulary — the chip a search for the same state wears.
internal struct AnalysisStatusBadge: View {

    internal let state: AnalysisGlyph.State

    internal var body: some View {
        AnalysisBadgeIcon(state: state)
            .font(.title3)
//            .padding(4)
            .background(.thinMaterial, in: Circle())
            .allowsHitTesting(false)
            .accessibilityLabel(AnalysisGlyph.statusLabel(state))
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
// **Neither the palette nor the spin takes everywhere.** macOS renders symbols
// in menus and some toolbar contexts as monochrome templates, and `NSMenuItem`
// takes an image rather than a running animation — so a menu's Analyze row is a
// still, untinted gear while the queue toolbar item turns. `AnalysisLabel` is
// used at those sites anyway: it costs nothing where it is ignored, and the
// alternative is a rule about which call sites get the treatment that nobody
// would remember. Absorbed by the three states being three silhouettes before
// any colour or motion is applied.

// MARK: Previews

/// The defect this type prevents is **visual and nothing else** — a tint
/// leaking from the symbol onto the word — so this preview is the only witness
/// that can fail. All six titles must render in the *default* foreground while
/// the badges differ; the counted plural is here because a long green string is
/// where the leak showed worst.
///
/// **The `.analyzing` row is also the spin's only witness.** A canvas runs
/// symbol effects, so this is where "does it keep rotating" gets answered — see
/// `AnalyzingGear`.
#Preview("Every State, Both Titles") {
    VStack(alignment: .leading, spacing: 12) {
        AnalysisLabel(state: .unanalyzed)
        AnalysisLabel(state: .analyzing)
        AnalysisLabel(state: .analyzed)
        AnalysisLabel(state: .unanalyzed, title: "Analyze 3 Games")
        AnalysisLabel(state: .analyzing, title: "Analyzing 3 Games")
        AnalysisLabel(state: .analyzed, title: "Analyze 3 Games")
    }
    .padding()
    .frame(width: 220, alignment: .leading)
}

/// Why `icon` leaves the running gear unstyled: a `.primary` or third palette
/// hue reads fine on the plain row above and wrong here, where a prominent
/// button paints its label white. The gear must match the "Open" glyph beside
/// it, which is only checkable side by side.
#Preview("Running, In Hosts") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            Button {} label: {
                Label("Open", systemImage: "arrow.up.forward.square")
            }
            .buttonStyle(.borderedProminent)

            Button {} label: { AnalysisLabel(state: .analyzing) }
                .buttonStyle(.borderedProminent)
        }

        HStack(spacing: 12) {
            Button {} label: {
                Label("Open", systemImage: "arrow.up.forward.square")
            }
            Button {} label: { AnalysisLabel(state: .analyzing) }
        }
    }
    .padding()
}

/// The badge over the card's worst case — a white document sheet — because
/// that host is why the chip exists: the running gear inherits `.foreground`,
/// which in dark mode is white on that white. All three states over the sheet
/// and over plain window background; the check is that every glyph reads in
/// both appearances, which only a canvas can answer.
#Preview("Status Badge, Both Grounds") {
    HStack(spacing: 24) {
        ForEach([AnalysisGlyph.State.unanalyzed, .analyzing, .analyzed], id: \.self) { state in
            VStack(spacing: 12) {
                Image(systemName: "doc.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.white)
                    .frame(width: 60)
                    .overlay(alignment: .bottomTrailing) {
                        AnalysisStatusBadge(state: state)
                    }
                AnalysisStatusBadge(state: state)
            }
        }
    }
    .padding(24)
}
