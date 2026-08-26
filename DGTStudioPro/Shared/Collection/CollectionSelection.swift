/// The selection algebra both destinations run over their display lists (M18 Phase 2) - two
/// one-liners, extracted not for reuse but because their contracts are load-bearing and were
/// unpinnable inside a `View`: display order feeds the analysis queue's run order *and* numbers
/// export filenames, and ⌘A's "every visible row and no more" is a promise the standing manual
/// checks spell out. Generic over `Identifiable` so the suite runs on plain values.
enum CollectionSelection {

    /// The selected models in **display order** - the display list filtered, so the result is
    /// always a subsequence of it: however the selection was accumulated (rubber-band, ⌘-click,
    /// ⌘A), what runs and what exports follows the screen.
    static func inDisplayOrder<Element: Identifiable>(
        _ ids: Set<Element.ID>,
        of displayList: [Element]
    ) -> [Element] {
        displayList.filter { ids.contains($0.id) }
    }

    /// ⌘A: the painted list's ids, exactly - a row scrolled out by a query is not selected,
    /// because it is not visible.
    static func allIDs<Element: Identifiable>(of displayList: [Element]) -> Set<Element.ID> {
        Set(displayList.map(\.id))
    }
}
