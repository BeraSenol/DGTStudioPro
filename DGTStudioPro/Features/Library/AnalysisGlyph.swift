import SwiftData
import SwiftUI

/// The analysis-state glyph: gear + checkmark analyzed, + xmark not, bare while the engine has
/// it. One home for symbol and tint; the predicate lives on `PGN.hasScoredPly`.
enum AnalysisGlyph {
    
    // MARK: State
    
    /// Three states, not a `Bool`: `isAnalyzed` is true for any scored ply and the driver writes
    /// plies as it walks, so a `Bool` went green at ply one.
    enum State: Equatable {
        /// Nothing scored, nothing working on it. Queued games sit here too.
        case unanalyzed
        /// On the engine now. Beats the array, which is mid-write underneath.
        case analyzing
        /// A pass left evaluations, nothing running. Says nothing about *coverage* — the Analysis Data
        /// window's per-ply rows are where that shows.
        case analyzed
    }
    
    /// "Has been analyzed", spelled once — forwards to `PGN`, which owns the question.
    static func isAnalyzed(_ game: PGN) -> Bool {
        game.hasScoredPly
    }
    
    /// The glyph's state for the rendered games. Running wins, then all-or-nothing (mixed selections
    /// read unanalyzed, so the action stays offerable). **Membership is asked of `games`, so `games`
    /// must be the caller's real subject, not a list something else can narrow.**
    static func state(
        of games: [PGN],
        runningID: PersistentIdentifier?
    ) -> State {
        if let runningID, games.contains(where: { $0.persistentModelID == runningID }) {
            return .analyzing
        }
        return !games.isEmpty && games.allSatisfy(isAnalyzed) ? .analyzed : .unanalyzed
    }
    
    /// Per-row spelling off the memoized projection — exists so a row badge cannot cost a
    /// blob decode. A cache, not a second opinion (`hasAnalysis` is the same predicate).
    static func state(
        of game: PGN,
        isAnalyzed: Bool,
        runningID: PersistentIdentifier?
    ) -> State {
        if game.persistentModelID == runningID { return .analyzing }
        return isAnalyzed ? .analyzed : .unanalyzed
    }
    
    /// Bare `gear` while analyzing: a badge is a *verdict*, and three silhouettes stay legible where
    /// menus render monochrome templates.
    static func name(_ state: State) -> String {
        switch state {
        case .unanalyzed: "gear.badge.xmark"
        case .analyzing:  "gear"
        case .analyzed:   "gear.badge.checkmark"
        }
    }
    
    /// Corner-badge symbol — plain verdict marks, no gear (by request). The gear is
    /// shared for `.analyzing`, so "the engine has it" has one silhouette everywhere.
    static func badgeName(_ state: State) -> String {
        switch state {
        case .unanalyzed: "xmark.circle.fill"
        case .analyzing:  "gear"
        case .analyzed:   "checkmark.circle.fill"
        }
    }
    
    // MARK: Badge Tint
    
    /// Badge colour: green analyzed, red not, **nil while running** — no verdict to report. Here,
    /// not at render sites: a colour decided per site is the twin-read-site pattern with a `Color`.
    static func tint(_ state: State) -> Color? {
        switch state {
        case .unanalyzed: .red
        case .analyzing:  nil
        case .analyzed:   .green
        }
    }
    
    /// "Analyze", "Analyzing…", "Analyzed" — state over verb: the common reason to look is to find
    /// out whether it has been done.
    static func actionTitle(_ state: State) -> String {
        switch state {
        case .unanalyzed: "Analyze"
        case .analyzing:  "Analyzing…"
        case .analyzed:   "Analyzed"
        }
    }
    
    /// Status vocabulary ("Not Analyzed" …) for surfaces that state rather than act; matches
    /// `LibrarySearchToken.unanalyzed`'s chip so badge and filter speak alike.
    static func statusLabel(_ state: State) -> String {
        switch state {
        case .unanalyzed: "Not Analyzed"
        case .analyzing:  "Analyzing"
        case .analyzed:   "Analyzed"
        }
    }
}

// MARK: Ambient Queue State

extension EnvironmentValues {
    
    /// The game on the engine now, or nil — the app's first custom environment value. An id, not the
    /// controller: a leaf holding the controller could start work; a leaf holding an id can only compare.
    @Entry var analysisRunningGameID: PersistentIdentifier?
}

// MARK: Running Gear

/// The badgeless turning gear — one spelling of "working now" for the queue toolbar item and
/// `AnalysisLabel`. `.rotate` is confirmed to turn `gear`; that it *repeats* is not.
struct AnalyzingGear: View {
    
    var body: some View {
        Image(systemName: AnalysisGlyph.name(.analyzing))
            .symbolEffect(.rotate, options: .repeat(.continuous))
    }
}

// MARK: Label

/// Glyph beside title — badge tinted, spinning where bare, **the text left alone** in every case.
/// A view, not a modifier: the structure cannot be applied after the fact.
struct AnalysisLabel: View {
    
    let title: String
    let state: AnalysisGlyph.State
    
    /// Defaults to `actionTitle`; token chips pass their own — "Not Analyzed" is a filter's name, not a verb.
    init(state: AnalysisGlyph.State, title: String? = nil) {
        self.state = state
        self.title = title ?? AnalysisGlyph.actionTitle(state)
    }
    
    var body: some View {
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

/// The glyph alone. Palette arrangement scoped to the `Image`; the running gear takes **no**
/// foreground style — `.primary` would override a host supplying its own (prominent button, selected row).
struct AnalysisGlyphIcon: View {
    
    let state: AnalysisGlyph.State
    
    var body: some View {
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

/// The plain-mark icon behind both badge surfaces — one view so the two cannot pick different marks.
struct AnalysisBadgeIcon: View {
    
    let state: AnalysisGlyph.State
    
    var body: some View {
        if let tint = AnalysisGlyph.tint(state) {
            Image(systemName: AnalysisGlyph.badgeName(state))
                .foregroundStyle(tint)
        } else {
            AnalyzingGear()
        }
    }
}

// MARK: Status Badge

/// The corner badge, with a backing chip that is load-bearing: the card's white sheet would
/// swallow a bare glyph in dark mode. Status, not a control — swallows no clicks.
struct AnalysisStatusBadge: View {
    
    let state: AnalysisGlyph.State
    
    var body: some View {
        AnalysisBadgeIcon(state: state)
            .font(.title2)
            .background(.ultraThinMaterial, in: Circle())
            .allowsHitTesting(false)
            .accessibilityLabel(AnalysisGlyph.statusLabel(state))
    }
}

// Rendering notes: `.symbolRenderingMode(.palette)` + `.foregroundStyle(tint, .foreground)` on
// the `Image` is the only way to scope palette rendering; the badge is the FIRST layer in
// `gear.badge.checkmark`. Palette, not multicolor — multicolor is the symbol's own colours, not ours.

// MARK: Previews

/// The defect this type prevents is visual and nothing else — a tint leaking onto the word — so
/// this preview is the only witness that can fail. The `.analyzing` row is the spin's only witness.
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

/// Why `icon` leaves the gear unstyled: a prominent button paints its label white, and the gear
/// must match the glyph beside it — only checkable side by side.
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

/// The badge over the card's worst case (white sheet, both appearances) — why the chip exists;
/// only a canvas can answer it.
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
