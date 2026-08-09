import Foundation
import os

/// Atomic single-file persistence for the one draft: atomic writes mean a crash mid-write
/// leaves the previous draft, never a torn file. Directory injectable for tests. The store is
/// dumb on purpose — the session owns *when*.
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
