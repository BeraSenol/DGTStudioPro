import Foundation

/// The single source of truth for the Stockfish options the app controls —
/// born from the M11 decoupling review, which caught the Settings pane
/// asserting configuration that lived nowhere: "Depth 20" (the real default
/// was 18, duplicated across two `analyze` signatures) and "Hash 128 MB /
/// Threads 1" (never sent, so the engine silently ran on Stockfish's own
/// defaults — 16 MB of hash). Every consumer now reads *this* type: the
/// Settings pane binds to the same keys, `GameAnalysisDriver` takes its
/// depth default from `current`, and `StockfishEngine.start()` sends
/// `uciOptionLines` in the `uciok` → `isready` window per the UCI contract.
///
/// Values clamp on init, so a stale or hand-edited defaults plist can never
/// push the engine outside sane bounds. Rejected: `UserDefaults.register` —
/// clamping at the single read site is stronger, because it also repairs
/// out-of-range values that are *present*, which registration can't.
internal struct EngineConfiguration: Equatable, Sendable {
    
    // MARK: Bounds
    
    /// 8 is the floor where per-ply evaluations stop being noise; 30 is the
    /// ceiling where a full-game pass stops being an interactive wait.
    internal static let depthRange = 8...30
    
    /// The transposition-table sizes offered in Settings. Stockfish accepts
    /// arbitrary megabyte values; a fixed menu keeps the choice legible and
    /// gives the clamp a nearest-size snap target.
    internal static let hashChoicesMB = [16, 64, 128, 256, 512, 1024]
    
    /// One thread minimum; the machine's active cores as the ceiling.
    /// Computed, not stored — core count is a fact about the host.
    internal static var threadsRange: ClosedRange<Int> {
        1...max(1, ProcessInfo.processInfo.activeProcessorCount)
    }

    // MARK: Syzygy Bounds

    /// Stockfish's own range for `SyzygyProbeDepth`, taken from its option
    /// advertisement rather than invented: `spin default 1 min 1 max 100`.
    ///
    /// The knob is "how shallow in the tree may we probe". 1 probes everywhere
    /// and is the most accurate; raising it trades tablebase hits for search
    /// speed, which matters when the tables sit on a spinning disk or a network
    /// volume. Left at 1 by default because this app analyzes archived games
    /// off a local SSD, where the probe is cheap.
    internal static let syzygyProbeDepthRange = 1...100

    /// `SyzygyProbeLimit`, `spin default 7 min 0 max 7` — the largest piece
    /// count to probe.
    ///
    /// **7 is a ceiling, not a promise.** Setting it to 7 with only 3-4-5 tables
    /// installed costs nothing: the engine probes what exists. Lowering it is
    /// how you stop probing a set you *have* — the case being a 7-piece
    /// collection on slow storage where the largest tables are the expensive
    /// ones. Zero disables probing entirely while keeping the path configured,
    /// which is a useful A/B and the reason the range starts there rather than
    /// at 3.
    internal static let syzygyProbeLimitRange = 0...7

    // MARK: Values

    internal let depth: Int
    internal let hashMB: Int
    internal let threads: Int

    /// The tablebase folder, as a plain filesystem path, or nil when none is
    /// configured.
    ///
    /// **A resolved path rather than a bookmark, and this type never opens
    /// it.** `SyzygyPath` is a UCI option and UCI options are strings; the
    /// security-scoped access that makes the path openable is `SyzygyLocation`'s
    /// job and must outlive this value — see the note on `current(syzygyPath:)`
    /// for why that separation is load-bearing rather than tidy.
    internal let syzygyPath: String?

    internal let syzygyProbeDepth: Int
    internal let syzygy50MoveRule: Bool
    internal let syzygyProbeLimit: Int
    
    /// Depth 18 preserves the pre-configuration behavior exactly (the old
    /// twin default, now living once); 128 MB makes the Settings pane's
    /// long-standing promise true; 1 thread keeps analysis polite to the
    /// rest of the app.
    /// The Syzygy members default to **Stockfish's own defaults**, deliberately
    /// spelled here rather than left implicit: with no path configured this
    /// type emits no Syzygy options at all, so the values only ever describe
    /// what the engine would have done anyway.
    internal static let `default` = EngineConfiguration(depth: 18, hashMB: 128, threads: 1)

