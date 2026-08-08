import Testing
import Foundation
import SwiftData
import SwiftUI
@testable import DGTStudioPro

/// Pins `AnalysisGlyph.State` and the one rule that produces it.
///
/// **This suite closes a written waiver.** The register carried `AnalysisGlyph`
/// as "three static one-liners: a predicate and two symbol-name mappings",
/// witnessed by the sites that render it, with a suite named as the preferred
/// close. It stopped being one-liners on 6 Aug 2026: the glyph now folds a
/// stored array *and* live queue state through an ordering, and the ordering is
/// the whole content.
///
/// **The defect these were written from.** `isAnalyzed` is true for any single
/// scored ply, and `GameAnalysisDriver` records plies as the walk advances — so
/// a game turned green at ply one and stayed green for the rest of its own
/// analysis. Every assertion below that mentions `.analyzing` fails under the
/// old `analyzed: Bool` rule, which is the property that makes them checks
/// rather than decoration.
///
/// `@MainActor`: these front realized `@Model`s out of a `ModelContext`, same
/// as the other store-adjacent suites. The rule itself is nonisolated and no
/// claim is made about reaching it from elsewhere — every caller is a view.
@MainActor
@Suite("Analysis Glyph — State")
struct AnalysisGlyphStateTests {

    // MARK: Helpers

    private static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: PGN.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// A three-ply game, inserted so it carries a real `PersistentIdentifier`.
    ///
    /// `scored` is how many of its plies carry an evaluation, counted from the
    /// front — which is how a pass in flight leaves the array, and therefore
    /// the shape the running-wins rule has to survive. `scored: 0` yields the
    /// all-nil non-empty array the type doc calls out as the case a bare
    /// `isEmpty` check answers wrongly.
    private static func game(
        in context: ModelContext,
        named name: String,
        scored: Int
    ) -> PGN {
        let moves = ["e4", "e5", "Nf3"]
        let pgn = PGN(
            white: "Alice",
            black: "Bob",
            moves: moves,
            evaluations: (0..<moves.count).map { index in
                index < scored ? Evaluation.centipawns(20 * (index + 1)) : nil
            },
            name: name
        )
        context.insert(pgn)
        return pgn
    }

    // MARK: Running Wins

