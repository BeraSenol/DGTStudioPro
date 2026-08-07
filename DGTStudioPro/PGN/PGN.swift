import Foundation
import SwiftData

internal enum GameResult: String, CaseIterable, Codable {
    case whiteWins = "1-0"
    case blackWins = "0-1"
    case draw      = "1/2-1/2"
    case ongoing   = "*"
}

internal enum SevenTagRoster: String, CaseIterable, Sendable {
    case event  = "Event"
    case site   = "Site"
    case date   = "Date"
    case round  = "Round"
    case white  = "White"
    case black  = "Black"
    case result = "Result"
}

@Model
internal final class PGN: Identifiable {
    
    // MARK: Stored Properties
    internal var event: String
    internal var site: String
    internal var date: Date?
    internal var round: Int?
    internal var white: String
    internal var black: String
    internal var result: GameResult
    internal var timeControl: String?
    
    /// The `Board` tag the DGT exports carry — "DGT 3000448278", the serial
    /// the board reports during the init handshake. Optional, and
    /// deliberately **outside the content hash** (like `timeControl`): it
    /// identifies the equipment, not the game, so the same game imported
    /// from two boards must still dedupe — and folding it in would rot every
    /// stored hash in place. Supplied by imports and — since M2 (D28′) — by
    /// the archive door, from the identity `startNewGame` stamped onto the
    /// roster at game start. Nil on pre-M2 archives and boardless games.
    internal var board: String?
    
    internal var moves: [String]
    
    /// Engine evaluations parallel to ``moves``, indexed by ply. The element
    /// at index `i` is the evaluation of the position reached *after*
    /// `moves[i]` is played — matching the Lichess / Chess.com `[%eval ...]`
    /// PGN convention where the comment follows the move it scored.
    ///
    /// Invariant: this array is either empty (no analysis has ever been
    /// recorded for this game) or exactly the same length as ``moves``.
    /// Individual entries may be `nil` for plies that weren't analyzed.
    /// Use ``evaluation(atPly:)`` to read safely against both shapes.
    internal var evaluations: [Evaluation?] = []
    
    // MARK: Classification (D19′, D34′, D35′)

    /// The ECO volume code of the game's opening — `"C60"` — or nil for a
    /// game whose line the bundled table doesn't name, and for every row
    /// that predates M4 until the backfill reaches it.
    ///
    /// All four classification fields are **derived truth**, not interchange:
    /// they are computed from `moves` by `GameClassification`, so they are
    /// deliberately outside the content hash (a game and its re-classified
    /// self are the same game) and deliberately **absent from `init`** — the
    /// `whitePlayer`/`blackPlayer` precedent. A caller that could set them
    /// directly would be a second classification door, and the first thing
    /// it would do is disagree with the first door.
    ///
    /// Nil is a real answer here, not just an unmigrated state: an unplayed
    /// game, an unnamed line, and a game that ended in an ordinary mate all
    /// legitimately classify nil. Nothing may read nil as "needs work" except
    /// `PGNStore.backfillClassifications()`, which accepts re-asking a game
    /// that will answer nil again as the price of not storing a third state.
    internal var ecoCode: String?

    /// The opening family — `"Ruy Lopez"`, the short form the Library column
    /// shows. Split from the source name at classification time (D35′).
    internal var ecoFamily: String?

    /// Everything after the family — `"Morphy Defense, Modern Steinitz
    /// Defense"` — or nil for a bare family line. The roadmap called this
    /// pair `ecoName`; it is spelled `ecoFamily`/`ecoVariation` so the model
    /// and `ECOOpening` cannot drift about which half of the name is which.
    internal var ecoVariation: String?

    /// The recognised checkmate type the game ended on, or nil for an
    /// ordinary mate, an unfinished game, or a movetext the replayer can't
    /// walk. Surfaced only through smart-tag filtering by decision — the
    /// seeded "Smothered mates" tag is its shop window.
    internal var specialCheckmate: SpecialCheckmate?

    internal var name: String = ""
    internal var importedAt: Date
    internal var contentHash: String

