import CryptoKit
import Foundation
import os
import SwiftData

// MARK: PGN Store

/// All Library persistence goes through here — import, archive, delete, and
/// the one-hash/two-doors `refreshHash`. `@MainActor` as a whole (July 2026
/// review): every method fronts the app's main-context `ModelContext`, and
/// the previous per-member annotations (`archive`, the nested
/// `Error`/`ArchiveResult`) understated that — the type was only ever safe
/// because a non-`Sendable` struct can't cross isolation, which is an
/// accident of shape, not a statement of intent. Nested types and members
/// now infer the isolation from the type.
@MainActor
internal struct PGNStore {
    
    // MARK: Static Constants
    private static let logger = AppLog.logger(.pgnstore)
    
    /// UTC Gregorian calendar backing the hash's date rendering.
    private static let hashCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
    
    /// Renders a date for the content hash. **Persistence contract**: every
    /// `contentHash` already stored in every Library was computed against
    /// this exact "yyyy.MM.dd"-in-UTC rendering (previously a shared
    /// `DateFormatter` with `en_US_POSIX`), so it must keep producing
    /// byte-identical output forever — or a migration must rewrite every
    /// stored hash, and dedupe silently rots in the meantime. Rendering via
    /// `DateComponents` instead of the formatter answers the July 2026
    /// review's concurrency question by removing the shared reference-type
    /// state entirely: `Calendar` is a `Sendable` value and the arithmetic
    /// is deterministic by construction. Internal (not private) so the pin
    /// test can hold the format without going through a full import.
    internal static func hashDateString(from date: Date) -> String {
        let parts = hashCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d.%02d.%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
    
    // MARK: Errors
    internal enum Error: Swift.Error {
        /// The imported text's content hash matches a game already in the
        /// Library. Carries the match's `PersistentIdentifier` plus its
        /// display name, rather than the `PGN` model itself: `Swift.Error`
        /// refines `Sendable`, and a live `@Model` never is. The name rides
        /// along because the import-status row titles duplicates with it
        /// (mirroring `.imported(name:)`) — carrying the `String` keeps the
        /// view free of SwiftData ID-resolution; the ID remains the handle
        /// for any future "reveal in Library" affordance.
        case duplicate(existingID: PersistentIdentifier, existingName: String)
        case missingRequiredTags(Set<String>)
        case malformedPGN(reason: String)
        case fileReadFailed(URL, underlying: Swift.Error)
        /// `archive(_:)` was handed a game whose result is still `*` —
        /// Decision #3: no ongoing game ever reaches the Library.
        case ongoingGame
    }
    
    /// What `archive(_:)` produced. Unlike import — where a hash match is
    /// an *error* (the user tried to add a game they already have) — a
    /// match on archive is *success* (requirement 8: the finished game is
    /// in the Library, which is all that was promised).
    internal struct ArchiveResult {
        /// The Library row the game landed on — fresh or pre-existing.
        internal let pgn: PGN
        /// True when an identical game was already stored.
        internal let deduplicated: Bool
    }
    
    // MARK: Stored Properties
    private let modelContext: ModelContext
    
    // MARK: Initializers
    internal init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: Instance Methods
    /// The text import door: parse, dedupe by content hash, insert.
    ///
    /// **Throws `Error.duplicate` naming the existing game rather than returning
    /// it** — worth reading off the declaration, because the name suggests
    /// otherwise and this project has recorded getting it wrong.
    ///
    /// `libraryIndex` is the ordinal the *file* carried, threaded from the URL
    /// door below (D58′). Nil here rather than derived: a game arriving as text
    /// has no filing number, and inventing one would put the app's numbering
    /// beside the folder's.
    @discardableResult
    internal func importPGN(text: String, libraryIndex: Int? = nil) throws -> PGN {
        let pgn = try parse(text)
        pgn.libraryIndex = libraryIndex
        let hash = Self.contentHash(for: pgn)
        
        if let existing = try existingPGN(withHash: hash) {
            Self.logger?.info(
                "Rejected duplicate: '\(pgn.name, privacy: .public)' matches existing '\(existing.name, privacy: .public)' hash=\(hash, privacy: .public)"
            )
            throw Error.duplicate(existingID: existing.persistentModelID, existingName: existing.name)
        }
        
        try insertNewGame(pgn, hash: hash)
        
        Self.logger?.info(
            "Imported: '\(pgn.name, privacy: .public)' \(pgn.white, privacy: .public) vs \(pgn.black, privacy: .public) [\(pgn.result.rawValue, privacy: .public)] plies=\(pgn.moves.count)"
        )
        
        return pgn
    }
    
    @discardableResult
    internal func importPGN(from url: URL) throws -> PGN {
        let text: String
        
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            Self.logger?.error("Failed to read PGN at \(url.path, privacy: .public)")
            throw Error.fileReadFailed(url, underlying: error)
        }
        
        // The one place the filename is in scope, which is why the ordinal is
        // read here and not deeper (D58′). `lastPathComponent`, not the whole
        // path: a folder called `2024. Tournaments` would otherwise number every
        // game inside it.
        return try importPGN(
            text: text,
            libraryIndex: PGNSerializer.libraryIndex(fromFileName: url.lastPathComponent)
        )
    }

