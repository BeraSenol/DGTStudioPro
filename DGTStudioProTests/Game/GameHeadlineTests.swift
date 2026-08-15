import Testing
@testable import DGTStudioPro

/// The inspector headline's grammar. Nonisolated: `GameHeadline` is a
/// pure formatter over value inputs.
struct GameHeadlineTests {
    
    @Test func reviewingCarriesTheRoundAndThePairing() {
        #expect(
            GameHeadline.text(.reviewing, round: 1, white: "Carlsen", black: "Nepomniachtchi")
            == "Reviewing 1. Carlsen vs Nepomniachtchi"
        )
    }
    
    @Test func recordingUsesTheLiveVerb() {
        #expect(
            GameHeadline.text(.recording, round: 101, white: "Carlsen", black: "Nepomniachtchi")
            == "Recording 101. Carlsen vs Nepomniachtchi"
        )
    }
    
    @Test func anAbsentRoundOmitsTheNumberRatherThanPlaceholdingIt() {
        #expect(
            GameHeadline.text(.reviewing, round: nil, white: "Alice", black: "Bob")
            == "Reviewing Alice vs Bob"
        )
    }
    
    @Test func namesArriveInDisplayForm() {
        #expect(
            GameHeadline.text(
                .reviewing, round: 7,
                white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian"
            )
            == "Reviewing 7. Magnus Carlsen vs Ian Nepomniachtchi"
        )
    }
    
    @Test func blankSeatsReadAsThePlaceholder() {
        #expect(
            GameHeadline.text(.recording, round: nil, white: "", black: "   ")
            == "Recording ? vs ?"
        )
    }
    
    @Test func questionMarkTagsPassThroughUnchanged() {
        #expect(
            GameHeadline.text(.reviewing, round: 2, white: "?", black: "?")
            == "Reviewing 2. ? vs ?"
        )
    }
}
