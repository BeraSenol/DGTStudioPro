import Testing
@testable import DGTStudioPro

/// The view mode's own opinions. Nonisolated: a `String`-raw enum with two computed properties and
/// no state - and the nonisolation is the witness that the inspector policy is reachable off the
/// main actor, which is what let it stop being a private method on two `View`s.
@Suite("Collection View Mode")
struct CollectionViewModeTests {

    /// Only `.columns` draws its own detail pane; the rule is stated as an identity, not a list, so
    /// a fifth mode arriving is forced through this test rather than silently joining the "no"s.
    @Test func onlyColumnsOwnsADetailPane() {
        for mode in CollectionViewMode.allCases {
            #expect(mode.ownsDetailPane == (mode == .columns))
        }
    }

    /// Gallery is a picker - the inspector is where the picked row's facts are, so entering opens it.
    @Test func galleryOpensTheInspectorOnEntry() {
        #expect(CollectionViewMode.gallery.inspectorPresentationOnEntry == true)
    }

    /// Columns already shows the same facts in its detail pane; a second copy is what the policy
    /// exists to prevent. Tied to `ownsDetailPane` rather than to the case, so the two cannot drift.
    @Test func aModeWithItsOwnDetailPaneClosesTheInspector() {
        #expect(CollectionViewMode.columns.inspectorPresentationOnEntry == false)
        for mode in CollectionViewMode.allCases where mode.ownsDetailPane {
            #expect(mode.inspectorPresentationOnEntry == false)
        }
    }

    /// **Nil is a third answer, not a default.** Icons and list leave the inspector where the reader
    /// put it; a `Bool` policy would have had to invent an opinion for them, and "leaving columns
    /// does not restore" is the behaviour that depends on it.
    @Test func theModesWithoutAnOpinionReturnNil() {
        #expect(CollectionViewMode.icons.inspectorPresentationOnEntry == nil)
        #expect(CollectionViewMode.list.inspectorPresentationOnEntry == nil)
    }
}
