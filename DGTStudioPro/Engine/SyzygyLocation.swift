import Foundation
import os

/// Where the Syzygy endgame tablebases live, and whether anything can actually
/// read them.
///
/// **This type exists because the answer is not obvious under the app sandbox,
/// and the whole feature turns on it.** Stockfish probes tablebases itself, from
/// its own process — the app never opens a `.rtbw` file. So the question is not
/// "can the app read this folder" but "can the *child* read it", and those have
/// different answers here:
///
/// - The app reaches a user-picked folder through PowerBox, which is a right
///   granted **after launch**.
/// - `Process`-spawned children inherit the parent's sandbox, and Apple's
///   documentation is explicit that inheritance covers only the **static**
///   rights in the entitlements file — "not any rights added to your sandbox
///   after launch (such as PowerBox access to files)".
///
/// Read literally, that means `setoption name SyzygyPath` pointing anywhere
/// outside the app's own container will leave Stockfish finding nothing. It has
/// not been measured here, which is why this type reports **two numbers rather
/// than one**: what the app can see (`visibleTableFileCount`) and what the
/// engine reported finding (`StockfishEngine.tablebaseReport`). A folder where
/// the first is 290 and the second is 0 is the sandbox blocking the child, said
/// out loud instead of looking like a wrong path. That diagnostic is worth
/// keeping even after the question is settled — it is also what a typo, an
/// unmounted volume, or a folder of `.rtbz` files with no `.rtbw` looks like.
///
/// **A security-scoped bookmark, not a path string.** A stored path gives the
/// app nothing on the next launch; the bookmark is what makes the folder
/// re-openable without asking again. That the app needs this at all is a
/// side effect of wanting to *census* the folder — the engine is handed a plain
/// filesystem path either way, because a UCI option is a string.
internal enum SyzygyLocation {

    // MARK: Static Constants

    /// `.engine` rather than `.analysis`: this is about the engine's resources,
    /// and it is read from Settings with no analysis running as often as from a
    /// pass. `StockfishEngine` logs the resulting report under the same
    /// category, so one `log stream` predicate follows the whole story.
    private static let logger = AppLog.logger(.engine)

    /// The WDL file extension. The census counts these rather than `.rtbz`
    /// because WDL is the half Stockfish needs to probe at all — DTZ only
    /// refines the answer at the root. A folder with DTZ and no WDL is a
    /// half-download, and reporting "290 files" over it would be a lie of the
    /// most convincing kind.
    private static let wdlExtension = "rtbw"

    /// The DTZ half, counted separately so the diagnostic can say "290 WDL,
    /// 290 DTZ" and make a half-download visible as an asymmetry.
    private static let dtzExtension = "rtbz"

    // MARK: Access Token

    /// Holds a security-scoped resource open for as long as it lives.
    ///
    /// The `ActivityToken` shape D14′ chose for the same reason: `start` and
    /// `stop` must be balanced, and balance is a fact about object lifetime
    /// rather than two call sites that have to agree. The engine holds one for
    /// the length of a run.
    internal final class Access {
        private let url: URL
        private let didStart: Bool

        internal var path: String { url.path(percentEncoded: false) }

        internal init?(resolving bookmark: Data) {
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
            // A stale bookmark still resolves and is still usable; it simply
            // wants rewriting. Logged rather than refused, because refusing
            // would turn "you moved the folder" into "tablebases silently
            // stopped working".
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

    /// Stores the folder as a security-scoped bookmark, or clears it for nil.
    ///
    /// Returns whether it stuck. A bookmark can fail to be created — an
    /// unmounted volume, a folder the panel never actually granted — and
    /// swallowing that would leave Settings showing a path the next launch
    /// cannot open.
    @discardableResult
    internal static func store(
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
            // The path is stored *alongside* the bookmark purely so Settings
            // can show something without resolving and holding a scoped
            // resource on every body pass. It is a label, never the thing
            // opened — resolving the bookmark is the only way in.
            defaults.set(url.path(percentEncoded: false), forKey: StorageKeys.syzygyDisplayPath)
            return true
        } catch {
            logger?.error(
                "Syzygy bookmark creation failed: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    /// The folder's path for display, or nil when none is configured. Never
    /// use this as the `SyzygyPath` value — see `access(in:)`.
    internal static func displayPath(in defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: StorageKeys.syzygyDisplayPath)
    }

    /// Opens the configured folder, or nil when none is set or it no longer
    /// resolves. **The caller must hold the returned token for as long as the
    /// engine runs** — releasing it closes the scoped resource under a
    /// subprocess that is still probing.
    internal static func access(in defaults: UserDefaults = .standard) -> Access? {
        guard let bookmark = defaults.data(forKey: StorageKeys.syzygyBookmark) else { return nil }
        return Access(resolving: bookmark)
    }

    // MARK: Census

    /// What the **app** can see in the folder — the first of the diagnostic's
    /// two numbers.
    ///
    /// Counted rather than sampled, and counted per extension, because the
    /// failure modes it has to tell apart are all shaped like a count: nothing
    /// there (wrong folder), WDL but no DTZ (half a download), and a healthy
    /// pair. Shallow, not recursive: `SyzygyPath` is not recursive either, so a
    /// recursive count would report files the engine will never find.
    internal struct Census: Equatable, Sendable {
        internal let wdl: Int
        internal let dtz: Int

        internal var isEmpty: Bool { wdl == 0 && dtz == 0 }

        /// "290 WDL · 290 DTZ", or a named absence. Kept beside the count so
        /// the two cannot drift.
        internal var summary: String {
            isEmpty ? "No tablebase files found" : "\(wdl) WDL · \(dtz) DTZ"
        }
    }

    /// Counts what the app can read at `access`'s folder. Requires a live
    /// token: without one the directory listing itself fails under the sandbox,
    /// which would report zero for the wrong reason.
    internal static func census(at access: Access) -> Census {
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
