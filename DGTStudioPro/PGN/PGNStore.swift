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
        calendar.timeZone = TimeZone(identifier: "UTC")!
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
        
        // Persist the computed hash on the model so subsequent imports of
        // the same game can find it via `existingPGN(withHash:)`. Without
        // this assignment the row is stored with an empty `contentHash`,
        // every future lookup misses, and deduplication silently no-ops.
        pgn.contentHash = hash
        modelContext.insert(pgn)
        try resolvePlayers(for: pgn)   // M-prs.1 — link before the save below covers both
        try modelContext.save()
        
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
            result: game.result
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
        
        pgn.contentHash = hash
        modelContext.insert(pgn)
        try resolvePlayers(for: pgn)   // M-prs.1 — same placement as the import door
        try modelContext.save()
        
        Self.logger.info(
            "Archived: '\(pgn.name, privacy: .public)' \(pgn.white, privacy: .public) vs \(pgn.black, privacy: .public) [\(pgn.result.rawValue, privacy: .public)] plies=\(pgn.moves.count)"
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
    /// `PGN.displayPlayerName(_:)` first (so "Lopez, Ruy" and "Ruy Lopez"
    /// are one identity), then match case-insensitively on the stored
    /// `normalizedName` key. PGN's `"?"` placeholder and empty tags
    /// resolve to `nil` — a placeholder is the *absence* of a player,
    /// never a player named "?".
    internal func resolvePlayer(named rawTag: String) throws -> Player? {
        let display = PGN.displayPlayerName(rawTag)
        guard !display.isEmpty, display != "?" else { return nil }
        
        let key = Player.normalizedKey(for: display)
        var descriptor = FetchDescriptor<Player>(
            predicate: #Predicate { $0.normalizedName == key }
        )
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        
        let player = Player(name: display)
        modelContext.insert(player)
        Self.logger.info("Created player '\(display, privacy: .public)'")
        return player
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
    
    // MARK: Private Helpers
    private func parse(_ text: String) throws -> PGN {
        do {
            return try PGNParser.parse(text)
        } catch let error as PGNParser.Error {
            switch error {
            case .missingRequiredTags(let tags):
                throw Error.missingRequiredTags(tags)
            case .unbalancedBraces:
                throw Error.malformedPGN(reason: "Unbalanced braces in movetext")
            case .unbalancedParentheses:
                throw Error.malformedPGN(reason: "Unbalanced parentheses in movetext")
            }
        }
    }
    
    private func existingPGN(withHash hash: String) throws -> PGN? {
        var descriptor = FetchDescriptor<PGN>(
            predicate: #Predicate { $0.contentHash == hash }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
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
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
