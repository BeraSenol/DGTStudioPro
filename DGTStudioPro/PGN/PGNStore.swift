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
internal struct PGNStore {

    // MARK: Static Constants
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "pgnstore"
    )

    private static let hashDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    // MARK: Errors
    @MainActor
    internal enum Error: Swift.Error {
        case duplicate(existing: PGN)
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
    @MainActor
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
            throw Error.duplicate(existing: existing)
        }

        // Persist the computed hash on the model so subsequent imports of
        // the same game can find it via `existingPGN(withHash:)`. Without
        // this assignment the row is stored with an empty `contentHash`,
        // every future lookup misses, and deduplication silently no-ops.
        pgn.contentHash = hash
        modelContext.insert(pgn)
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
    /// duplicating. `@MainActor` because it reads the `@MainActor`
    /// `LiveGame` and returns a model-bearing result.
    @MainActor
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
            return ArchiveResult(pgn: existing, deduplicated: true)
        }

        pgn.contentHash = hash
        modelContext.insert(pgn)
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
            pgn.date.map(hashDateFormatter.string(from:)) ?? "",
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
