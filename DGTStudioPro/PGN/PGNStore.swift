import CryptoKit
import Foundation
import os
import SwiftData

// MARK: PGN Store

/// All Library persistence - import, archive, delete, one-hash/two-doors `refreshHash`.
/// `@MainActor` as a whole: every method fronts the app's main-context `ModelContext`.
@MainActor
struct PGNStore {
    
    // MARK: Static Constants
    private static let logger = AppLog.logger(.pgnstore)
    
    /// UTC Gregorian calendar backing the hash's date rendering.
    private static let hashCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
    
    /// **Persistence contract**: every stored `contentHash` was computed against this exact
    /// "yyyy.MM.dd"-in-UTC rendering - it must stay byte-identical forever or dedupe rots.
    /// Internal (not private) so the pin can reach it.
    static func hashDateString(from date: Date) -> String {
        let parts = hashCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d.%02d.%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
    
    // MARK: Errors
    enum Error: Swift.Error, LocalizedError {
        /// Hash matches an existing game. Carries id + name, never the model - `Swift.Error`
        /// refines `Sendable`, and a live `@Model` never is.
        case duplicate(existingID: PersistentIdentifier, existingName: String)
        case missingRequiredTags(Set<String>)
        case malformedPGN(reason: String)
        case fileReadFailed(URL, underlying: Swift.Error)
        /// `archive(_:)` got a `*` result - no ongoing game reaches the Library.
        case ongoingGame

        /// `LocalizedError` for the generic catches: the archive door renders
        /// `localizedDescription` into the HUD's Retry/Discard message (`DGTLiveSession`), where
        /// the Foundation fallback read "…error 4." The import sheet keeps its own per-surface
        /// copy (`ImportStatusView`) and never reads this - view prose stays in views.
        var errorDescription: String? {
            switch self {
            case .duplicate(_, let name):
                return "Already in the Library as '\(name)'."
            case .missingRequiredTags(let tags):
                return "Missing required tags: \(tags.sorted().joined(separator: ", "))."
            case .malformedPGN(let reason):
                return reason
            case .fileReadFailed(let url, let underlying):
                return "Couldn't read \(url.lastPathComponent): \(underlying.localizedDescription)"
            case .ongoingGame:
                return "The game is still ongoing - only a finished game archives."
            }
        }
    }
    
    /// Archive outcome: a hash match here is *success* (game is in the Library), not the error import throws.
    struct ArchiveResult {
        /// The Library row the game landed on - fresh or pre-existing.
        let pgn: PGN
        /// True when an identical game was already stored.
        let deduplicated: Bool
    }
    
    // MARK: Stored Properties
    private let modelContext: ModelContext
    
    // MARK: Initializers
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: Instance Methods
    /// The text import door: parse, dedupe by content hash, insert.
    /// **Throws `Error.duplicate` naming the existing game - it does not return it.**
    @discardableResult
    func importPGN(text: String, libraryIndex: Int? = nil) throws -> PGN {
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
    func importPGN(from url: URL) throws -> PGN {
        let text: String
        
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            Self.logger?.error("Failed to read PGN at \(url.path, privacy: .public)")
            throw Error.fileReadFailed(url, underlying: error)
        }
        
        // The one place the filename is in scope. `lastPathComponent`: a folder named
        // `2024. Tournaments` must not number every game inside it.
        return try importPGN(
            text: text,
            libraryIndex: PGNSerializer.libraryIndex(fromFileName: url.lastPathComponent)
        )
    }

    /// Highest ordinal in the Library, or nil. Predicated + limit 1, not fetch-and-scan.
    func highestLibraryIndex() throws -> Int? {
        var descriptor = FetchDescriptor<PGN>(
            predicate: #Predicate { $0.libraryIndex != nil },
            sortBy: [SortDescriptor(\.libraryIndex, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.libraryIndex
    }
    
    /// Folder-scan report (counts and filenames only - no models cross this boundary, the `HashCollision` rule).
    struct LibraryIndexBackfill: Sendable, Equatable {
        /// Rows that had no ordinal and now carry the one their file named.
        var stamped: Int = 0
        /// Matched a row that already had an ordinal - left alone, see below.
        var alreadyNumbered: Int = 0
        /// Parsed cleanly, matched no row - a finding, not an error: the folder holds a game the Library does not.
        var unmatched: [String] = []
        /// No `<digits>.` ordinal in the filename; skipped before parsing.
        var unnumbered: [String] = []
        /// Unreadable or unparseable - separate from `unmatched` because the remedies differ.
        var skipped: [String] = []

        var scanned: Int {
            stamped + alreadyNumbered + unmatched.count + unnumbered.count + skipped.count
        }
    }

    /// Whether any game still lacks an ordinal - gates the backfill affordance. Predicated + limit 1.
    func hasUnnumberedGames() throws -> Bool {
        var descriptor = FetchDescriptor<PGN>(predicate: #Predicate { $0.libraryIndex == nil })
        descriptor.fetchLimit = 1
        return try !modelContext.fetch(descriptor).isEmpty
    }

    /// Matches PGN files in `folder` to rows by **content hash** (never by filename - the folder uses full
    /// names, the serializer given names) and stamps each match with the filename's ordinal.
    /// An existing ordinal is never overwritten; one bad file does not cost the rest.
    func backfillLibraryIndices(from folder: URL) throws -> LibraryIndexBackfill {
        var report = LibraryIndexBackfill()

        let names = try FileManager.default
            .contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "pgn" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        for url in names {
            let name = url.lastPathComponent

            guard let index = PGNSerializer.libraryIndex(fromFileName: name) else {
                report.unnumbered.append(name)
                continue
            }

            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  let parsed = try? parse(text) else {
                report.skipped.append(name)
                continue
            }

            // `parse` builds a detached `PGN` and does not insert; nothing here reaches `insertNewGame`.
            guard let row = try existingPGN(withHash: Self.contentHash(for: parsed)) else {
                report.unmatched.append(name)
                continue
            }

            guard row.libraryIndex == nil else {
                report.alreadyNumbered += 1
                continue
            }

            row.libraryIndex = index
            report.stamped += 1
        }

        // One save outside the loop - N saves leave a half-stamped archive behind a mid-loop failure.
        // `libraryIndex` is outside the content hash, so no `refreshHash` needed.
        if report.stamped > 0 { try modelContext.save() }

        Self.logger?.info(
            """
            Library index backfill: stamped=\(report.stamped) \
            alreadyNumbered=\(report.alreadyNumbered) unmatched=\(report.unmatched.count) \
            unnumbered=\(report.unnumbered.count) skipped=\(report.skipped.count)
            """
        )

        return report
    }

    /// The second door (M5): archives a finished live game. Shares `contentHash` with import -
    /// one hash, two doors - so a game imported and archived deduplicates.
    @discardableResult
    func archive(_ game: LiveGame) throws -> ArchiveResult {
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
            // Board stamped at game start; outside the content hash so dedupe is unperturbed.
            board: game.roster.board
        )
        // A played game takes `max + 1` - the number its exported file will carry. Cost: delete the
        // newest game and the number is reused (the folder is the authority). `?? 0` inside the `do`:
        // an empty Library is index 1, but *fetch failed* must not stamp 1 - caught, never thrown;
        // an ordinal must never fail an archive (archive-first, exactly once, never lost).
        do {
            pgn.libraryIndex = (try highestLibraryIndex() ?? 0) + 1
        } catch {
            pgn.libraryIndex = nil
            Self.logger?.error(
                "Could not read the highest library index; archiving unnumbered: \(error)"
            )
        }
        let hash = Self.contentHash(for: pgn)
        
        if let existing = try existingPGN(withHash: hash) {
            Self.logger?.info(
                "Archive deduplicated: matches existing '\(existing.name, privacy: .public)' hash=\(hash, privacy: .public)"
            )
            // Deliberately untouched: doors only link rows they insert; healing is the backfill's job.
            return ArchiveResult(pgn: existing, deduplicated: true)
        }
        
        try insertNewGame(pgn, hash: hash)
        
        Self.logger?.info(
            "Archived: '\(pgn.name, privacy: .public)' [\(pgn.result.rawValue, privacy: .public)] plies=\(pgn.moves.count)"
        )
        return ArchiveResult(pgn: pgn, deduplicated: false)
    }
    
    /// Recomputes and persists `contentHash` after an in-place edit - skipping it lets dedupe rot
    /// against stale hashes ("any in-place edit must call `refreshHash`").
    func refreshHash(of pgn: PGN) throws {
        pgn.contentHash = Self.contentHash(for: pgn)
        try modelContext.save()
        Self.logger?.info("Refreshed content hash for '\(pgn.name, privacy: .public)'")
    }
    
    /// One-hash/two-doors made structural: every in-place edit funnels through here, so mutation
    /// and rehash cannot be separated by a forgetful caller. Re-resolves both seats unconditionally.
    func applyEdit(to pgn: PGN, _ edit: (PGN) -> Void) throws {
        // The only rows this edit can strand are the two it is about to re-resolve away
        // from - captured before the edit, checked after (the rule, scoped).
        let displaced = [pgn.whitePlayer, pgn.blackPlayer].compactMap { $0 }
        edit(pgn)
        try resolvePlayers(for: pgn)
        collectOrphanedPlayers(among: displaced)
        try refreshHash(of: pgn)   // saves - one transaction covers all three
    }
    
    // MARK: Movetext Edit (M-lib.3)
    
    /// Applies edited movetext, validated by full replay (`MovetextEdit`). `.failure` names the
    /// first offending ply and nothing mutates; `.success` stores canonical moves, invalidates stored
    /// evaluations, re-classifies, rehashes - one transaction. Seats untouched: movetext cannot edit them.
    /// `throws` is reserved for the SwiftData save.
    func applyMovetextEdit(
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
            pgn.analysisDepths = []    // travels with `evaluations`, always
            classify(pgn)              // re-derived, not cleared - see the note above
            try refreshHash(of: pgn)   // recompute hash + save - one transaction
            Self.logger?.info(
                "Applied movetext edit to '\(pgn.name, privacy: .public)' plies=\(accepted.moves.count)"
            )
            return .success(accepted.moves)
        }
    }
    
    /// Forwards to the batch door - the orphan cascade and transaction shape have exactly one implementation.
    func delete(_ pgn: PGN) throws {
        try delete([pgn])
    }

    /// Deletes games in one transaction. Players stranded by the deletion go with it - computed
    /// **before** the first delete: `.nullify` propagation cannot be relied on afterwards.
    func delete(_ pgns: [PGN]) throws {
        guard !pgns.isEmpty else { return }
        let stranded = Self.playersOrphaned(byDeleting: pgns)
        let subject = pgns.count == 1 ? "'\(pgns[0].name)'" : "\(pgns.count) games"
        Self.logger?.info("Deleting \(subject, privacy: .public)")
        for pgn in pgns {
            modelContext.delete(pgn)
        }
        for player in stranded {
            Self.logger?.info(
                "Collecting '\(player.name, privacy: .public)', its last game went with this deletion"
            )
            modelContext.delete(player)
        }
        try modelContext.save()
    }
    
    // MARK: Player Resolution (M-prs.1)
    /// Links both seats to `Player` identities. Save-free by contract: every caller ends in its own save.
    func resolvePlayers(for pgn: PGN) throws {
        pgn.whitePlayer = try resolvePlayer(named: pgn.white)
        pgn.blackPlayer = try resolvePlayer(named: pgn.black)
    }
    
    /// The single creation door for `Player`. Tags fold through `PlayerName.displayForm` then match on
    /// `normalizedName`; `"?"` and empty resolve to nil - the *absence* of a player, never a player named "?".
    func resolvePlayer(named rawTag: String) throws -> Player? {
        // Placeholder rule + identity fold live on `Player.identity(forTag:)` - one spelling.
        guard let key = Player.identity(forTag: rawTag) else { return nil }
        let display = PlayerName.displayForm(of: rawTag)

        if let existing: Player = try first(#Predicate { $0.normalizedName == key }) {
            return existing
        }

        // First-seen tag form, whitespace-folded only - comma structure, casing, diacritics verbatim.
        let player = Player(name: display, tagName: PlayerName.folded(rawTag))
        modelContext.insert(player)
        Self.logger?.info("Created player '\(display, privacy: .public)'")
        return player
    }
    
    /// Read-only bridge from `PlayerStats.ID` (= `normalizedName`) to the model - **never creates**.
    func player(withNormalizedKey key: String) throws -> Player? {
        try first(#Predicate { $0.normalizedName == key })
    }
    
    /// The two player backfills behind the converged stamp: once one pass heals zero rows
    /// the stamp is set and every later appearance skips the app's most-run full-table scan.
    /// Safe to gate because imports link at the door, so no door can re-create the work; the one
    /// residual risk - a save that failed after an in-memory link - is priced in the anchor, and
    /// the recovery is deleting the default. `defaults` injectable for the suite.
    func healPlayersIfNeeded(defaults: UserDefaults = .standard) throws {
        guard !defaults.bool(forKey: StorageKeys.playerBackfillsConverged) else { return }
        let healed = try backfillPlayerLinks() + backfillPlayerTagNames()
        if healed == 0 {
            defaults.set(true, forKey: StorageKeys.playerBackfillsConverged)
            Self.logger?.info("Player backfills converged - stamped; the per-appearance scan retires")
        }
    }

    /// The `onAppear` spelling of the above: build the store, heal, swallow the failure into a log.
    /// Both collection destinations need players linked whether or not the other was visited this
    /// launch, and each carried this as a byte-identical private method until 18 Aug 2026.
    ///
    /// **`logger` is a parameter and that is not "who's calling".** A category is a contract with
    /// the console - manual checks stream `category == "library"` and `== "players"` by name - so
    /// folding both callers onto this type's own `.pgnstore` would silently empty two predicates.
    /// The caller passes the category it already publishes under; the *work* lives once.
    static func healPlayers(in modelContext: ModelContext, logger: Logger?) {
        do {
            try PGNStore(modelContext: modelContext).healPlayersIfNeeded()
        } catch {
            logger?.error("Player-link backfill failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Links rows predating the M-prs.1 schema. Idempotent, called through `healPlayersIfNeeded`.
    /// Fetch-all-and-scan deliberately: a nil `whitePlayer` on a `"?"` row is *correct*, not missing.
    @discardableResult
    func backfillPlayerLinks() throws -> Int {
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
        // The healing arm for orphans predating the rule - nothing else ever touches them.
        // Deliberately **after** the relink loop: before it, this would delete rows the loop is about to link.
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

    /// Heals `Player.tagName` on pre-schema rows: "first seen" reconstructed as the seat tag of the
    /// earliest linked game (chronological-order philosophy) - deterministic.
    @discardableResult
    func backfillPlayerTagNames() throws -> Int {
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
    
    // MARK: Classification
    /// Stamps derived classification - opening and mate motif - from stored moves. Save-free by
    /// contract (`resolvePlayers` precedent). Both columns stamped together or not at all (`PGN.opening`'s invariant).
    @discardableResult
    func classify(_ pgn: PGN, using table: ECOClassifier = ECOTable.bundled) -> Bool {
        let result = GameClassification.classify(moves: pgn.moves, using: table)
        guard result.opening != pgn.opening
                || result.openingPlies != pgn.ecoDepth
                || result.specialCheckmate != pgn.specialCheckmate else { return false }
        pgn.ecoCode = result.opening?.code
        pgn.ecoFamily = result.opening?.family
        pgn.ecoVariation = result.opening?.variation
        pgn.ecoDepth = result.openingPlies   // the book skip's input
        pgn.specialCheckmate = result.specialCheckmate
        return true
    }

    /// Classifies rows with `ecoCode == nil` - deliberately conflating "not yet classified" with
    /// "classified, unnamed"; cheap because the table names all twenty first moves
    /// (`everyPlayedGameGetsAName`). Library `onAppear` only; predicated, unlike the link backfill.
    @discardableResult
    func backfillClassifications(
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

    // MARK: Player Retag, Merge and Delete

    /// One game a retag touches, and which seats. **Both flags on one entry per game**: a player can
    /// hold both sides, and per-seat entries compute two hashes, neither the row's real future hash.
    private struct Rewrite {
        let game: PGN
        let isWhite: Bool
        let isBlack: Bool
    }

    /// A game and the row its rewritten hash would collide with. Identifiers and names, never models
    /// (`Error.duplicate` precedent - `Swift.Error` refines `Sendable`).
    struct HashCollision: Sendable {
        /// The game being retagged.
        let gameID: PersistentIdentifier
        let gameName: String
        /// The row its rewritten hash would land on.
        let existingID: PersistentIdentifier
        let existingName: String
    }

    /// Pre-flight refusals: nothing has been written when one of these is thrown.
    enum RetagRejection: Swift.Error {
        /// The rewrite would hand a game a hash another row already owns.
        case wouldCollide([HashCollision])
        /// A retag to `"?"`/empty is a deletion wearing a rename's clothes - refused.
        case emptyTag
    }

    /// Rewrites every game `player` appears in to carry `newTag` in that seat, re-resolves, rehashes -
    /// the single door through which a stored seat tag changes identity. `newTag` is **tag
    /// form**. Pre-flight and all-or-nothing: a refusal leaves the archive untouched.
    /// Cost, accepted: seat tags are inside the hash, so pre-rename exports no longer dedupe.
    @discardableResult
    func retag(_ player: Player, to newTag: String) throws -> Int {
        let display = PlayerName.displayForm(of: newTag)
        guard !display.isEmpty, display != "?" else { throw RetagRejection.emptyTag }

        let rewrites = Self.rewrites(for: player)
        guard !rewrites.isEmpty else { return 0 }

        try refuseCollisions(in: rewrites, becoming: newTag)

        for rewrite in rewrites {
            if rewrite.isWhite { rewrite.game.white = newTag }
            if rewrite.isBlack { rewrite.game.black = newTag }
            // Re-resolve then rehash, the `applyEdit` order - but one transaction over the whole rewrite.
            try resolvePlayers(for: rewrite.game)
            rewrite.game.contentHash = Self.contentHash(for: rewrite.game)
        }
        // The renamed-from row is the rename's whole residue, collected in the same
        // transaction - scoped to it. This is what makes rename the merge replacement
        // it was designed to be.
        collectOrphanedPlayers(among: [player])
        try modelContext.save()
        Self.logger?.info(
            "Retagged player to '\(newTag, privacy: .public)' across \(rewrites.count) game(s)"
        )
        return rewrites.count
    }

    /// Every game `player` appears in, once - union of both relationship arrays; both-seat rows get one `Rewrite`.
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

    /// Deletes every registry row nothing points at - the PGN files are the source of truth.
    /// Safe because `resolvePlayer`'s two callers both link immediately, so a linkless row is always a
    /// leftover, never in transit (a future create-then-link-later door trips this loudly). Save-free.
    /// Fetch-all-and-scan: `isOrphaned` reads relationships, which `#Predicate` cannot. The
    /// backfill's arm - the editing doors pass only the rows they displaced.
    @discardableResult
    func collectOrphanedPlayers() -> Int {
        guard let players = try? modelContext.fetch(FetchDescriptor<Player>()) else {
            // A failed fetch means no collection this pass, never a partial one; the next door retries.
            Self.logger?.error("Orphan collection skipped, player fetch failed")
            return 0
        }
        return collectOrphanedPlayers(among: players)
    }

    /// The scoped core: the same rule over only `candidates`. A self-play edit passes one
    /// row twice - the `isDeleted` guard makes the second visit a no-op, never a double delete.
    @discardableResult
    func collectOrphanedPlayers(among candidates: [Player]) -> Int {
        var collected = 0
        for player in candidates where !player.isDeleted && Self.isOrphaned(player) {
            Self.logger?.info(
                "Collecting orphaned player '\(player.name, privacy: .public)', no game references it"
            )
            modelContext.delete(player)
            collected += 1
        }
        return collected
    }

    /// The one spelling of "nothing points at this row" - a second spelling is the twin-read-site pattern.
    static func isOrphaned(_ player: Player) -> Bool {
        player.whiteGames.isEmpty && player.blackGames.isEmpty
    }

    /// `isOrphaned`'s **prospective twin** - the players `pgns` would strand, asked before any delete
    /// (`.nullify` propagation cannot be relied on afterwards; "the array still looks fine" is the trap).
    static func playersOrphaned(byDeleting pgns: [PGN]) -> [Player] {
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


    /// The pre-flight. Two collision sources, and missing the second is the easy bug: an existing
    /// Library row, *or* another game in this same batch (not yet stored under its future hash).
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

    /// Reads a collision at the one point both live rows are in hand, so the `Sendable` payload never reaches back.
    private static func collision(_ game: PGN, against existing: PGN) -> HashCollision {
        HashCollision(
            gameID: game.persistentModelID,
            gameName: game.name,
            existingID: existing.persistentModelID,
            existingName: existing.name
        )
    }

    // MARK: Private Helpers

    /// The shared tail of both doors. Ordering carries weight: `resolvePlayers` before the save (one
    /// transaction); persisting the hash is what makes future dedupe lookups hit at all.
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
            // `throws(PGNParser.Error)` - the switch is exhaustive by the compiler, no cast needed.
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
    
    /// Fetch-limit-1 lookup; the limit is the load-bearing part.
    private func first<T: PersistentModel>(_ predicate: Predicate<T>) throws -> T? {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
    
    private func existingPGN(withHash hash: String) throws -> PGN? {
        try first(#Predicate { $0.contentHash == hash })
    }
    
    // MARK: Static Methods
    /// Model-typed spelling - a thin forward to the field-typed twin, which exists so the collision pre-flight can ask
    /// "what hash *would* this row carry" without mutate-and-revert or a second copy of the recipe.
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

    /// The recipe: MD5 of the eight fields joined by `|`, in this order, **forever** - every stored
    /// hash depends on it. `timeControl`, `board`, classification, `libraryIndex` deliberately absent.
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
        // `map`, not `compactMap`: nothing is nil, and the old verb asked which bytes get dropped.
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// The hash after every touched seat becomes `newTag` - asked without writing. Both flags
    /// substituted in one call (per-seat asking yields two hashes the game will never have).
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
    
    /// **Persistence contract** (see `hashDateString`): byte-identical forever. Lowercasing commutes
    /// with the fold, so routing through `PlayerName.folded` was a refactor, not a change.
    private static func normalize(_ value: String) -> String {
        PlayerName.folded(value).lowercased()
    }
}
