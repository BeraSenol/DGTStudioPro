import CoreGraphics

/// The inspector column's one width, every destination (17 Aug 2026, by request). The three
/// per-destination values it replaces - Library 335, Board 350, Players 365 - made the column
/// jump as you switched destinations; unified at the **largest recorded minimum**, so no
/// destination loses width its content needed (Players' profile grid set the floor).
///
/// One owner, not three call-site literals - the twin-read-site rule. The Board's hand-rolled
/// pane and the two `.inspector` destinations all read this; a future value change is one
/// edit. Priced cost of sameness: Library and Players pin min = ideal = max, so the drag
/// resize their old `max: 400` allowed is gone - a dragged-wide column would differ from its
/// siblings again, which is the thing this constant exists to end.
enum InspectorColumn {
    static let width: CGFloat = 365
}
