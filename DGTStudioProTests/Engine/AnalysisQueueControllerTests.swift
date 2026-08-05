import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// Transport-level pin for the controller's run-task plumbing. The pure
/// decisions are `AnalysisQueueTests`' job; this suite exists for the one
/// defect that lived *between* the pure queue and the engine — the
/// enqueue-during-drain race (M1 item 1) — which no pure test can see
/// because it is made of task lifetimes and a real 500 ms shutdown grace.
/// Real engine, binary-gated like `StockfishEngineTests`; in-memory
/// container like the store suites; `@MainActor` to match its subject.
@MainActor
@Suite("Analysis Queue Controller — drain race")
struct AnalysisQueueControllerTests {

    // `nonisolated`, load-bearing: `.enabled(if:)` evaluates its
    // condition in a `Sendable` closure outside the suite's isolation,
    // and in a `@MainActor` suite a bare static inherits main-actor
    // isolation — the macro expansion then fails to compile.
    // (`StockfishEngineTests` never needed this; that suite is
    // nonisolated.) Any future `@MainActor` suite gating on the binary
    // wants this same spelling.
    private nonisolated static var stockfishAvailable: Bool {
        StockfishEngine.defaultBinaryURL != nil
    }

    /// An `enqueue` landing inside the drain's `driver.shutdown()` grace
    /// must start a fresh run once the task clears itself. Pre-fix,
    /// `startRunIfNeeded` saw the stale `runTask`, refused the start,
    /// nothing ever re-checked, and the item sat "#1 in line" forever —
    /// this test's pre-fix failure mode is the second poll timing out
    /// with B still `.waiting`.
    ///
    /// Determinism note: observing `completedCount == 1` from the main
    /// actor is only possible once the run task has suspended, and its
    /// first suspension after recording A's outcome *is* the shutdown
    /// grace — so B reliably lands inside the window. Should scheduling
    /// ever delay this test past the grace, B lands after the task
    /// cleared and the test still passes, merely exercising the ordinary
    /// path that run.
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

        // Poll with a deadline and assert after — a timeout must be a
        // failure, never a silent pass (the F7 lesson).
        var deadline = Date().addingTimeInterval(90)
        while Date() < deadline, controller.queue.completedCount < 1 {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(controller.queue.completedCount == 1, "First game should finish")

        // The race: land B while the drain sits in its grace window.
        // (Enqueueing onto the momentarily-idle queue also resets the
        // finished log — the documented fresh-batch rule — which is why
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
