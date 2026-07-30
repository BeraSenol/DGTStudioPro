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
    private static func contentHash(for pgn: PGN) -> String {
        let parts: [String] = [
            normalize(pgn.event),
            normalize(pgn.site),
            pgn.date.map(hashDateString(from:)) ?? "",
            pgn.round.map(String.init) ?? "",
            normalize(pgn.white),
            normalize(pgn.black),
            pgn.result.rawValue,
            pgn.moves.joined(separator: " ")
        ]
        let combined = parts.joined(separator: "|")
        let digest = Insecure.MD5.hash(data: Data(combined.utf8))
        // `map`, not `compactMap`: nothing here can be nil, and the old verb
        // made a reader ask which bytes of a hash get dropped.
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Fold + case, one implementation (`PlayerName.folded`). **Persistence
    /// contract** — see `hashDateString`: this must keep producing
    /// byte-identical output forever. It does; lowercasing commutes with the
    /// fold, so routing through the shared helper is a refactor, not a change.
    private static func normalize(_ value: String) -> String {
        PlayerName.folded(value).lowercased()
    }
}
