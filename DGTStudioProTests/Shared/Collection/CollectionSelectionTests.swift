import Testing
@testable import DGTStudioPro

/// Pins the selection algebra (M18 Phase 2 - `CollectionSelection`). Nonisolated over plain
/// values, load-bearing: the contracts here feed the analysis queue's run order, export's
/// filename numbering, and ⌘A's "every visible row and no more" - all previously unpinnable
/// inside the destinations.
@Suite("Collection Selection")
struct CollectionSelectionTests {

    private struct Row: Identifiable, Equatable {
        let id: Int
    }

    private static func rows(_ ids: [Int]) -> [Row] { ids.map(Row.init) }

    // MARK: Display Order

    /// The contract that numbers export files: however the selection set is written, the
    /// result follows the *display list's* order - a set literal in reverse still comes back
    /// forward.
    @Test func selectionFollowsDisplayOrderNotSelectionOrder() {
        let display = Self.rows([40, 10, 30, 20])
        let picked = CollectionSelection.inDisplayOrder(Set([20, 40, 10]), of: display)
        #expect(picked.map(\.id) == [40, 10, 20])
    }

    /// A subsequence, exactly: non-members contribute nothing, and an id the display list
    /// no longer shows (deleted, or narrowed away) silently drops - the tombstone-adjacent
    /// behaviour every bulk door relies on.
    @Test func nonMembersAndAbsenteesDrop() {
        let display = Self.rows([1, 2, 3])
        #expect(CollectionSelection.inDisplayOrder(Set([3, 99]), of: display).map(\.id) == [3])
        #expect(CollectionSelection.inDisplayOrder(Set<Int>(), of: display).isEmpty)
        #expect(CollectionSelection.inDisplayOrder(Set([1]), of: [Row]()).isEmpty)
    }

    /// Order preservation as a property: any subset of a shuffled display list comes back as
    /// the display list minus the unpicked - verified by an independent walk.
    @Test func everySubsetIsASubsequenceOfTheDisplayList() {
        let display = Self.rows([7, 3, 9, 1, 8, 2, 6])
        let subsets: [Set<Int>] = [[7], [3, 6], [9, 1, 8], [7, 3, 9, 1, 8, 2, 6], [2, 7, 6]]
        for subset in subsets {
            let picked = CollectionSelection.inDisplayOrder(subset, of: display).map(\.id)
            #expect(picked == display.map(\.id).filter(subset.contains))
        }
    }

    // MARK: Select All

    /// ⌘A: the painted list's ids exactly - every visible row, no more, and a narrowed-away
    /// row is not visible.
    @Test func allIDsIsExactlyThePaintedList() {
        let display = Self.rows([5, 2, 8])
        #expect(CollectionSelection.allIDs(of: display) == Set([5, 2, 8]))
        #expect(CollectionSelection.allIDs(of: [Row]()) == Set<Int>())
    }

    /// The round trip: select all, then read back in display order - the identity on the
    /// visible list, which is what ⌘A-then-export means.
    @Test func selectAllThenDisplayOrderIsTheIdentity() {
        let display = Self.rows([12, 4, 9, 30])
        let all = CollectionSelection.allIDs(of: display)
        #expect(CollectionSelection.inDisplayOrder(all, of: display) == display)
    }
}