    /// The highest ordinal the Library currently holds, or nil on a Library
    /// that has none (D58′).
    ///
    /// Predicated and limited rather than fetched-and-scanned — `libraryIndex`
    /// is a stored column, so "the largest one" is a question a
    /// `FetchDescriptor` can answer whole, and the alternative materializes
    /// every game with its full `moves` array to read one `Int`. The
    /// `backfillClassifications` lesson, applied at minting.
    internal func highestLibraryIndex() throws -> Int? {
        var descriptor = FetchDescriptor<PGN>(
            predicate: #Predicate { $0.libraryIndex != nil },
            sortBy: [SortDescriptor(\.libraryIndex, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.libraryIndex
    }
    
    /// The second door (M5): archives a finished live game into the
    /// Library. Shares `contentHash` with import — one hash, two doors —
    /// so a game that was also imported (or archived twice, e.g. by the
    /// resume self-heal after a crash mid-save) deduplicates instead of
    /// duplicating. (Reads the `@MainActor` `LiveGame` and returns a
    /// model-bearing result — covered by the type's isolation.)
    @discardableResult
    internal func archive(_ game: LiveGame) throws -> ArchiveResult {
        guard game.isFinished, game.result != .ongoing else {
            throw Error.ongoingGame
        }
        
        let pgn = PGN(
            event: game.roster.event,
            site: game.roster.site,
            date: game.roster.date,
            round: game.roster.round,
            white: game.roster.white,
            black: game.roster.black,
            moves: game.sanMoves,
            result: game.result,
            // D28′: the board that played the game, stamped at game start.
            // Outside the content hash by D24′ — equipment, not game — so
            // threading it can't perturb dedupe against pre-M2 archives.
            board: game.roster.board
        )
        // D58′: a game played here has no file yet, so it takes the number the
        // file it is *going* to become would carry — one past the highest the
        // Library knows. That keeps the folder's run unbroken when it is
        // exported, which is the whole point of adopting the folder's scheme
        // rather than inventing one.
        //
        // The recorded cost: this is `max + 1`, not a high-water mark, so
        // deleting the newest game hands its number to the next one. Accepted
        // at one Mac and one filing system — the folder on disk is the
        // authority, and a number reused there is a number the user themselves
        // reused. A stored mark would be a second source of truth for a value
        // whose first source is a directory listing.
        pgn.libraryIndex = (try? highestLibraryIndex()).flatMap { $0 + 1 }
        let hash = Self.contentHash(for: pgn)
        
        if let existing = try existingPGN(withHash: hash) {
            Self.logger?.info(
                "Archive deduplicated: matches existing '\(existing.name, privacy: .public)' hash=\(hash, privacy: .public)"
            )
            // Deliberately untouched: healing links on pre-existing rows is
            // the backfill's single job. Doors only link rows they insert.
            return ArchiveResult(pgn: existing, deduplicated: true)
        }
        
        try insertNewGame(pgn, hash: hash)
        
        Self.logger?.info(
            "Archived: '\(pgn.name, privacy: .public)' [\(pgn.result.rawValue, privacy: .public)] plies=\(pgn.moves.count)"
        )
        return ArchiveResult(pgn: pgn, deduplicated: false)
    }
    
    /// Recomputes and persists `contentHash` after an in-place edit (the
    /// archive-confirmation sheet, future Library edits). Every field the
    /// hash covers is user-editable there; skipping this call would let
    /// future deduplication silently rot against stale hashes — which is
    /// why the invariant reads "any in-place edit must call `refreshHash`".
    internal func refreshHash(of pgn: PGN) throws {
        pgn.contentHash = Self.contentHash(for: pgn)
        try modelContext.save()
        Self.logger?.info("Refreshed content hash for '\(pgn.name, privacy: .public)'")
    }
    
    /// The one-hash/two-doors invariant, made structural: every in-place
    /// edit funnels through here, so the mutation and the rehash can never
    /// be separated by a forgetful caller. The M11 decoupling review's
    /// finding: the convention was honored at the sole existing edit door
    /// (`BoardDestination.applyEditedInfo`), but only because that door
    /// remembered — a second door would be one forgotten line from silent
    /// dedupe rot, which is exactly the failure the invariant warns about.
    /// Rejected: keeping the two-step write-then-rehash convention per
    /// call site. M-prs.1 adds the player re-resolve here for the same
    /// structural reason: an edited white/black tag with stale links is
    /// the relationship version of a stale hash. Re-resolving
    /// unconditionally is idempotent and cheaper than diffing which
    /// fields the closure touched. Orphaned `Player` rows (nothing links
    /// them after an edit) linger by decision — no GC in the POC.
    internal func applyEdit(to pgn: PGN, _ edit: (PGN) -> Void) throws {
        edit(pgn)
        try resolvePlayers(for: pgn)
        // D60′ — a seat edit can strand the player it just replaced, and this
        // is where most orphans came from: every distinct *spelling* ever
        // committed to a seat mints a row, and re-spelling one left the old
        // behind. Collected here, before the save below, so the whole edit is
        // one transaction.
        collectOrphanedPlayers()
        try refreshHash(of: pgn)   // saves — one transaction covers all three
    }
    
    // MARK: Movetext Edit (M-lib.3, D18′)
    
    /// Applies an edited movetext to an archived game, validating by full
    /// replay (`MovetextEdit`). Returns `.failure` with the first offending
    /// ply when the proposal is illegal or its result is inconsistent —
    /// nothing mutates in that case — or `.success` with the stored canonical
    /// moves once committed. `throws` is reserved for the SwiftData save: a
    /// *rejection* is a value, so the editor distinguishes "your move 14 is
    /// illegal" from "the write failed".
    ///
    /// Re-validating here — the editor already validates for live feedback —
    /// makes "persisted movetext never bypasses the replayer" structural rather
    /// than a caller's good manners.
    ///
    /// On acceptance, one transaction (D18′): canonical moves replace the old,
    /// `evaluations` is invalidated (its per-ply indexing no longer describes
    /// these plies), `refreshHash` recomputes and saves. Seats are untouched by
    /// a movetext edit, so the re-resolution `applyEdit` does is omitted here. A
    /// proposal that canonicalizes to the current game is a no-op — evaluations
    /// stay, being still valid by position.
    ///
    /// Classification **re-derives** rather than clearing, which is D34′'s
    /// asymmetry: an opening is a dictionary probe, while recomputing
    /// evaluations means a depth-18 search. A re-seated Ruy Lopez is a Ruy Lopez
    /// before the transaction closes, not after the next Library visit.
    internal func applyMovetextEdit(
        to pgn: PGN,
        proposed: [String]
    ) throws -> Result<[String], MovetextEdit.Rejection> {
        switch MovetextEdit.validate(proposed, claimedResult: pgn.result) {
        case .failure(let rejection):
            return .failure(rejection)
        case .success(let accepted):
            guard accepted.moves != pgn.moves else { return .success(pgn.moves) }
            pgn.moves = accepted.moves
            pgn.evaluations = []
            classify(pgn)              // re-derived, not cleared — see the note above
            try refreshHash(of: pgn)   // recompute hash + save — one transaction
            Self.logger?.info(
                "Applied movetext edit to '\(pgn.name, privacy: .public)' plies=\(accepted.moves.count)"
            )
            return .success(accepted.moves)
        }
    }
    
    /// Forwards to the batch door rather than deleting here, so the orphan
    /// cascade and the transaction shape have exactly one implementation.
    /// Two doors that each remember to collect players is the twin-read-site
    /// pattern with a delete rule inside it.
    internal func delete(_ pgn: PGN) throws {
        try delete([pgn])
    }

    /// Deletes several games in one transaction (a single `save`), so a
    /// multi-select delete of many games doesn't fan out into one save per
    /// game. A no-op for an empty array.
    ///
    /// **Players stranded by the deletion go with it.** This reverses the
    /// no-collector half of D9′ for one specific cause, and only that cause:
    /// the roadmap's old "delete-player = nullify + delete" could not work
    /// because `.nullify` leaves the games' seat tags intact and the next
    /// `backfillPlayerLinks()` resolves them straight back. Deleting the
    /// *game* takes its seat tags with it, so there is nothing left to
    /// re-resolve and the row stays gone. The sweep (D40′) survives as the
    /// backstop for rows orphaned before this landed.
    ///
    /// The cascade is computed **before** the first `modelContext.delete`
    /// and applied after — see `playersOrphaned(byDeleting:)` for why asking
    /// afterwards is the trap.
    internal func delete(_ pgns: [PGN]) throws {
        guard !pgns.isEmpty else { return }
        let stranded = Self.playersOrphaned(byDeleting: pgns)
        let subject = pgns.count == 1 ? "'\(pgns[0].name)'" : "\(pgns.count) games"
        Self.logger?.info("Deleting \(subject, privacy: .public)")
        for pgn in pgns {
            modelContext.delete(pgn)
        }
        for player in stranded {
            Self.logger?.info(
                "Collecting '\(player.name, privacy: .public)' — its last game went with this deletion"
            )
            modelContext.delete(player)
        }
        try modelContext.save()
    }
    
    // MARK: Player Resolution (M-prs.1)
    
    /// Links both sides of `pgn` to their `Player` identities. Save-free
    /// by contract: the two doors and `applyEdit` each already end in a
    /// save, and `backfillPlayerLinks()` batches its own — a save here
    /// would double every door's transaction count.
    internal func resolvePlayers(for pgn: PGN) throws {
        pgn.whitePlayer = try resolvePlayer(named: pgn.white)
        pgn.blackPlayer = try resolvePlayer(named: pgn.black)
    }
    
    /// The single creation door for `Player`. Raw tags pass through
    /// `PlayerName.displayForm(of:)` first (so "Lopez, Ruy" and "Ruy Lopez"
    /// are one identity), then match case-insensitively on the stored
    /// `normalizedName` key. PGN's `"?"` placeholder and empty tags
    /// resolve to `nil` — a placeholder is the *absence* of a player,
    /// never a player named "?".
    internal func resolvePlayer(named rawTag: String) throws -> Player? {
        // The placeholder rule and the identity fold both live on
        // `Player.identity(forTag:)` since D61′ — extracted when the seat guard
        // needed the same answer without creating a row. Three lines were
        // inline here and this was the only place that knew them.
        guard let key = Player.identity(forTag: rawTag) else { return nil }
        let display = PlayerName.displayForm(of: rawTag)

        if let existing: Player = try first(#Predicate { $0.normalizedName == key }) {
            return existing
        }

        // D29′: remember the first-seen tag form alongside the display form.
        // Whitespace-folded only — comma structure, casing, and diacritics
        // stay verbatim, so the picker re-inserts what the tag actually was.
        let player = Player(name: display, tagName: PlayerName.folded(rawTag))
        modelContext.insert(player)
        Self.logger?.info("Created player '\(display, privacy: .public)'")
        return player
    }
    
    /// Read-only sibling of `resolvePlayer(named:)` for the M-prs.6
    /// "Show in Library" hop: the collection destinations' currency is
    /// the pure `PlayerStats.ID` (= `normalizedName`), the sidebar's is
    /// the model identifier — this is the bridge, and it **never
    /// creates** (the D9′ single door is about creation; a lookup that
    /// quietly inserted would be a second door by accident). A miss is
    /// only possible for a key no resolved link produced — which the
    /// stats index can't emit — so callers treat nil as a no-op.
    internal func player(withNormalizedKey key: String) throws -> Player? {
        try first(#Predicate { $0.normalizedName == key })
    }
    
    /// Links players on rows that predate the M-prs.1 schema (or whose
    /// links a future player deletion nullified). The `backfillEmptyNames`
    /// precedent: idempotent, cheap when clean, called from the collection
    /// destinations' `onAppear`. Fetch-all-and-scan rather than a
    /// predicate, deliberately: a nil `whitePlayer` on a `"?"` row is
    /// *correct*, not missing, so "needs linking" isn't a predicate over
    /// the link alone — and libraries are personal-scale. Returns the
    /// number of games it changed so the idempotence contract is testable.
    @discardableResult
    internal func backfillPlayerLinks() throws -> Int {
        let games = try modelContext.fetch(FetchDescriptor<PGN>())
        var relinked = 0
        for game in games {
            var changed = false
            if game.whitePlayer == nil, let player = try resolvePlayer(named: game.white) {
                game.whitePlayer = player
                changed = true
            }
            if game.blackPlayer == nil, let player = try resolvePlayer(named: game.black) {
                game.blackPlayer = player
                changed = true
            }
            if changed { relinked += 1 }
        }
        // D60′ — and this is the arm that heals what is already there. The
        // other collection sites fire when a door strands a row; nothing
        // strands the orphans that predate the rule, so nothing would ever
        // touch them. This runs on the Library's appearance, which is the one
        // pass that already walks every game and every player, so the registry
        // is clean by the first time anyone looks at it.
        //
        // Deliberately **after** the relink loop, never before: the loop
        // *creates* players for previously unlinked seats, and collecting first
        // would delete rows this pass is about to attach games to.
        let collected = collectOrphanedPlayers()
        if relinked > 0 || collected > 0 {
            try modelContext.save()
            if relinked > 0 {
                Self.logger?.info("Backfilled player links on \(relinked) game(s)")
            }
            if collected > 0 {
                Self.logger?.info("Collected \(collected) orphaned player(s)")
            }
        }
        return relinked
    }

    /// Heals `Player.tagName` on rows that predate the field (D29′) — the
    /// eager half of the decision: existing players must insert tag form
    /// from the picker *now*, not after they next happen to re-resolve.
    /// "First seen" for a pre-schema row is reconstructed as the seat tag
    /// of the earliest linked game (`effectiveDate`, then `importedAt` —
    /// the chronological-order philosophy), which is deterministic and the
    /// closest surviving witness to what created the row. A row with no
    /// links (a future deletion's orphan) stays nil; readers fall back to
    /// `name`. Idempotent, fetch-all-and-scan at personal scale, called
    /// *after* `backfillPlayerLinks()` at the same three sites — it reads
    /// the links, so the ordering lets a row linked this very pass be
    /// stamped this very pass. A separate pass rather than a rider on the
    /// link backfill, so each keeps an honest count contract. Returns the
    /// number of players stamped.
    @discardableResult
    internal func backfillPlayerTagNames() throws -> Int {
        let players = try modelContext.fetch(FetchDescriptor<Player>())
        var stamped = 0
        for player in players where player.tagName == nil {
            let sightings = player.whiteGames.map { ($0, $0.white) }
                + player.blackGames.map { ($0, $0.black) }
            let earliest = sightings.min { lhs, rhs in
                if lhs.0.effectiveDate != rhs.0.effectiveDate {
                    return lhs.0.effectiveDate < rhs.0.effectiveDate
                }
                return lhs.0.importedAt < rhs.0.importedAt
            }
            guard let tag = earliest?.1 else { continue }
            player.tagName = PlayerName.folded(tag)
            stamped += 1
        }
        if stamped > 0 {
            try modelContext.save()
            Self.logger?.info("Backfilled tag names on \(stamped) player(s)")
        }
        return stamped
    }
    
    // MARK: Classification (D19′, D34′)

    /// Stamps a game's derived classification — opening and mate motif — from
    /// its stored moves. Save-free by contract, the `resolvePlayers`
    /// precedent: every caller either already ends in a save
    /// (`applyMovetextEdit`, the analysis pass) or batches its own
    /// (`backfillClassifications`).
    ///
    /// The one write site for all four columns, so they are written together
    /// or not at all — which is the invariant `PGN.opening` checks when it
    /// requires both a code and a family. Returns whether anything actually
    /// changed, so the backfill's count contract can stay honest without
    /// re-reading the row.
    ///
    /// The table is a parameter with a convenience default rather than a
    /// reach for the global: callers already on an async path
    /// (`backfillClassifications`, the analysis pass) pass a table warmed off
    /// the main actor, and the default exists for the one caller that is
    /// synchronous by nature — `applyMovetextEdit`, inside a sheet's save.
    @discardableResult
    internal func classify(_ pgn: PGN, using table: ECOClassifier = ECOTable.bundled) -> Bool {
        let result = GameClassification.classify(moves: pgn.moves, using: table)
        guard result.opening != pgn.opening
                || result.specialCheckmate != pgn.specialCheckmate else { return false }
        pgn.ecoCode = result.opening?.code
        pgn.ecoFamily = result.opening?.family
        pgn.ecoVariation = result.opening?.variation
        pgn.specialCheckmate = result.specialCheckmate
        return true
    }

    /// Classifies rows that carry no opening yet — the `backfillPlayerLinks`
    /// precedent, and D34′'s reason for existing: an opening name is a table
    /// lookup, so an archive full of already-analysed games should not have
    /// to re-run Stockfish to learn one.
    ///
    /// The filter is `ecoCode == nil`, deliberately conflating "not yet
    /// classified" with "classified, and the table doesn't name this line". The
    /// alternative is a third stored state that would have to stay true across
    /// every movetext edit and table update or it would lie.
    ///
    /// Conflating costs almost nothing because of a property of the shipped
    /// dataset: it names all twenty legal first moves, so **any game with a move
    /// classifies to something**, and the residue re-asked each sweep is
    /// moveless rows. Pinned by `everyPlayedGameGetsAName` — if a table trim
    /// ever breaks that, the sweep stops converging and that test says so.
    ///
    /// Library `onAppear` only: Players reads neither field, so running it there
    /// would double the scan to change nothing.
    ///
    /// **Predicated, unlike its two neighbours, and the difference is the
    /// point.** `backfillPlayerLinks` fetches everything on purpose — a nil
    /// `whitePlayer` on a `"?"` row is *correct*, not missing. Here `ecoCode ==
    /// nil` is the whole filter, so SQLite answers it and the converged case
    /// fetches **zero rows** rather than materializing every game with its full
    /// `moves` array, on every Library appearance.
    @discardableResult
    internal func backfillClassifications(
        using table: ECOClassifier = ECOTable.bundled
    ) throws -> Int {
        let games = try modelContext.fetch(
            FetchDescriptor<PGN>(predicate: #Predicate { $0.ecoCode == nil })
        )
        var classified = 0
        for game in games {
            if classify(game, using: table) { classified += 1 }
        }
        if classified > 0 {
            try modelContext.save()
            Self.logger?.info("Classified \(classified) game(s)")
        }
        return classified
    }

    // MARK: Player Retag, Merge and Delete (M5 — D37′, D38′, D39′)

    /// One game a retag touches, and which of its seats.
    ///
    /// **Both flags, on one entry per game, rather than one entry per seat.**
    /// A player can hold both sides of the same row — a self-play game, or two
    /// people sharing a name — and the seat-wise shape gets that wrong in a way
    /// that is invisible until it bites: the collision pre-flight would compute
    /// two hashes for such a game, one per seat rewritten in isolation, and
    /// neither is the hash the row would actually end up with once *both* seats
    /// change. The prospective hash has to be asked once per game, with every
    /// seat the retag will touch substituted at the same time.
    private struct Rewrite {
        internal let game: PGN
        internal let isWhite: Bool
        internal let isBlack: Bool
    }

    /// One game a retag would rewrite, and the row it would collide with.
    ///
    /// **Identifiers and names, never the models** — `Error.duplicate`'s
    /// precedent, and for its recorded reason: `Swift.Error` refines
    /// `Sendable`, and a live `@Model` never is, so a rejection carrying `PGN`
    /// references would not compile as an error payload at all. The names ride
    /// along because the refusal has to *say* which two games it means — "this
    /// would make two of your games identical" is unactionable otherwise — and
    /// carrying them keeps the surface free of ID resolution, while the
    /// identifiers stay the handle for a reveal-in-Library affordance.
    internal struct HashCollision: Sendable {
        /// The game being retagged.
        internal let gameID: PersistentIdentifier
        internal let gameName: String
        /// The row its rewritten hash would land on.
        internal let existingID: PersistentIdentifier
        internal let existingName: String
    }

    /// Why a retag was refused. Both cases are pre-flight: nothing has been
    /// written when one of these is thrown.
    internal enum RetagRejection: Swift.Error {
        /// D39′. The rewrite would give one or more games a content hash that
        /// already belongs to a different row.
        case wouldCollide([HashCollision])
        /// `"?"` and empty are PGN's vocabulary for *no player*, and a retag
        /// to nothing is a deletion wearing a rename's clothes — it would
        /// strand games with an unnamed seat and no way back. Deleting the
        /// player is the operation that means that, and it has its own door.
        case emptyTag
    }

    /// Rewrites every game `player` appears in to carry `newTag` in that seat,
    /// then re-resolves and rehashes each — the single door through which a
    /// stored seat tag ever changes identity (D37′, D38′).
    ///
    /// **Why the games and not the registry.** `PGN.white` / `PGN.black` are
    /// what export writes byte for byte (D24′) and what the hash folds, while
    /// `Player.name` is *derived* from them. Renaming the registry alone would
    /// make `Player.name` disagree with every file the app writes; rewriting the
    /// tags makes identity follow the tags, D23′'s direction. Accepted price:
    /// seat tags are inside the hash, so an export taken *before* a rename no
    /// longer dedupes against its own game — not a leak, since by the hash's own
    /// definition the players are part of what identifies the game.
    ///
    /// **`newTag` is tag form, not display form** — "Senol, Bera". D23′ forbids
    /// the inverse, so the caller supplies what gets stored.
    ///
    /// Pre-flight and all-or-nothing (D39′): every prospective hash is checked
    /// against the Library *and* against the rest of the batch before a single
    /// field is written, so a refusal leaves the archive exactly as it was.
    /// Returns the number of games rewritten.
    @discardableResult
    internal func retag(_ player: Player, to newTag: String) throws -> Int {
        let display = PlayerName.displayForm(of: newTag)
        guard !display.isEmpty, display != "?" else { throw RetagRejection.emptyTag }

        let rewrites = Self.rewrites(for: player)
        guard !rewrites.isEmpty else { return 0 }

        try refuseCollisions(in: rewrites, becoming: newTag)

        for rewrite in rewrites {
            if rewrite.isWhite { rewrite.game.white = newTag }
            if rewrite.isBlack { rewrite.game.black = newTag }
            // Re-resolve then rehash, the `applyEdit` order: links follow the
            // tags, and the hash is recomputed from what the row now says. Not
            // `applyEdit` itself, which saves once per game — this is one
            // transaction over the whole rewrite.
            try resolvePlayers(for: rewrite.game)
            rewrite.game.contentHash = Self.contentHash(for: rewrite.game)
        }
        // D60′ — a rename relinks every game to the *new* identity, which
        // leaves the row that was renamed *from* pointing at nothing. That row
        // is the rename's whole residue and it goes with it, inside the same
        // transaction, so a rename can never be the thing that grows the
        // registry. This is also what makes rename the merge replacement D52′
        // promised it was: retag onto an existing name, and the loser is
        // collected rather than lingering as a duplicate spelling.
        collectOrphanedPlayers()
        try modelContext.save()
        Self.logger?.info(
            "Retagged player to '\(newTag, privacy: .public)' across \(rewrites.count) game(s)"
        )
        return rewrites.count
    }

    /// Every game `player` appears in, once, with the seats it holds there.
    ///
    /// The union of the two relationship arrays, folded on identity — a row
    /// present in both is one `Rewrite` with both flags set, never two.
    private static func rewrites(for player: Player) -> [Rewrite] {
        var byGame: [PersistentIdentifier: Rewrite] = [:]
        for game in player.whiteGames {
            byGame[game.persistentModelID] = Rewrite(game: game, isWhite: true, isBlack: false)
        }
        for game in player.blackGames {
            let existing = byGame[game.persistentModelID]
            byGame[game.persistentModelID] = Rewrite(
                game: game,
                isWhite: existing?.isWhite ?? false,
                isBlack: true
            )
        }
        return Array(byGame.values)
    }

    // `merge(_:into:)` lived here from D38′ until D52′ removed it. What it knew
    // survives: a duplicate spelling is fixed by *renaming* the misspelt player
    // to the canonical tag, through the same `retag` door merge called. D38′'s
    // finding — link surgery without tag rewriting is undone by `applyEdit`'s
    // unconditional re-resolve — stands at the anchor, where it constrains any
    // future door that moves players between rows.

    /// Deletes every registry row nothing points at (D60′).
    ///
    /// **The rule is that the PGN files are the source of truth.** A `Player`
    /// exists to give a seat tag an identity; a row no game references is
    /// describing nobody, and the archive it was derived from has already
    /// forgotten it. So it goes, always, without being asked — which repeals
    /// the "no collector" half of D9′ rather than narrowing it the way D50′
    /// did for one cause.
    ///
    /// **Safe because `resolvePlayer` has exactly two callers and both link
    /// immediately** — `resolvePlayers(for:)` and `backfillPlayerLinks()`.
    /// There is no path that creates a row and links it later, so a linkless
    /// row is always a leftover and never a row in transit. That was checked
    /// rather than assumed, and it is the whole argument: if a future door ever
    /// wants to mint a player *before* attaching it, this method is what breaks,
    /// and it will break loudly by deleting the row mid-flight.
    ///
    /// **Save-free by contract**, the `resolvePlayers` discipline: every caller
    /// already ends in a save, and one here would double each door's
    /// transaction count. Callers that do *not* save (a read path) must not
    /// call this.
    ///
    /// Fetch-all-and-scan, necessarily: `isOrphaned` reads relationships, which
    /// SwiftData cannot express in a `#Predicate` — the same reason
    /// `backfillPlayerLinks` fetches everything. It joins the known-costs
    /// census, bounded by running only on doors a person invoked.
    @discardableResult
    internal func collectOrphanedPlayers() -> Int {
        guard let players = try? modelContext.fetch(FetchDescriptor<Player>()) else {
            // A failed fetch means no collection this pass, never a partial
            // one. The next door through does it again; nothing accumulates
            // that a later edit will not sweep.
            Self.logger?.error("Orphan collection skipped — player fetch failed")
            return 0
        }
        var collected = 0
        for player in players where !player.isDeleted && Self.isOrphaned(player) {
            Self.logger?.info(
                "Collecting orphaned player '\(player.name, privacy: .public)' — no game references it"
            )
            modelContext.delete(player)
            collected += 1
        }
        return collected
    }

    /// The one spelling of "nothing points at this row" (D40′).
    ///
    /// Three sites asked it independently before D40′ — a delete guard,
    /// `merge`'s post-retag assertion, and the inspector's `canDelete` — the
    /// twin-read-site pattern in behavioural clothes. **One caller now**:
    /// `collectOrphanedPlayers`. The sweep door and its `@Query` filter went
    /// with D60′, merge's assertion with D52′.
    ///
    /// Static and context-free on purpose, so the *rule* is store-owned while
    /// whoever holds the rows stays free to fetch them their own way. A `func
    /// orphanedPlayers()` here was written first and removed: it fetches, which
    /// welds the rule to one way of getting the rows.
    ///
    /// **Orphans are structurally unselectable**, which is why they ever needed
    /// a door of their own: Players renders `PlayerStats.index(of:)`, a fold
    /// over `GameRecord`s built from *resolved links*, so a linkless row appears
    /// in no view mode. "Is in the list" and "is deletable" were exact
    /// complements — D40′'s finding, and the reason anything gated on a
    /// *selected* orphan is dead code with a green build.
    ///
    /// D60′ answers that by having no door at all: collection is automatic on
    /// every path that can strand a row.
    internal static func isOrphaned(_ player: Player) -> Bool {
        player.whiteGames.isEmpty && player.blackGames.isEmpty
    }

    /// The players `pgns` would strand — `isOrphaned`'s **prospective twin**,
    /// asked before a single row is deleted.
    ///
    /// One rule, two spellings — `contentHash`'s arrangement for D39′'s
    /// pre-flight. The present-tense predicate reads live relationships; a
    /// pre-flight needs what would be true *after* a write it hasn't performed.
    /// Deleting first and then asking `isOrphaned` bets on SwiftData having
    /// propagated the inverse before `save()`, and **fails silently in the
    /// direction that looks fine**: the array still holds the tombstoned game,
    /// the cascade never fires, the build is green and the feature does nothing.
    /// D40′'s defect exactly, which is why this is a set question.
    ///
    /// A player goes iff every linked game is in the deletion set, which handles
    /// two cases a seat-wise reading gets wrong for free: one player on both
    /// seats of a deleted game (counted once, via the identifier-keyed table),
    /// and a player whose games are spread across a batch (each row alone looks
    /// survivable). `allSatisfy` over an empty array answers true — right for a
    /// stale link, and the only way an already-orphaned row reaches here.
    ///
    /// Sorted by name because the result is rendered, and a `Dictionary`'s
    /// values have no order to show them in.
    internal static func playersOrphaned(byDeleting pgns: [PGN]) -> [Player] {
        let doomed = Set(pgns.map(\.persistentModelID))
        var seated: [PersistentIdentifier: Player] = [:]
        for pgn in pgns {
            for player in [pgn.whitePlayer, pgn.blackPlayer].compactMap({ $0 }) {
                seated[player.persistentModelID] = player
            }
        }
        return seated.values
            .filter { player in
                (player.whiteGames + player.blackGames)
                    .allSatisfy { doomed.contains($0.persistentModelID) }
            }
            .sorted { $0.name < $1.name }
    }

    // `deleteOrphanedPlayers(_:)` was D40′'s write door, removed with the sweep
    // it served (D60′). Its transferable lesson survives at
    // `collectOrphanedPlayers` above, inverted: that door re-checked each row
    // because a list held across a dialog is stale by construction, and the new
    // one needs no such guard because it never holds a list — it fetches,
    // filters and deletes in one pass with no user in the middle.


    /// D39′'s pre-flight. Throws `.wouldCollide` naming every game whose
    /// rewritten hash would land on a row that isn't itself.
    ///
    /// Two sources of collision, and missing the second is the easy bug: a
    /// rewritten game can collide with a row already in the Library, *or* with
    /// another game in this same batch — which is exactly the double-imported
    /// game that motivates merging in the first place, one copy under each
    /// spelling of the name. The batch is checked against itself through
    /// `seen`, so the second copy reports against the first rather than both
    /// passing a Library probe that neither has been written into yet.
    private func refuseCollisions(in rewrites: [Rewrite], becoming newTag: String) throws {
        var collisions: [HashCollision] = []
        var seen: [String: PGN] = [:]
        for rewrite in rewrites {
            let hash = Self.prospectiveHash(for: rewrite, becoming: newTag)
            if let twin = seen[hash] {
                collisions.append(Self.collision(rewrite.game, against: twin))
                continue
            }
            seen[hash] = rewrite.game
            if let existing = try existingPGN(withHash: hash),
               existing.persistentModelID != rewrite.game.persistentModelID {
                collisions.append(Self.collision(rewrite.game, against: existing))
            }
        }
        guard collisions.isEmpty else {
            Self.logger?.error("Retag refused: \(collisions.count) hash collision(s)")
            throw RetagRejection.wouldCollide(collisions)
        }
    }

    /// Reads a collision off two live rows at the one point where both are in
    /// hand, so the `Sendable` payload never has to reach back for them.
    private static func collision(_ game: PGN, against existing: PGN) -> HashCollision {
        HashCollision(
            gameID: game.persistentModelID,
            gameName: game.name,
            existingID: existing.persistentModelID,
            existingName: existing.name
        )
    }

    // MARK: Private Helpers

    /// The shared tail of both doors. "One hash, two doors" is a rule about
    /// `contentHash`; this is the *rest* of the door, and it was duplicated
    /// line for line — including the ordering that carries weight, with
    /// `resolvePlayers` before the save so one transaction covers the row and
    /// its links. Persisting the hash is what makes the next import's
    /// `existingPGN(withHash:)` hit: without the assignment the row stores an
    /// empty hash, every future lookup misses, and dedupe silently no-ops.
    private func insertNewGame(_ pgn: PGN, hash: String) throws {
        pgn.contentHash = hash
        modelContext.insert(pgn)
        try resolvePlayers(for: pgn)
        try modelContext.save()
    }
    
    private func parse(_ text: String) throws -> PGN {
        do {
            return try PGNParser.parse(text)
        } catch {
            // `PGNParser.parse` is `throws(PGNParser.Error)`, so the `as` cast
            // this used to need is gone and the switch below is exhaustive by
            // the compiler rather than by convention.
            switch error {
            case .missingRequiredTags(let tags):
                throw Error.missingRequiredTags(tags)
            case .unbalancedBraces:
                throw Error.malformedPGN(reason: "Unbalanced braces in movetext")
            case .unbalancedParentheses:
                throw Error.malformedPGN(reason: "Unbalanced parentheses in movetext")
            case .multipleGames:
                throw Error.malformedPGN(
                    reason: "This file contains more than one game. Split it into one game per file."
                )
            }
        }
    }
    
    /// Fetch-limit-1 lookup. Three call sites built this by hand; the limit is
    /// the load-bearing part — an unbounded fetch taken `.first` of is the kind
    /// of thing that only hurts at five thousand games.
    private func first<T: PersistentModel>(_ predicate: Predicate<T>) throws -> T? {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
    
    private func existingPGN(withHash hash: String) throws -> PGN? {
        try first(#Predicate { $0.contentHash == hash })
    }
    
    // MARK: Static Methods

    /// The model-typed spelling — what both doors and `refreshHash` call.
    ///
    /// A thin forward to the field-typed one below, which exists because D39′
    /// needs a game's hash **as it would be** after a seat retag, and the only
    /// alternatives were worse: mutate-hash-revert (a door that briefly writes
    /// a lie into the model it is validating) or a second transcription of the
    /// recipe (the "one content hash" invariant, broken by the very check
    /// meant to protect it).
    private static func contentHash(for pgn: PGN) -> String {
        contentHash(
            event: pgn.event,
            site: pgn.site,
            date: pgn.date,
            round: pgn.round,
            white: pgn.white,
            black: pgn.black,
            result: pgn.result,
            moves: pgn.moves
        )
    }

    /// The recipe itself, over values — MD5 of the eight fields joined by `|`,
    /// in this order, forever.
    ///
    /// **Persistence contract.** Every stored `contentHash` in the Library was
    /// produced by this arrangement; changing the order, the separator, the
    /// normalization or the digest silently un-dedupes the entire archive
    /// against itself. `timeControl`, `board` and the four classification
    /// columns are deliberately absent — equipment, clock and derived truth do
    /// not identify a game.
    private static func contentHash(
        event: String,
        site: String,
        date: Date?,
        round: Int?,
        white: String,
        black: String,
        result: GameResult,
        moves: [String]
    ) -> String {
        let parts: [String] = [
            normalize(event),
            normalize(site),
            date.map(hashDateString(from:)) ?? "",
            round.map(String.init) ?? "",
            normalize(white),
            normalize(black),
            result.rawValue,
            moves.joined(separator: " ")
        ]
        let combined = parts.joined(separator: "|")
        let digest = Insecure.MD5.hash(data: Data(combined.utf8))
        // `map`, not `compactMap`: nothing here can be nil, and the old verb
        // made a reader ask which bytes of a hash get dropped.
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// The hash the game *would* carry once every seat this retag touches
    /// becomes `newTag` — D39′'s whole question, asked without writing to the
    /// row it is asking about.
    ///
    /// Both flags are substituted in one call, which is the reason `Rewrite`
    /// is per-game rather than per-seat: for a row the player holds on both
    /// sides, asking twice with one seat changed each time produces two hashes
    /// the game will never have.
    private static func prospectiveHash(for rewrite: Rewrite, becoming newTag: String) -> String {
        let game = rewrite.game
        return contentHash(
            event: game.event,
            site: game.site,
            date: game.date,
            round: game.round,
            white: rewrite.isWhite ? newTag : game.white,
            black: rewrite.isBlack ? newTag : game.black,
            result: game.result,
            moves: game.moves
        )
    }
    
    /// Fold + case, one implementation (`PlayerName.folded`). **Persistence
    /// contract** — see `hashDateString`: this must keep producing
    /// byte-identical output forever. It does; lowercasing commutes with the
    /// fold, so routing through the shared helper is a refactor, not a change.
    private static func normalize(_ value: String) -> String {
        PlayerName.folded(value).lowercased()
    }
}
