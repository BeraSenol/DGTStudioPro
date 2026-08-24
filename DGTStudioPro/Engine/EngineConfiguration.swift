import Foundation

/// Single source of truth for the Stockfish options the app controls (M11 review: Settings
/// asserted values that lived nowhere - the engine silently ran on 16 MB hash). Values clamp on
/// init, so a hand-edited plist can never reach the engine out of range.
struct EngineConfiguration: Equatable, Sendable {
    
    // MARK: Bounds
    
    /// 8 = floor where per-ply evals stop being noise; 30 = ceiling where a pass stops being interactive.
    static let depthRange = 8...30
    
    /// Fixed menu of hash sizes - legible, and the clamp gets a nearest-size snap target. The snap
    /// below breaks ties **downward** (40 → 16, 96 → 64, 192 → 128), because `min(by:)` keeps the
    /// first of equals.
    static let hashChoicesMB = [16, 64, 128, 256, 512, 1024]
    
    /// One thread minimum; active cores as ceiling. Computed - core count is a fact about the host.
    static var threadsRange: ClosedRange<Int> {
        1...max(1, ProcessInfo.processInfo.activeProcessorCount)
    }

    // MARK: Syzygy Bounds

    /// Stockfish's own range for `SyzygyProbeDepth` (`spin default 1 min 1 max 100`) - how shallow
    /// in the tree probing may go; 1 probes everywhere.
    static let syzygyProbeDepthRange = 1...100

    /// `SyzygyProbeLimit` (`spin default 7 min 0 max 7`) - the largest piece count to probe. **7 is
    /// a ceiling, not a promise**: with only 3-4-5 tables Stockfish probes what it has.
    static let syzygyProbeLimitRange = 0...7

    // MARK: Values

    let depth: Int
    let hashMB: Int
    let threads: Int

    /// The tablebase folder as a plain path, or nil. A resolved path, not a bookmark - this type
    /// never opens the folder; holding scoped access is `SyzygyLocation.Access`'s job.
    let syzygyPath: String?

    let syzygyProbeDepth: Int
    let syzygy50MoveRule: Bool
    let syzygyProbeLimit: Int
    
    /// Depth 18 preserves pre-configuration behaviour (the old twin default, now once); 128 MB
    /// makes Settings true; 1 thread stays polite. Syzygy members default to Stockfish's own - with
    /// no path the type emits no Syzygy options at all.
    static let `default` = EngineConfiguration(depth: 18, hashMB: 128, threads: 1)

    /// Clamps depth/threads; snaps hash to the nearest offered size (a plist-edited 100 → 128).
    /// Syzygy spins clamp against Stockfish's advertised ranges.
    init(
        depth: Int,
        hashMB: Int,
        threads: Int,
        syzygyPath: String? = nil,
        syzygyProbeDepth: Int = 1,
        syzygy50MoveRule: Bool = true,
        syzygyProbeLimit: Int = 7
    ) {
        self.depth = depth.clamped(to: Self.depthRange)
        // The `??` is unreachable - `hashChoicesMB` is a non-empty literal - and is here only
        // because `min(by:)` is optional over a sequence that could in principle be empty.
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
    
    /// Persisted configuration, clamped on read. `UserDefaults` is thread-safe, so callable from
    /// the actor at launch and the driver per call - Settings apply to the *next* run, no restart story.
    ///
    /// **No defaults seam - always `.standard`.** Kept for `SettingsView`, whose bindings are the
    /// real domain by definition. Anything a suite can reach must call the overload below with an
    /// injected suite instead; the analysis path was moved off this one on 24 Aug 2026 for exactly
    /// that reason.
    static var current: EngineConfiguration {
        current(syzygyPath: nil)
    }

    /// The persisted configuration with a tablebase folder threaded in. The path is a parameter,
    /// not another defaults read - resolving the bookmark and holding scoped access is the caller's.
    static func current(
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

    /// The `setoption` lines sent after `uciok`, before `isready` - the one window.
    /// **`SyzygyPath` goes last**: Stockfish loads tables the moment it sees the path, under
    /// whatever probe settings are already in effect.
    var uciOptionLines: [String] {
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
    /// The standard clamp the stdlib doesn't ship.
    ///
    /// **An extension on `Comparable` lands on every comparable type in the app** - `Square.swift`
    /// makes the same warning about a bare `Int`, and this one is wider. It has already escaped this
    /// file: `CollectionViewOptions` clamps `CGFloat`s with it in eight places.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