    /// **The reported defect, pinned.** A game part-way through its pass has a
    /// partial array, and the array alone says "analyzed".
    @Test("A game on the engine reads analyzing, however much of it is scored")
    func runningBeatsAPartialArray() throws {
        let context = try Self.makeContext()
        let pgn = Self.game(in: context, named: "In Flight", scored: 1)

        #expect(AnalysisGlyph.isAnalyzed(pgn))
        #expect(
            AnalysisGlyph.state(of: [pgn], runningID: pgn.persistentModelID) == .analyzing
        )
    }

    /// The same at the far end of the walk: a fully scored game still on the
    /// engine has not finished until the queue says so. Without this, the badge
    /// would flip green on the last ply instead of at the drain — a smaller
    /// version of the same lie.
    @Test("A fully scored game still on the engine reads analyzing")
    func runningBeatsAFullArray() throws {
        let context = try Self.makeContext()
        let pgn = Self.game(in: context, named: "Nearly Done", scored: 3)

        #expect(
            AnalysisGlyph.state(of: [pgn], runningID: pgn.persistentModelID) == .analyzing
        )
    }

    /// Running is about *this* game, not about the engine being busy. A game
    /// waiting in line while another runs reads unanalyzed — D-less by
    /// decision, and the case the type doc declines to give a fourth state.
    @Test("Another game running leaves this one alone")
    func aDifferentRunningGameDoesNotClaimThisOne() throws {
        let context = try Self.makeContext()
        let waiting = Self.game(in: context, named: "Waiting", scored: 0)
        let running = Self.game(in: context, named: "Running", scored: 1)

        #expect(
            AnalysisGlyph.state(of: [waiting], runningID: running.persistentModelID)
                == .unanalyzed
        )
    }

    // MARK: The Array, With Nothing Running

    @Test("Scored plies and an idle queue read analyzed")
    func scoredAndIdleReadsAnalyzed() throws {
        let context = try Self.makeContext()
        let pgn = Self.game(in: context, named: "Done", scored: 3)

        #expect(AnalysisGlyph.state(of: [pgn], runningID: nil) == .analyzed)
    }

    /// A non-empty all-nil array is the case `!evaluations.isEmpty` answers
    /// wrongly — the latent fork this type was extracted to close, still closed.
    @Test("A non-empty all-nil array reads unanalyzed")
    func allNilReadsUnanalyzed() throws {
        let context = try Self.makeContext()
        let pgn = Self.game(in: context, named: "Reset", scored: 0)

        #expect(!pgn.evaluations.isEmpty)
        #expect(AnalysisGlyph.state(of: [pgn], runningID: nil) == .unanalyzed)
    }

    /// A partial array with nothing running still reads analyzed — the skipped
    /// or cancelled batch. Deliberate rather than overlooked: coverage is Get
    /// Info's "48 of 58" row, not the glyph's. Pinned so a future pass that
    /// wants to change it has to say so out loud.
    @Test("A partial array with an idle queue reads analyzed, not partial")
    func partialAndIdleReadsAnalyzed() throws {
        let context = try Self.makeContext()
        let pgn = Self.game(in: context, named: "Skipped", scored: 1)

        #expect(AnalysisGlyph.state(of: [pgn], runningID: nil) == .analyzed)
    }

    // MARK: Aggregate

    @Test("One unanalyzed game makes the whole set unanalyzed")
    func allOrNothingOverASet() throws {
        let context = try Self.makeContext()
        let done = Self.game(in: context, named: "Done", scored: 3)
        let alsoDone = Self.game(in: context, named: "Also Done", scored: 2)
        let notDone = Self.game(in: context, named: "Not Done", scored: 0)

        #expect(AnalysisGlyph.state(of: [done, alsoDone], runningID: nil) == .analyzed)
        #expect(AnalysisGlyph.state(of: [done, notDone], runningID: nil) == .unanalyzed)
    }

    /// Running beats all-satisfy, which is the ordering stated as a test: every
    /// other game in the selection is finished, so the array-first reading
    /// would report the batch complete while it is still running.
    @Test("Running wins over a set that is otherwise fully analyzed")
    func runningWinsOverAnOtherwiseCompleteSet() throws {
        let context = try Self.makeContext()
        let done = Self.game(in: context, named: "Done", scored: 3)
        let running = Self.game(in: context, named: "Running", scored: 2)

        #expect(
            AnalysisGlyph.state(of: [done, running], runningID: running.persistentModelID)
                == .analyzing
        )
    }

    /// The emptiness guard that used to live at the toolbar and be absent from
    /// the context menu — safe there only because a branch above established
    /// non-emptiness. Folded into the rule, so both sites now get it whether or
    /// not they remember to.
    @Test("An empty selection reads unanalyzed rather than vacuously analyzed")
    func anEmptySetIsNotAnalyzed() {
        #expect(AnalysisGlyph.state(of: [], runningID: nil) == .unanalyzed)
    }

    // MARK: Membership Is Asked Of The Games Passed In

    /// **The shipped bug, kept as a pin on the rule that replaced the fix.**
    ///
    /// The Library toolbar's Analyze button resolved its selection through
    /// `filteredGames`, so with the Not Analyzed chip active the running game
    /// left the rendered list the moment its first ply was scored, and the glyph
    /// fell back to the red x mid-batch while the engine worked on. A
    /// selection-scoped overload comparing ids fixed it; the button was removed
    /// by request hours later and took the overload with it.
    ///
    /// What survives is a **constraint on callers**, and this is where it is
    /// checkable: a game absent from `games` is not running as far as this rule
    /// is concerned, whatever the queue is doing. That is correct for the two
    /// live callers — a row menu and a detail pane both hold what they draw —
    /// and it is a trap for any future aggregate caller, which is why the
    /// assertion is phrased as the trap rather than as the fix.
    @Test("A running game absent from the games passed in does not read analyzing")
    func membershipIsDecidedByTheGamesPassedIn() throws {
        let context = try Self.makeContext()
        let running = Self.game(in: context, named: "Running", scored: 1)
        let visible = (0..<3).map {
            Self.game(in: context, named: "Visible \($0)", scored: 0)
        }

        #expect(
            AnalysisGlyph.state(of: visible, runningID: running.persistentModelID)
                == .unanalyzed
        )
        #expect(
            AnalysisGlyph.state(
                of: visible + [running],
                runningID: running.persistentModelID
            ) == .analyzing
        )
    }

    // MARK: Presentation

    /// Three states, three symbols. The distinctness is the claim — a state
    /// sharing a silhouette with another is invisible on the surfaces where
    /// neither colour nor motion survives (menus), which is exactly where the
    /// glyph is most often read.
    @Test("Every state has its own symbol")
    func symbolsAreDistinct() {
        let names = [AnalysisGlyph.State.unanalyzed, .analyzing, .analyzed]
            .map(AnalysisGlyph.name)

        #expect(Set(names).count == names.count)
        #expect(AnalysisGlyph.name(.analyzing) == "gear")
    }

    /// The badge vocabulary (D72′ postscript): plain marks, distinct, and the
    /// running state is the **same bare gear** as the action vocabulary — one
    /// silhouette for "the engine has this one" everywhere it appears, which
    /// is the sentence that keeps two vocabularies from being two opinions.
    @Test("Badge symbols are plain marks sharing only the running gear")
    func badgeSymbolsArePlainMarksSharingTheGear() {
        let names = [AnalysisGlyph.State.unanalyzed, .analyzing, .analyzed]
            .map(AnalysisGlyph.badgeName)

        #expect(Set(names).count == names.count)
        #expect(AnalysisGlyph.badgeName(.analyzing) == AnalysisGlyph.name(.analyzing))
        #expect(!AnalysisGlyph.badgeName(.analyzed).contains("gear"))
        #expect(!AnalysisGlyph.badgeName(.unanalyzed).contains("gear"))
    }

    /// The badgeless state takes no tint, and the two verdicts do. Asserted as
    /// nil-ness rather than against `.red` / `.green` so the colours stay a
    /// design choice; what is pinned is that a running pass reports no verdict,
    /// which is what `AnalysisLabel` branches on to leave it unstyled.
    @Test("Only the two verdict states carry a tint")
    func onlyVerdictsAreTinted() {
        #expect(AnalysisGlyph.tint(.analyzing) == nil)
        #expect(AnalysisGlyph.tint(.unanalyzed) != nil)
        #expect(AnalysisGlyph.tint(.analyzed) != nil)
    }

    @Test("Every state has its own action title")
    func actionTitlesAreDistinct() {
        let titles = [AnalysisGlyph.State.unanalyzed, .analyzing, .analyzed]
            .map(AnalysisGlyph.actionTitle)

        #expect(Set(titles).count == titles.count)
    }

    /// The badge's passive vocabulary, distinct per state like the action
    /// titles — and "Not Analyzed" verbatim, because it is the chip
    /// (`LibrarySearchToken.unanalyzed`) that finds the games wearing it, and
    /// a badge and its filter drifting apart is two names for one state.
    @Test("Every state has its own status label, and the negative matches the chip")
    func statusLabelsAreDistinctAndChipAligned() {
        let labels = [AnalysisGlyph.State.unanalyzed, .analyzing, .analyzed]
            .map(AnalysisGlyph.statusLabel)

        #expect(Set(labels).count == labels.count)
        #expect(AnalysisGlyph.statusLabel(.unanalyzed) == LibrarySearchToken.unanalyzed.displayName)
    }

    // MARK: The Projection Overload (D72′)

    /// The row badges read `state(of:isAnalyzed:runningID:)`, with
    /// `isAnalyzed` off the memoized `GameRecord` projection instead of the
    /// model — so the two overloads answering identically is the whole claim,
    /// and it is checked across every combination that could split them:
    /// scored and unscored arrays, running and not.
    ///
    /// Driven through `\.gameRecord` — the projection the destinations
    /// actually feed the badges — rather than hand-passed booleans, so this
    /// fails if `hasAnalysis` and `hasScoredPly` ever stop being one spelling.
    @Test("The projection overload agrees with the model overload")
    func theProjectionOverloadAgreesWithTheModelOverload() throws {
        let context = try Self.makeContext()
        let games = [
            Self.game(in: context, named: "None", scored: 0),
            Self.game(in: context, named: "Partial", scored: 1),
            Self.game(in: context, named: "Full", scored: 3),
        ]

        for game in games {
            for running in [nil, game.persistentModelID, games[0].persistentModelID] {
                #expect(
                    AnalysisGlyph.state(
                        of: game,
                        isAnalyzed: game.gameRecord.hasAnalysis,
                        runningID: running
                    )
                    == AnalysisGlyph.state(of: [game], runningID: running)
                )
            }
        }
    }

    /// Running wins in the projection overload too, whatever the projected
    /// flag claims — the badge on a card mid-pass shows the gear, not the
    /// verdict the half-written array would justify.
    @Test("Running beats the projected flag in the per-row overload")
    func runningBeatsTheProjectedFlag() throws {
        let context = try Self.makeContext()
        let pgn = Self.game(in: context, named: "In Flight", scored: 2)

        #expect(
            AnalysisGlyph.state(
                of: pgn,
                isAnalyzed: true,
                runningID: pgn.persistentModelID
            ) == .analyzing
        )
        #expect(
            AnalysisGlyph.state(of: pgn, isAnalyzed: true, runningID: nil) == .analyzed
        )
        #expect(
            AnalysisGlyph.state(of: pgn, isAnalyzed: false, runningID: nil) == .unanalyzed
        )
    }
}