    /// The ordinal this game's PGN file carries on disk — the `47` in
    /// `47. Bera Senol vs Christophe Heylen.pgn` (D58′).
    ///
    /// **A second identity, and deliberately the weaker one.** `contentHash` is
    /// what the app dedupes, links and reasons with; this is a human's filing
    /// number, read off the filename at import rather than assigned here. That
    /// direction is the whole decision: the folder on disk was numbering these
    /// games before this app existed, so inventing a parallel numbering would
    /// give one game two ordinals and make the app's the wrong one.
    ///
    /// Optional and often nil: a game pasted as text, dropped from a folder
    /// that does not follow the convention, or imported before D58′ has no
    /// ordinal to read and keeps none. Nil is a real answer, not an unmigrated
    /// state — there is nothing to backfill it *from*, because the app never
    /// stored the URL it imported through.
    ///
    /// **Outside the content hash, necessarily.** Two copies of one game filed
    /// under different numbers are the same game, and folding this in would
    /// un-dedupe the archive against itself — the `board` and `timeControl`
    /// argument, with a sharper edge, since this value is *about* the filing
    /// rather than about the play. Absent from `init` for the reason the
    /// classification fields are: the doors assign it, and a caller that could
    /// set it directly would be a second numbering.
    ///
    /// Not unique, and not enforced as such. Two files can legitimately carry
    /// the same ordinal (two folders, two numbering runs), and refusing that
    /// would make an import fail over a filename while the game itself is fine.
    internal var libraryIndex: Int?
    
    /// Resolved player identities for the `white`/`black` tags (M-prs.1),
    /// maintained exclusively by `PGNStore` — both doors, the backfill,
    /// and `applyEdit`. Optional because `"?"` placeholders resolve to no
    /// player, and rows predating the schema start nil until backfilled.
    /// Deliberately absent from `init`: a link assigned anywhere but the
    /// resolver would bypass the single creation door. Sibling of the
    /// one-hash rule: any edit to `white`/`black` outside
    /// `PGNStore.applyEdit` silently rots these links.
    internal var whitePlayer: Player?
    internal var blackPlayer: Player?
    
    // MARK: Computed Properties
    internal var id: PersistentIdentifier { persistentModelID }
    
    internal var displayDate: String {
        RosterSummary.displayDate(date)
    }
    
    internal var displayRound: String {
        RosterSummary.displayRound(round)
    }
    
    internal var whiteDisplayName: String {
        PlayerName.displayForm(of: white)
    }
    
    internal var blackDisplayName: String {
        PlayerName.displayForm(of: black)
    }

    /// The stored classification rehydrated into the value the surfaces and
    /// `TagRule` actually want.
    ///
    /// Requiring *both* code and family is an invariant check, not defensive
    /// nil-handling: `PGNStore.classify` writes the three columns together
    /// from one `ECOOpening`, so a row with one and not the other could only
    /// come from a second writer — and this returning nil is how that shows
    /// up as "unclassified" rather than as a half-built opening.
    internal var opening: ECOOpening? {
        guard let ecoCode, let ecoFamily else { return nil }
        return ECOOpening(code: ecoCode, family: ecoFamily, variation: ecoVariation)
    }
    
    /// The one construction of a game's default name. `init`'s fallback and
    /// `nameIsStaleDefault`'s comparison each built this string separately
    /// and have to agree byte for byte: if they drift, `hasStaleDefaultName`
    /// is true forever and `backfillEmptyNames` rewrites and saves every game
    /// on every Library appearance — the shape of the 20 July field finding
    /// documented below.
    internal static func defaultName(white: String, black: String) -> String {
        "\(PlayerName.displayForm(of: white)) vs \(PlayerName.displayForm(of: black))"
    }
    
    /// Default `name` for a game with these players, in display form.
    /// Used both for new imports and the backfill comparison.
    internal var defaultDisplayName: String {
        Self.defaultName(white: white, black: black)
    }
    
