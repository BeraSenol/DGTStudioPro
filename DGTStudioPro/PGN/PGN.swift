import Foundation
import SwiftData

enum GameResult: String, CaseIterable, Codable {
    case whiteWins = "1-0"
    case blackWins = "0-1"
    case draw      = "1/2-1/2"
    case ongoing   = "*"
}

enum SevenTagRoster: String, CaseIterable, Sendable {
    case event  = "Event"
    case site   = "Site"
    case date   = "Date"
    case round  = "Round"
    case white  = "White"
    case black  = "Black"
    case result = "Result"
}

@Model
final class PGN: Identifiable {
    
    // MARK: Stored Properties
    var event: String
    var site: String
    var date: Date?
    var round: Int?
    var white: String
    var black: String
    var result: GameResult
    var timeControl: String?
    
    /// The `Board` tag — "DGT 3000448278". Deliberately **outside the content hash** (like
    /// `timeControl`): equipment, not game — folding it in would rot every stored hash.
    var board: String?
    
    var moves: [String]
    
    /// Evaluations parallel to `moves`, indexed by ply: `evaluations[i]` scores the position after
    /// `moves[i]` (the `[%eval]` convention). Invariant: empty, or exactly `moves.count` long.
    var evaluations: [Evaluation?] = []

    /// The search depth each evaluation was produced at, parallel to `evaluations`: empty,
    /// or exactly `moves.count` long. What makes the book skip and incremental deepening provable
    /// rather than guessed — a ply scored at ≥ the target depth is kept, never re-searched.
    var analysisDepths: [Int?] = []
    
    // MARK: Classification

    /// ECO code — `"C60"` — or nil (unnamed line, or unbackfilled pre-M4 row). All four
    /// classification fields are derived truth: outside the content hash, absent from `init`
    /// (`PGNStore.classify` is the single write door), never exported.
    var ecoCode: String?

    /// The opening family — the short form the Library column shows.
    var ecoFamily: String?

    /// Everything after the family, or nil for a bare family line. Spelled `ecoFamily`/`ecoVariation`
    /// so the model and `ECOOpening` cannot drift about which half is which.
    var ecoVariation: String?

    /// The matched book prefix in plies, stamped with the rest of the classification —
    /// nil exactly when the opening is. The analysis pass starts searching here.
    var ecoDepth: Int?

    /// The recognised checkmate type, or nil (ordinary mate, unfinished, unwalkable movetext).
    var specialCheckmate: SpecialCheckmate?

    var name: String = ""
    var importedAt: Date
    var contentHash: String

    /// The ordinal the file carries on disk — the `47` in `47. ….pgn`. **The weaker of two
    /// identities**: `contentHash` decides what is the same game; this is filing. Outside the hash,
    /// necessarily — two copies under different numbers still dedupe. Nil is a real answer: nothing
    /// to backfill it from.
    var libraryIndex: Int?
    
    /// Resolved player links, maintained exclusively by `PGNStore` — absent from `init` (a link
    /// assigned outside the store bypasses the one creation door).
    var whitePlayer: Player?
    var blackPlayer: Player?
    
    // MARK: Computed Properties
    var id: PersistentIdentifier { persistentModelID }
    
    var displayDate: String {
        RosterSummary.displayDate(date)
    }
    
    var displayRound: String {
        RosterSummary.displayRound(round)
    }
    
    var whiteDisplayName: String {
        PlayerName.displayForm(of: white)
    }
    
    var blackDisplayName: String {
        PlayerName.displayForm(of: black)
    }

    /// Stored classification rehydrated. Requiring both code and family is an invariant check, not
    /// defensive nil-handling — both were written from one `ECOOpening`.
    var opening: ECOOpening? {
        guard let ecoCode, let ecoFamily else { return nil }
        return ECOOpening(code: ecoCode, family: ecoFamily, variation: ecoVariation)
    }
    
    /// The one construction of the default name — `init`'s fallback and `nameIsStaleDefault` must
    /// agree byte for byte, or the backfill rewrites every game on every Library appearance.
    static func defaultName(white: String, black: String) -> String {
        "\(PlayerName.displayForm(of: white)) vs \(PlayerName.displayForm(of: black))"
    }
    
    /// Default `name` in display form — new imports and the backfill comparison.
    var defaultDisplayName: String {
        Self.defaultName(white: white, black: black)
    }
    
    /// True only when the rewrite would change the value — an empty name, or a legacy raw-tag
    /// default whose display transform differs.
    static func nameIsStaleDefault(
        storedName: String, white: String, black: String
    ) -> Bool {
        let legacyDefault = "\(white) vs \(black)"
        let displayDefault = defaultName(white: white, black: black)
        return (storedName.isEmpty || storedName == legacyDefault)
        && storedName != displayDefault
    }
    
    /// Instance form for the backfill's filter.
    var hasStaleDefaultName: Bool {
        Self.nameIsStaleDefault(storedName: name, white: white, black: black)
    }
    
    /// Any ply carries an evaluation — the app's one spelling of "is there analysis to show?".
    /// `!evaluations.isEmpty` is a different question: true of an all-nil array, which drew a
    /// fabricated 50/50 bar for a pass that scored nothing.
    var hasScoredPly: Bool {
        evaluations.contains { $0 != nil }
    }

    // MARK: Instance Methods
    /// Evaluation after the move at `ply`, or nil — safe against both invariant shapes.
    func evaluation(atPly ply: Int) -> Evaluation? {
        guard ply >= 0, ply < evaluations.count else { return nil }
        return evaluations[ply]
    }
    
    // MARK: Initializers
    init(
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
