import SwiftData
import SwiftUI

/// The analysis-state glyph (2 Aug 2026, retiring the state-blind
/// `wand.and.stars` everywhere): a gear with a checkmark for a game that
/// has been analyzed, a gear with an xmark for one that hasn't, and — since
/// 6 Aug 2026 — a bare spinning gear for one that is on the engine right now.
/// One home for the symbol names, the tint, *and* the predicate, because the
/// glyph made a latent fork visible: the inspector's Re-analyze keyed off
/// `evaluations.contains { $0 != nil }` while the search filter keyed off
/// `!evaluations.isEmpty` — different answers for a non-empty all-nil
/// array. Both now route here. (D33′'s bar/graph presence gate stays its
/// own `evaluations.isEmpty` deliberately: it asks "is there anything to
/// draw", not "did an analysis pass run".)
internal enum AnalysisGlyph {

    // MARK: State (6 Aug 2026)

    /// What the glyph is saying about a game — or about a whole selection.
    ///
    /// **Three states rather than a `Bool`, because the `Bool` could not name
    /// the one a user spends the most time looking at.** `isAnalyzed` is true
    /// for *any* scored ply, and the driver records plies as the walk advances,
    /// so a game went green at **ply one** and stayed green for the rest of the
    /// pass. That was never a threshold to tune: "some plies are scored" and
    /// "the pass has finished" are different questions, and the stored array
    /// can only answer the first. The second is the queue's to answer, which is
    /// why `state(of:runningID:)` takes both.
    ///
    /// Deliberately no `waiting` case. A game in line is genuinely unanalyzed,
    /// nothing is happening to it yet, and the toolbar's queue popover already
    /// owns "where is this in the batch" — three glyph states on screen at once
    /// would spend the whole vocabulary on a distinction the popover states
    /// better in words.
    internal enum State: Equatable {
        /// No ply carries an evaluation, and nothing is working on it. Also
        /// where a game in line sits, per the note above.
        case unanalyzed
        /// On the engine right now. Beats whatever the array says, because the
        /// array is mid-write underneath it.
        case analyzing
        /// A pass left evaluations behind and nothing is running. Says nothing
        /// about *coverage* — a skipped batch leaves a partial array and still
        /// reads analyzed, which is what Get Info's "48 of 58" row is for.
        case analyzed
    }

    /// "Has been analyzed", spelled once: any ply carries a recorded
    /// evaluation.
    internal static func isAnalyzed(_ game: PGN) -> Bool {
        game.evaluations.contains { $0 != nil }
    }

    /// The glyph's state for a set of games the caller is *rendering*.
    ///
    /// **Running wins, then all-or-nothing.** Running first because a pass in
    /// flight is a fact about *now* while `evaluations` is being written
    /// underneath it — consulting the array first is precisely how the badge
    /// used to go green at ply one. All-or-nothing second because that is the
    /// rule the toolbar has always spelled: the checkmark means there is no
    /// work left in this set, and one unanalyzed game is work left.
    ///
    /// **Singular callers pass a one-element array**, so the per-game answer
    /// and the aggregate one cannot fork — `GameActionsMenu` already takes its
    /// subject this way, for the same reason. It also folds in the emptiness
    /// guard that used to live at the toolbar and be *absent* from the menu
    /// (safe there only because a branch above it established non-emptiness):
    /// an empty selection reads `.unanalyzed` everywhere now, harmlessly, since
    /// the one site that can produce one is `disabled` there.
    ///
    /// **Membership is asked of `games`, so `games` must be the caller's real
    /// subject and not a list something else can narrow.** Both surviving
    /// callers satisfy that — a row's context menu and the columns detail pane
    /// each hold the games they are drawing, and a game that is filtered away
    /// takes its menu and its detail pane with it.
    ///
    /// **A caller that did not satisfy it cost a shipped bug, recorded here
    /// because the next aggregate caller will be tempted the same way.** The
    /// Library toolbar's Analyze button resolved its selection through
    /// `filteredGames`, which applies the search tokens. With the **Not
    /// Analyzed** chip on — the obvious way to pick a backlog to analyze — ply
    /// one of the running game made it analyzed, the chip dropped it from the
    /// rendered list, this `contains` stopped matching, and the button fell back
    /// to the red x while the engine worked on. A few seconds into an
    /// eighteen-game batch, reproducibly. It was briefly fixed by a
    /// selection-scoped overload comparing ids; that overload went with the
    /// button on 6 Aug 2026 rather than being kept as a door with no surface.
    ///
    /// The lesson outlives both: **a question about identity must not be routed
    /// through a collection something else is allowed to narrow.** If an
    /// aggregate caller ever returns, it should take the ids it means and
    /// compare against `runningID` directly — `PGN.ID` *is*
    /// `PersistentIdentifier`, so that check is O(1) and owes nothing to what
    /// happens to be on screen.
    internal static func state(
        of games: [PGN],
        runningID: PersistentIdentifier?
    ) -> State {
        if let runningID, games.contains(where: { $0.persistentModelID == runningID }) {
            return .analyzing
        }
        return !games.isEmpty && games.allSatisfy(isAnalyzed) ? .analyzed : .unanalyzed
    }

