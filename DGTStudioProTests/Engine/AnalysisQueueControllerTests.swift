import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// Transport-level pin - the one defect that lived *between* the pure queue and the engine.
@MainActor
@Suite("Analysis Queue Controller - Drain Race")
struct AnalysisQueueControllerTests {

    // `nonisolated`, load-bearing: `.enabled(if:)` evaluates in a `Sendable` closure outside the
    // suite's isolation.
    private nonisolated static var stockfishAvailable: Bool {
        StockfishEngine.defaultBinaryURL != nil
    }

    /// An `enqueue` landing inside the drain's shutdown grace must start a fresh run once the task
    /// clears - pre-fix it was refused and the batch sat queued forever.
    @Test(.enabled(if: stockfishAvailable))
    func enqueueDuringDrainGraceStartsAFreshRun() async throws {
        let container = try ModelContainer(
            for: PGN.self, Player.self, SmartTag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let first = PGN(
            event: "Race", site: "Memory", round: 1,
            white: "White, Player", black: "Black, Player",
            moves: ["e4"], name: "Race A", result: .ongoing,
            contentHash: "race-a"
        )
        let second = PGN(
            event: "Race", site: "Memory", round: 2,
            white: "White, Player", black: "Black, Player",
            moves: ["d4"], name: "Race B", result: .ongoing,
            contentHash: "race-b"
        )
        context.insert(first)
        context.insert(second)
        try context.save()

        let controller = AnalysisQueueController()
        controller.enqueue([first], modelContext: context)

        // Poll with a deadline and assert after - a timeout must be a
        // failure, never a silent pass (the F7 lesson).
        var deadline = Date().addingTimeInterval(90)
        while Date() < deadline, controller.queue.completedCount < 1 {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(controller.queue.completedCount == 1, "First game should finish")

        // The race: land B while the drain sits in its grace window.
        // (Enqueueing onto the momentarily-idle queue also resets the
        // finished log - the documented fresh-batch rule - which is why
        // the assertions below ask about B's status, not counts.)
        controller.enqueue([second], modelContext: context)

        deadline = Date().addingTimeInterval(90)
        while Date() < deadline,
              controller.queue.status(of: second.persistentModelID) != .finished(.done) {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(controller.queue.status(of: second.persistentModelID) == .finished(.done),
                "A grace-window enqueue must be picked up by a fresh run")

        await controller.shutdown()
    }
}
