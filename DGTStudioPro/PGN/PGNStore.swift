//
//  PGNStore.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 15/04/2026.
//

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
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "pgnstore"
    )
    
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
    @discardableResult
    internal func importPGN(text: String) throws -> PGN {
        let pgn = try parse(text)
        let hash = Self.contentHash(for: pgn)
        
        if let existing = try existingPGN(withHash: hash) {
            Self.logger.info(
                "Rejected duplicate: '\(pgn.name, privacy: .public)' matches existing '\(existing.name, privacy: .public)' hash=\(hash, privacy: .public)"
            )
            throw Error.duplicate(existingID: existing.persistentModelID, existingName: existing.name)
        }
        
        try insertNewGame(pgn, hash: hash)
        
        Self.logger.info(
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
            Self.logger.error("Failed to read PGN at \(url.path, privacy: .public)")
            throw Error.fileReadFailed(url, underlying: error)
        }
        
        return try importPGN(text: text)
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
        let hash = Self.contentHash(for: pgn)
        
        if let existing = try existingPGN(withHash: hash) {
            Self.logger.info(
                "Archive deduplicated: matches existing '\(existing.name, privacy: .public)' hash=\(hash, privacy: .public)"
            )
            // Deliberately untouched: healing links on pre-existing rows is
            // the backfill's single job. Doors only link rows they insert.
            return ArchiveResult(pgn: existing, deduplicated: true)
        }
        
        try insertNewGame(pgn, hash: hash)
        
        Self.logger.info(
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
        Self.logger.info("Refreshed content hash for '\(pgn.name, privacy: .public)'")
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
        try refreshHash(of: pgn)   // saves — one transaction covers both
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
    /// Re-validating here (the editor already validates for live feedback) is
    /// deliberate — it makes "persisted movetext never bypasses the replayer"
    /// structural rather than a caller's good manners, the `applyEdit`
    /// philosophy applied to movetext.
    ///
    /// On acceptance, one transaction (D18′): the canonical moves replace the
    /// old, the parallel `evaluations` array is invalidated (its per-ply
    /// indexing no longer describes these plies), and `refreshHash` recomputes
    /// and saves. Seats are untouched by a movetext edit, so the player
    /// re-resolution the transaction calls for on a *seat* edit is a no-op and
    /// omitted (metadata edits route through `applyEdit`, which re-resolves).
    /// A proposal that canonicalizes to the current game is a no-op —
    /// evaluations, still valid by position, are preserved.
    ///
    /// Correction (M4): this doc used to promise the classification fields
    /// would *clear* here alongside the evaluations, "once they exist on the
    /// model". They exist, and clearing turned out to be the wrong verb.
    /// D34′ made classification engine-free, so the edited game can be
    /// re-classified on the spot for the price of a dictionary probe — the
    /// evaluations clear because recomputing them means a depth-18 search,
    /// which is exactly the asymmetry that stopped applying once the opening
    /// stopped needing an engine. A re-seated Ruy Lopez is a Ruy Lopez
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
            Self.logger.info(
                "Applied movetext edit to '\(pgn.name, privacy: .public)' plies=\(accepted.moves.count)"
            )
            return .success(accepted.moves)
        }
    }
    
    internal func delete(_ pgn: PGN) throws {
        Self.logger.info("Deleting: '\(pgn.name, privacy: .public)'")
        modelContext.delete(pgn)
        try modelContext.save()
    }
    
    /// Deletes several games in one transaction (a single `save`), so a
    /// multi-select delete of many games doesn't fan out into one save per
    /// game. A no-op for an empty array.
    internal func delete(_ pgns: [PGN]) throws {
        guard !pgns.isEmpty else { return }
        Self.logger.info("Deleting \(pgns.count) game(s) in batch")
        for pgn in pgns {
            modelContext.delete(pgn)
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
        let display = PlayerName.displayForm(of: rawTag)
        guard !display.isEmpty, display != "?" else { return nil }
        
        let key = Player.normalizedKey(for: display)
        if let existing: Player = try first(#Predicate { $0.normalizedName == key }) {
            return existing
        }

        // D29′: remember the first-seen tag form alongside the display form.
        // Whitespace-folded only — comma structure, casing, and diacritics
        // stay verbatim, so the picker re-inserts what the tag actually was.
        let player = Player(name: display, tagName: PlayerName.folded(rawTag))
        modelContext.insert(player)
        Self.logger.info("Created player '\(display, privacy: .public)'")
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
        if relinked > 0 {
            try modelContext.save()
            Self.logger.info("Backfilled player links on \(relinked) game(s)")
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
            Self.logger.info("Backfilled tag names on \(stamped) player(s)")
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
    /// The filter is `ecoCode == nil`, which deliberately conflates "not yet
    /// classified" with "classified, and the table doesn't name this line".
    /// The alternative is a third stored state — a flag or a timestamp saying
    /// the question was already asked — and that state would have to be kept
    /// true across every movetext edit and table update or it would lie.
    ///
    /// The cost of conflating turns out to be close to nothing, and the
    /// reason is a property of the shipped dataset worth writing down: it
    /// names all twenty legal first moves, so **any game with a move at all
    /// classifies to something**. The residue that gets re-asked each sweep
    /// is therefore just moveless rows. Pinned by
    /// `everyPlayedGameGetsAName` — if a future table trim breaks that
    /// property, the sweep quietly stops converging, and that test is what
    /// says so.
    ///
    /// Called from the Library's `onAppear` only, not from all three
    /// collection destinations the player backfills run at: Players and
    /// Rankings read neither field, so running it there would triple the
    /// scan to change nothing.
    ///
    /// **Predicated, unlike its two neighbours, and the difference is the
    /// point.** `backfillPlayerLinks` fetches everything on purpose — a nil
    /// `whitePlayer` on a `"?"` row is *correct*, not missing, so "needs
    /// linking" isn't a predicate over the link alone. Here it is: `ecoCode`
    /// is a plain stored column and `ecoCode == nil` is the whole filter, so
    /// SQLite can answer it and the converged case fetches **zero rows**
    /// instead of materializing every game in the Library — each of which
    /// drags its full `moves` array along for a question about one optional
    /// string. That happens on every Library appearance, which is what makes
    /// it worth the predicate rather than a deferred measurement.
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
            Self.logger.info("Classified \(classified) game(s)")
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
    /// what export writes byte for byte (D24′) and what the content hash folds
    /// (the one-hash invariant), while `Player.name` is *derived* from them
    /// through `PlayerName.displayForm`. Renaming the registry row alone would
    /// make `Player.name` a label that disagrees with every file the app
    /// writes; rewriting the tags makes identity follow the tags, which is the
    /// direction D23′ says names travel. The price, accepted at decision time:
    /// seat tags are inside the hash, so every affected game's hash changes and
    /// an export taken *before* the rename no longer dedupes against its own
    /// game. That is not a leak — by the hash's own definition the players are
    /// part of what identifies the game.
    ///
    /// **`newTag` is tag form, not display form** — "Senol, Bera". D23′ forbids
    /// the inverse transform, so the caller must supply the form that gets
    /// stored; the rename surface edits the tag and shows the derived display
    /// form beneath it.
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
        try modelContext.save()
        Self.logger.info(
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

    /// Folds `loser` into `survivor`: retag the loser's games to the survivor's
    /// stored tag form, which relinks them by resolution, then delete the row
    /// nothing points at any more (D38′).
    ///
    /// **Merge is retag, and it has to be.** Pure link surgery — move the
    /// relationships, leave the tags — looks cheaper and is unstable:
    /// `applyEdit` re-resolves both seats from the tag strings unconditionally,
    /// so the first metadata edit on a merged game would read its untouched
    /// tag, fail to find the survivor, and mint the deleted player straight
    /// back. Rewriting the tags is what makes the merge survive the app's own
    /// existing doors instead of needing them weakened.
    ///
    /// The survivor's `tagName` is the target, falling back to its display
    /// `name` for a pre-D29′ orphan that never got one — the same fallback the
    /// seat picker uses, for the same reason.
    @discardableResult
    internal func merge(_ loser: Player, into survivor: Player) throws -> Int {
        guard loser.persistentModelID != survivor.persistentModelID else { return 0 }
        let target = survivor.tagName ?? survivor.name
        let moved = try retag(loser, to: target)
        // Retagging resolved every game onto the survivor, so the loser is now
        // orphaned by construction — but assert it rather than assume it: a
        // still-linked loser means the target tag didn't fold onto the
        // survivor's key, and deleting it here would nullify live links.
        guard loser.whiteGames.isEmpty, loser.blackGames.isEmpty else {
            Self.logger.error(
                "Merge left '\(loser.name, privacy: .public)' still linked — not deleting"
            )
            return moved
        }
        modelContext.delete(loser)
        try modelContext.save()
        Self.logger.info(
            "Merged '\(loser.name, privacy: .public)' into '\(survivor.name, privacy: .public)' (\(moved) seat(s))"
        )
        return moved
    }

    /// Deletes a player row that nothing links to.
    ///
    /// **Only orphans, and the guard is the point.** `.nullify` means deleting
    /// a linked player strands its games with their seat tags intact — and the
    /// next Library visit runs `backfillPlayerLinks()`, which resolves those
    /// same tags and creates the row again. A delete that the app itself undoes
    /// within one navigation is worse than no delete at all. For a player who
    /// has games, the operation the user actually wants is rename (change what
    /// they're called) or merge (they're someone else); this door refuses so
    /// the surface can say that instead of appearing to work.
    ///
    /// Returns `false` when it refused, so the caller can explain rather than
    /// silently no-op.
    @discardableResult
    internal func deleteOrphanedPlayer(_ player: Player) throws -> Bool {
        guard player.whiteGames.isEmpty, player.blackGames.isEmpty else {
            Self.logger.info(
                "Refused to delete linked player '\(player.name, privacy: .public)' — the link backfill would recreate it"
            )
            return false
        }
        Self.logger.info("Deleting orphaned player '\(player.name, privacy: .public)'")
        modelContext.delete(player)
        try modelContext.save()
        return true
    }

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
            Self.logger.error("Retag refused: \(collisions.count) hash collision(s)")
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