    /// The symbol. `gear` **alone** while analyzing, and the absence of a badge
    /// is the decision rather than a gap: a badge is a *verdict*, and a pass
    /// that has not finished has not reached one.
    ///
    /// It also means the three states stay legible with no motion and no colour
    /// involved — three distinct silhouettes. That matters because the spin is
    /// the one part of this that can silently not happen (see `AnalysisLabel`),
    /// and because macOS renders symbols in menus as monochrome templates
    /// regardless of what we ask for.
    internal static func name(_ state: State) -> String {
        switch state {
        case .unanalyzed: "gear.badge.xmark"
        case .analyzing:  "gear"
        case .analyzed:   "gear.badge.checkmark"
        }
    }

    // MARK: Badge Tint (3 Aug 2026)

    /// The badge's colour: green for analyzed, red for not, **nil while a pass
    /// is running** — there is no badge to colour, and no verdict to report.
    ///
    /// Here rather than at the render sites for the reason this type
    /// exists at all — it already owns *which* symbol and *what counts as
    /// analyzed*, and a colour decided per site is the twin-read-site
    /// pattern with a `Color` in it. Sites agreeing today is not the
    /// same as sites that cannot disagree.
    ///
    /// Semantic rather than literal (`.green` / `.red`, not hex), so the
    /// badges follow the system's accessibility settings — including
    /// Increase Contrast and the differentiate-without-colour work Apple
    /// does to these two hues specifically. The glyph shape is already
    /// carrying the meaning; the colour is reinforcement, which is the only
    /// way a red/green pair is defensible.
    ///
    /// The optional is what `AnalysisLabel` branches on, and nil means more
    /// than "no colour": the running gear takes **no foreground style at all**,
    /// so it inherits whatever its host gives every other glyph beside it. A
    /// third hue here would have to fight `.borderedProminent`, which supplies
    /// its own foreground and would be right to.
    internal static func tint(_ state: State) -> Color? {
        switch state {
        case .unanalyzed: .red
        case .analyzing:  nil
        case .analyzed:   .green
        }
    }

    /// The action's title. "Analyzed" once it has been, "Analyze" before,
    /// "Analyzing…" while the engine has it.
    ///
    /// The button still re-runs the pass when clicked — a past participle on
    /// a live control is a deliberate choice of *state over verb*, on the
    /// grounds that the common reason to look at it is to find out whether
    /// the game has been done, not to do it again. Recorded because it reads
    /// like a disabled control and isn't one; "Re-analyze" was the previous
    /// answer and said the opposite thing.
    ///
    /// The present participle is the same choice one state further along, and
    /// clicking it is safe rather than merely tolerated: `AnalysisQueue.enqueue`
    /// skips an id already running, so a second click on a spinning button is a
    /// no-op instead of a second pass over the game being written.
    internal static func actionTitle(_ state: State) -> String {
        switch state {
        case .unanalyzed: "Analyze"
        case .analyzing:  "Analyzing…"
        case .analyzed:   "Analyzed"
        }
    }
}

// MARK: Ambient Queue State

extension EnvironmentValues {

    /// The game on the engine right now, or nil.
    ///
    /// **The app's first custom environment value, so the argument is written
    /// here rather than left to look like a shortcut.** The glyph's state needs
    /// one fact from the queue, and the sites that draw it are leaves:
    /// `GameActionsMenu` (three hosts, each with its own previews) and
    /// `LibraryColumnsView`'s detail button. Threading a parameter reaches four
    /// view types and about ten preview call sites, nearly all of which would
    /// pass nil — a lot of surface area for a value no intermediate view has an
    /// opinion about. `OpenGamesRegistry` set the precedent for ambient app
    /// state in the environment; this is the narrow version of it.
    ///
    /// The Library toolbar was a third reader for a few hours and never used
    /// this — it held the controller directly, since the queue is in scope
    /// where the toolbar is built. Its Analyze button is gone (6 Aug 2026), so
    /// the destination is now purely the *writer*.
    ///
    /// **An id, not the controller**, and that is the load-bearing half. A leaf
    /// holding `AnalysisQueueController` could enqueue, and — worse — would
    /// observe everything on it, including the driver's per-ply progress, so
    /// every row in the Library would re-render once per ply of whatever is
    /// running. This value changes once per *game*. Written by
    /// `LibraryDestination`, which already re-renders on queue changes for its
    /// toolbar count, so it costs nothing new there.
    ///
    /// Defaults to nil, which is also the honest reading for every context that
    /// has no queue: previews, and Get Info's own window.
    @Entry internal var analysisRunningGameID: PersistentIdentifier?
}

// MARK: Running Gear