    /// Whether `name` is a **stale stored default** that should be rewritten
    /// to `defaultDisplayName`. True only when the rewrite would change the
    /// value: an empty name, or a legacy raw-tag default whose display
    /// transform differs. Deliberately false when `name` already equals
    /// `defaultDisplayName` even if it also equals the legacy form — for
    /// comma-free players the raw and display forms coincide, so the old
    /// `name == legacyDefaultName` test false-positived on every freshly
    /// archived game (the archive door stores `defaultDisplayName`), logging
    /// a spurious backfill and dirtying the context with a no-op save (the
    /// 20 July field finding). Custom names match neither branch and survive.
    internal static func nameIsStaleDefault(
        storedName: String, white: String, black: String
    ) -> Bool {
        let legacyDefault = "\(white) vs \(black)"
        let displayDefault = defaultName(white: white, black: black)
        return (storedName.isEmpty || storedName == legacyDefault)
        && storedName != displayDefault
    }
    
    /// Instance form for the Library backfill's `filter(\.hasStaleDefaultName)`.
    internal var hasStaleDefaultName: Bool {
        Self.nameIsStaleDefault(storedName: name, white: white, black: black)
    }
    
    /// Whether any ply carries an engine evaluation — the app's one spelling
    /// of "is there analysis to show?".
    ///
    /// **`!evaluations.isEmpty` is a different question and was being asked
    /// in its place** (7 Aug 2026). `GameAnalysisDriver` resets the array to
    /// `Array(repeating: nil, count: moves.count)` *before* it walks, so a
    /// pass that starts and scores nothing leaves a full-length, all-nil
    /// array. That array is not empty, and it contains no analysis. Every
    /// surface that consumed it drew the `?? 0.5` fallback at every ply —
    /// a curve lying exactly on the 50/50 midline `EvaluationGraphView`
    /// strokes unconditionally, which reads as a flat line and no data, and
    /// which is a fabricated reading rather than a missing one.
    ///
    /// The distinction is invisible until it fires, and then it is
    /// **actively misleading**: the failure presents as a drawing bug on a
    /// game the app is simultaneously calling analyzed, which sends a reader
    /// to the chart code instead of to the engine log.
    ///
    /// Lives on `PGN` rather than on `AnalysisGlyph`, where the correct
    /// spelling already existed, because the question belongs to the game
    /// rather than to the Library's icon — D25′'s rule that a value with an
    /// owning type should live on it, and D64′'s that a thing consumed by
    /// Board *and* Library *and* Get Info is not the Library's. The glyph
    /// forwards here now, the way `LiveGame.Roster.seatsNameOnePlayer`
    /// forwards to `Player`'s.
    internal var hasScoredPly: Bool {
        evaluations.contains { $0 != nil }
    }

    // MARK: Instance Methods
    /// Returns the evaluation recorded for the position reached after the
    /// move at `ply` is played, or `nil` if no analysis is present for
    /// that ply. Safe against both invariant shapes of ``evaluations`` —
    /// returns `nil` when the array is empty (no analysis ever run) or
    /// when the entry at that index is itself `nil`.
    internal func evaluation(atPly ply: Int) -> Evaluation? {
        guard ply >= 0, ply < evaluations.count else { return nil }
        return evaluations[ply]
    }
    
    // MARK: Initializers
    internal init(
        event: String = RosterSummary.unknownTag,
        site: String = RosterSummary.unknownTag,
        date: Date? = nil,
        round: Int? = nil,
        white: String = RosterSummary.unknownTag,
        black: String = RosterSummary.unknownTag,
        moves: [String] = [],
        evaluations: [Evaluation?] = [],
        name: String? = nil,
        result: GameResult = .ongoing,
        timeControl: String? = nil,
        board: String? = nil,
        contentHash: String = ""
    ) {
        self.event = event
        self.site = site
        self.date = date
        self.round = round
        self.white = white
        self.black = black
        self.result = result
        self.timeControl = timeControl
        self.board = board
        self.moves = moves
        self.evaluations = evaluations
        self.name = name ?? Self.defaultName(white: white, black: black)
        self.importedAt = .now
        self.contentHash = contentHash
    }
}
