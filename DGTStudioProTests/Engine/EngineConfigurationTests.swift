import Testing
@testable import DGTStudioPro

/// The clamp-and-format core of the engine configuration. `current` (the
/// `UserDefaults` read) is deliberately untested: it is three `??` falls
/// into the tested initializer, and its values are exercised live by every
/// analysis run.
///
/// Nonisolated: `EngineConfiguration` is a pure `Sendable` value type.
struct EngineConfigurationTests {
    
    @Test func defaultPreservesThePreConfigurationBehavior() {
        let config = EngineConfiguration.default
        #expect(config.depth == 18)     // the old twin default, now single
        #expect(config.hashMB == 128)   // the pane's promise, now true
        #expect(config.threads == 1)
    }
    
    @Test func depthClampsIntoRange() {
        #expect(EngineConfiguration(depth: 1, hashMB: 128, threads: 1).depth == 8)
        #expect(EngineConfiguration(depth: 99, hashMB: 128, threads: 1).depth == 30)
        #expect(EngineConfiguration(depth: 22, hashMB: 128, threads: 1).depth == 22)
    }
    
    @Test func hashSnapsToTheNearestOfferedSize() {
        #expect(EngineConfiguration(depth: 18, hashMB: 100, threads: 1).hashMB == 128)
        #expect(EngineConfiguration(depth: 18, hashMB: 0, threads: 1).hashMB == 16)
        #expect(EngineConfiguration(depth: 18, hashMB: 9000, threads: 1).hashMB == 1024)
        #expect(EngineConfiguration(depth: 18, hashMB: 512, threads: 1).hashMB == 512)
    }
    
    @Test func threadsClampIntoTheMachineRange() {
        #expect(EngineConfiguration(depth: 18, hashMB: 128, threads: 0).threads == 1)
        #expect(
            EngineConfiguration(depth: 18, hashMB: 128, threads: 9999).threads
            == EngineConfiguration.threadsRange.upperBound
        )
    }
    
    @Test func uciOptionLinesFollowTheSetoptionGrammar() {
        let lines = EngineConfiguration(depth: 18, hashMB: 256, threads: 2).uciOptionLines
        #expect(lines == [
            "setoption name Hash value 256",
            "setoption name Threads value 2",
        ])
    }
}