/// The badgeless gear, turning — the app's one spelling of "work is happening
/// right now", drawn by two surfaces that must not disagree.
///
/// Extracted 6 Aug 2026, when the Library toolbar's queue item replaced its
/// `ProgressView` with this and became the second drawer. The symbol name and
/// the effect had to travel together: `AnalysisGlyph.name(.analyzing)` alone
/// would have left each site choosing its own motion, and **the motion is the
/// part still under question** (see below). When the answer lands it should land
/// once, which is what this type buys.
///
/// **`.symbolEffect(.rotate)` is confirmed to turn `gear`** — 6 Aug 2026, a live
/// batch. What is *not* confirmed is that it repeats: the first field run had a
/// state bug pulling the glyph out from under the effect, so "stopped spinning"
/// and "stopped being a gear" were one event and could not be separated. With
/// that fixed the question is isolated and sits on the manual-check list.
/// `.repeat(.continuous)` is the explicit request for indefinite playback; if it
/// turns out to rotate once and stop, the replacement is a `.rotationEffect`
/// driven by a repeating animation, which moves any view — **and it belongs
/// here, in this one body.**
///
/// No foreground style, deliberately: a running pass has no verdict to report,
/// and the two surfaces that draw this sit in different chrome (a toolbar
/// button, a `Label`'s icon slot). Inheriting is the only thing that is right in
/// both. `AnalysisLabel.icon` carries the longer form of that argument.
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
    internal let state: AnalysisGlyph.State

    /// The title defaults to `AnalysisGlyph.actionTitle`, so the action
    /// sites read the same word without restating the switch. The token
    /// chips pass their own, because "Not Analyzed" is a filter's name rather
    /// than a verb.
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

    /// Two arrangements, and the branch is `tint`'s optional rather than a
    /// second switch on the state — one source deciding both the colour and
    /// whether there is one to apply.
    ///
    /// **The running gear takes no foreground style at all.** Not `.primary`,
    /// which would override a host that supplies its own foreground (a
    /// `.borderedProminent` button, a selected row); not palette with a third
    /// hue, which would put a colour on a state that has no verdict to report.
    /// It renders exactly as the plain glyphs beside it do.
    ///
    /// The motion lives in `AnalyzingGear` rather than here, because the Library
    /// toolbar's queue item draws the same turning gear and the two must not
    /// choose their own animations. Its doc carries what is and is not known
    /// about `.symbolEffect(.rotate)`.
    ///
    /// Worth one line where it will be read: **macOS ignores symbol effects in
    /// menu items**, so this menu's copy is a still gear by construction. The
    /// design absorbs that without a second edit — the badgeless silhouette is
    /// already distinct from both badged forms, so a still gear is a legible
    /// state and only a duller one.
    @ViewBuilder
    private var icon: some View {
        if let tint = AnalysisGlyph.tint(state) {
            Image(systemName: AnalysisGlyph.name(state))
                .symbolRenderingMode(.palette)
                .foregroundStyle(tint, .foreground)
        } else {
            AnalyzingGear()
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
//
// **The same applies to the spin** (6 Aug 2026). A menu item is the clearest
// case — `NSMenuItem` takes an image, not a running animation — so the context
// menu's Analyze row shows a still gear while the Library toolbar's queue item
// turns, and that is the framework rather than a bug to chase. (This said "the
// toolbar's" meaning the Analyze *button*, which was removed hours later; the
// queue item is the surface that spins now.) Absorbed by the same property that
// absorbs the palette being ignored: the three states are three *silhouettes*
// before any motion or colour is applied, so every surface reads correctly with
// the effect doing nothing. Whether it repeats is `AnalyzingGear`'s open
// question, and the one place a fix would land.

// MARK: Previews

/// The defect this type exists to prevent is **visual and nothing else** — a
/// tint leaking from the symbol onto the word beside it — so a preview is not
/// a nicety here, it is the only witness that can fail. Neither the compiler
/// nor a unit test can see a green "Analyze".
///
/// Every state, both title forms, on one canvas: the claim is that all six
/// titles render in the *default* foreground while the badges differ. If the
/// modifier this replaced ever comes back, two of these words turn colour and
/// the rows beside them stay put, which is what makes the pairing worth the
/// space.
///
/// The counted plural is here rather than only at the call site because it is
/// the form where the leak was most visible — a long green string rather than
/// one word.
///
/// **The `.analyzing` row is also the only witness the spin has.** A canvas
/// runs symbol effects, so this is where "does `gear` actually rotate" gets
/// answered — the question `AnalysisLabel.icon` records and declines to assert.
/// Watch this row for a second; a still gear is the "no" and sends you to the
/// `.rotationEffect` fallback named there.
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

/// The running gear inside the two hosts that supply their own foreground, and
/// the reason `icon` leaves it unstyled.
///
/// A `.primary` or a third palette hue reads fine on the plain row above and
/// wrong in both of these: a prominent button paints its label white, and a
/// selected row inverts. The claim is that the spinning gear matches the "Open"
/// glyph beside it in every one of these contexts, which is only checkable by
/// putting them side by side.
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
