//
//  LiveGameDraftStore.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 13/06/2026.
//

import Foundation
import os

/// Atomic single-file persistence for the one `LiveGameDraft` (M4.1).
///
/// One draft, one file: `LiveGameDraft.json` in Application Support (the
/// sandbox container already scopes that directory to this app). Writes are
/// atomic, so a crash mid-save leaves either the old draft or the new one —
/// never a torn file. The directory is injectable so tests run against a
/// temp directory and never touch the real sidecar.
///
/// The store is dumb on purpose: it moves bytes and validates the schema
/// version, nothing else. *When* to save, load, or delete is the session's
/// policy (M4.2); *what* a draft means is `LiveGameDraft`'s schema.
@MainActor
internal final class LiveGameDraftStore {

    // MARK: Static Constants

    private static let logger = AppLog.logger(.dgt)

    private static let fileName = "LiveGameDraft.json"

    // MARK: Errors

    internal enum StoreError: Error, Equatable {
        /// The file decoded, but its `schemaVersion` isn't one this build
        /// understands. Treated as corrupt by callers — never guessed at.
        case unsupportedSchema(found: Int)
    }

    // MARK: Stored Properties

    /// Full path of the draft file. Exposed for tests and diagnostics.
    internal let fileURL: URL

    private let directory: URL

    // MARK: Initializer

    /// - Parameter directory: where the draft file lives. Defaults to the
    ///   app's Application Support directory; tests inject a temp directory.
    internal init(directory: URL = .applicationSupportDirectory) {
        self.directory = directory
        self.fileURL = directory.appending(path: Self.fileName)
    }

    // MARK: I/O

    /// Atomically writes `draft`, replacing any previous one (last write
    /// wins — there is only ever one draft). Creates the directory on first
    /// use. Throws on encoding or filesystem failure; the caller decides how
    /// loudly to react.
    internal func save(_ draft: LiveGameDraft) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try LiveGameDraft.encoder().encode(draft)
        try data.write(to: fileURL, options: [.atomic])
        Self.logger?.debug("Draft saved (\(draft.sanMoves.count) plies)")
    }

    /// Loads the draft, or `nil` when no file exists (the common launch).
    /// Throws when a file exists but can't be read, doesn't decode, or
    /// carries an unknown schema version — "absent" and "corrupt" are
    /// different answers, and the session surfaces them differently.
    internal func load() throws -> LiveGameDraft? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        let draft = try LiveGameDraft.decoder().decode(LiveGameDraft.self, from: data)
        guard draft.schemaVersion == LiveGameDraft.currentSchemaVersion else {
            throw StoreError.unsupportedSchema(found: draft.schemaVersion)
        }
        return draft
    }

    /// Removes the draft file. Idempotent — deleting an absent draft is not
    /// an error (discard and archive paths both call this unconditionally).
    internal func delete() {
        do {
            try FileManager.default.removeItem(at: fileURL)
            Self.logger?.debug("Draft deleted")
        } catch CocoaError.fileNoSuchFile {
            // Already gone — exactly the desired end state.
        } catch {
            Self.logger?.error(
                "Draft delete failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
