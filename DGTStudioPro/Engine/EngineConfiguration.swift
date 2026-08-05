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
    
    // MARK: Values
    
    internal let depth: Int
    internal let hashMB: Int
    internal let threads: Int
    
    /// Depth 18 preserves the pre-configuration behavior exactly (the old
    /// twin default, now living once); 128 MB makes the Settings pane's
    /// long-standing promise true; 1 thread keeps analysis polite to the
    /// rest of the app.
    internal static let `default` = EngineConfiguration(depth: 18, hashMB: 128, threads: 1)
    
    /// Clamps depth and threads into range; snaps hash to the nearest
    /// offered size, so a plist-edited 100 becomes 128 rather than
    /// rejecting or defaulting.
    internal init(depth: Int, hashMB: Int, threads: Int) {
        self.depth = depth.clamped(to: Self.depthRange)
        self.hashMB = Self.hashChoicesMB.min {
            abs($0 - hashMB) < abs($1 - hashMB)
        } ?? Self.hashChoicesMB[0]
        self.threads = threads.clamped(to: Self.threadsRange)
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
        let defaults = UserDefaults.standard
        return EngineConfiguration(
            depth: defaults.object(forKey: StorageKeys.analysisDepth) as? Int
            ?? Self.default.depth,
            hashMB: defaults.object(forKey: StorageKeys.engineHashMB) as? Int
            ?? Self.default.hashMB,
            threads: defaults.object(forKey: StorageKeys.engineThreads) as? Int
            ?? Self.default.threads
        )
    }
    
    // MARK: UCI
    
    /// The `setoption` lines `StockfishEngine.start()` sends after `uciok`
    /// and before `isready` — the UCI contract's one window for options.
    internal var uciOptionLines: [String] {
        [
            "setoption name Hash value \(hashMB)",
            "setoption name Threads value \(threads)",
        ]
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