    /// Clamps depth and threads into range; snaps hash to the nearest
    /// offered size, so a plist-edited 100 becomes 128 rather than
    /// rejecting or defaulting. The two Syzygy spins clamp the same way,
    /// against the ranges Stockfish itself advertises.
    ///
    /// An **empty** `syzygyPath` folds to nil rather than being passed through.
    /// `setoption name SyzygyPath value ` with nothing after it is a real
    /// command that Stockfish reads as "clear the tables", and a cleared path
    /// and an unconfigured one are the same state — so representing them
    /// identically is what stops "no tablebases" having two spellings.
    internal init(
        depth: Int,
        hashMB: Int,
        threads: Int,
        syzygyPath: String? = nil,
        syzygyProbeDepth: Int = 1,
        syzygy50MoveRule: Bool = true,
        syzygyProbeLimit: Int = 7
    ) {
        self.depth = depth.clamped(to: Self.depthRange)
        self.hashMB = Self.hashChoicesMB.min {
            abs($0 - hashMB) < abs($1 - hashMB)
        } ?? Self.hashChoicesMB[0]
        self.threads = threads.clamped(to: Self.threadsRange)

        let trimmed = syzygyPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.syzygyPath = (trimmed?.isEmpty ?? true) ? nil : trimmed
        self.syzygyProbeDepth = syzygyProbeDepth.clamped(to: Self.syzygyProbeDepthRange)
        self.syzygy50MoveRule = syzygy50MoveRule
        self.syzygyProbeLimit = syzygyProbeLimit.clamped(to: Self.syzygyProbeLimitRange)
    }
    
    // MARK: Persistence
    
    /// The persisted configuration, clamped on read. `UserDefaults` is
    /// thread-safe, so this is callable from the engine actor at launch and
    /// from the driver's default argument at each analyze call. Settings
    /// changes therefore apply to the *next* run with no restart story:
    /// depth is read per call, and hash/threads are read at engine launch —
    /// which M-batch guarantees happens per run, since the engine releases
    /// at drain.
    internal static var current: EngineConfiguration {
        current(syzygyPath: nil)
    }

    /// The persisted configuration with a tablebase folder threaded in.
    ///
    /// **The path is a parameter rather than another `UserDefaults` read, and
    /// that asymmetry is the point.** Every other value here is a number in the
    /// plist; the Syzygy folder is a security-scoped resource that has to be
    /// *held open* while the engine runs. Reading it here would produce a path
    /// string whose access token had already been released by the time this
    /// function returned — a path that looks right and opens nothing. The
    /// caller resolves it, keeps the token, and passes what it opened.
    ///
    /// `StockfishEngine.start()` is the one caller that passes a path;
    /// `GameAnalysisDriver`'s depth default takes the pathless form, since it
    /// wants one number and starts no engine.
    internal static func current(
        syzygyPath: String?,
        in defaults: UserDefaults = .standard
    ) -> EngineConfiguration {
        EngineConfiguration(
            depth: defaults.object(forKey: StorageKeys.analysisDepth) as? Int
            ?? Self.default.depth,
            hashMB: defaults.object(forKey: StorageKeys.engineHashMB) as? Int
            ?? Self.default.hashMB,
            threads: defaults.object(forKey: StorageKeys.engineThreads) as? Int
            ?? Self.default.threads,
            syzygyPath: syzygyPath,
            syzygyProbeDepth: defaults.object(forKey: StorageKeys.syzygyProbeDepth) as? Int
            ?? Self.default.syzygyProbeDepth,
            syzygy50MoveRule: defaults.object(forKey: StorageKeys.syzygy50MoveRule) as? Bool
            ?? Self.default.syzygy50MoveRule,
            syzygyProbeLimit: defaults.object(forKey: StorageKeys.syzygyProbeLimit) as? Int
            ?? Self.default.syzygyProbeLimit
        )
    }

    // MARK: UCI

    /// The `setoption` lines `StockfishEngine.start()` sends after `uciok`
    /// and before `isready` — the UCI contract's one window for options.
    ///
    /// **`SyzygyPath` goes last, and the order is not cosmetic.** Stockfish
    /// loads the tables synchronously when that option is set and answers with
    /// an `info string` naming what it found; sending it after the others keeps
    /// that answer as the final line of the option block, where
    /// `StockfishEngine` reads it without having to correlate it against
    /// anything. The other three configure the probe and mean nothing until
    /// there are tables to probe.
    ///
    /// **All four are omitted entirely with no path.** Sending
    /// `SyzygyProbeDepth` to an engine with no tables is harmless and
    /// meaningless, and it would put four lines in every UCI log for a feature
    /// nobody has switched on — the log-noise argument D63′ makes about the
    /// engine's own option advertisement, applied to our half of the
    /// conversation.
    internal var uciOptionLines: [String] {
        var lines = [
            "setoption name Hash value \(hashMB)",
            "setoption name Threads value \(threads)",
        ]
        guard let syzygyPath else { return lines }
        lines.append("setoption name SyzygyProbeDepth value \(syzygyProbeDepth)")
        lines.append("setoption name Syzygy50MoveRule value \(syzygy50MoveRule)")
        lines.append("setoption name SyzygyProbeLimit value \(syzygyProbeLimit)")
        lines.append("setoption name SyzygyPath value \(syzygyPath)")
        return lines
    }
}

extension Comparable {
    /// The standard clamp the stdlib doesn't ship. Two hand-rolled
    /// `min(max(…))` pairs in the initializer above were the whole reason
    /// this file had arithmetic in it at all.
    internal func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
