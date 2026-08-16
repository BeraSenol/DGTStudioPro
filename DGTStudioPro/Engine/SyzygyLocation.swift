import Foundation
import os

/// Where the Syzygy tablebases live, and whether anything can read them. Exists because the
/// answer is not obvious under the sandbox: the *engine subprocess* does the reading, and
/// inheritance covers only static entitlements - so the type reports **two numbers** (what the
/// app sees, what Stockfish says it loaded) rather than assuming they agree.
enum SyzygyLocation {

    // MARK: Static Constants

    /// `.engine`, not `.analysis`: the engine's resources - one `log stream` predicate follows the
    /// whole story.
    private static let logger = AppLog.logger(.engine)

    /// The census counts WDL: the half Stockfish needs to probe at all (DTZ only refines the root).
    /// Counting DTZ over a half-download would be a convincing lie.
    private static let wdlExtension = "rtbw"

    /// DTZ counted separately, so a half-download is visible as an asymmetry.
    private static let dtzExtension = "rtbz"

    // MARK: Access Token

    /// Holds a security-scoped resource open for its lifetime - the `ActivityToken` shape: balance
    /// as a fact about object lifetime. The engine holds one per run.
    final class Access {
        private let url: URL
        private let didStart: Bool

        var path: String { url.path(percentEncoded: false) }

        init?(resolving bookmark: Data) {
            var stale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else {
                SyzygyLocation.logger?.error("Syzygy bookmark could not be resolved")
                return nil
            }
            // A stale bookmark still resolves - logged, not refused: refusing turns "you moved the folder"
            // into "tablebases silently stopped working".
            if stale {
                SyzygyLocation.logger?.info("Syzygy bookmark is stale; still resolving")
            }
            self.url = url
            self.didStart = url.startAccessingSecurityScopedResource()
        }

        deinit {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }
    }

    // MARK: Storage

    /// Stores the folder as a security-scoped bookmark (nil clears). Returns whether it stuck -
    /// swallowing a failed bookmark leaves Settings showing a path the next launch cannot open.
    @discardableResult
    static func store(
        _ url: URL?,
        in defaults: UserDefaults = .standard
    ) -> Bool {
        guard let url else {
            defaults.removeObject(forKey: StorageKeys.syzygyBookmark)
            defaults.removeObject(forKey: StorageKeys.syzygyDisplayPath)
            return true
        }
        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(bookmark, forKey: StorageKeys.syzygyBookmark)
            // The path rides along purely for display - a label, never the thing opened; resolving the
            // bookmark is the only way in.
            defaults.set(url.path(percentEncoded: false), forKey: StorageKeys.syzygyDisplayPath)
            return true
        } catch {
            logger?.error(
                "Syzygy bookmark creation failed: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    /// Display path, or nil. Never use as the `SyzygyPath` value - see `access(in:)`.
    static func displayPath(in defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: StorageKeys.syzygyDisplayPath)
    }

    /// Opens the configured folder, or nil. **Hold the token for the length of the run** -
    /// releasing it closes the resource under a subprocess still probing.
    static func access(in defaults: UserDefaults = .standard) -> Access? {
        guard let bookmark = defaults.data(forKey: StorageKeys.syzygyBookmark) else { return nil }
        return Access(resolving: bookmark)
    }

    // MARK: Census

    /// What the **app** can see - the diagnostic's first number. Counted per extension; shallow,
    /// like `SyzygyPath` itself.
    struct Census: Equatable, Sendable {
        let wdl: Int
        let dtz: Int

        var isEmpty: Bool { wdl == 0 && dtz == 0 }

        /// "290 WDL · 290 DTZ", or a named absence - kept beside the count so the two cannot drift.
        var summary: String {
            isEmpty ? "No tablebase files found" : "\(wdl) WDL · \(dtz) DTZ"
        }
    }

    /// Requires a live token: without one the listing itself fails under the sandbox - zero for the
    /// wrong reason.
    static func census(at access: Access) -> Census {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: access.path) else {
            logger?.error("Syzygy folder could not be listed at '\(access.path, privacy: .public)'")
            return Census(wdl: 0, dtz: 0)
        }
        var wdl = 0
        var dtz = 0
        for name in names {
            switch (name as NSString).pathExtension {
            case wdlExtension: wdl += 1
            case dtzExtension: dtz += 1
            default:           break
            }
        }
        return Census(wdl: wdl, dtz: dtz)
    }
}
