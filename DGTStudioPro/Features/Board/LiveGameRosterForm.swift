import SwiftUI

// MARK: Placeholder Normalization

/// PGN's `"?"` ↔ empty-field boundary: `"?"` → `""` seeding a form, trimmed `""` → `"?"`
/// committing one. Kept adjacent so the round trip is obviously symmetric; not private, because
/// all three roster sheets stage it - `NewLiveGameSheet`, `EditLiveGameDetailsSheet`,
/// `EditGameInfoSheet`. They live in this file because it declares the form they serve.
func formValue(_ tag: String) -> String {
    tag == "?" ? "" : tag
}

func tagValue(_ field: String) -> String {
    let trimmed = field.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "?" : trimmed
}

/// Normalizes a whole roster before it leaves any form.
func normalized(_ roster: LiveGame.Roster) -> LiveGame.Roster {
    var result = roster
    result.event = tagValue(roster.event)
    result.site  = tagValue(roster.site)
    result.white = tagValue(roster.white)
    result.black = tagValue(roster.black)
    return result
}

// MARK: Roster Form

/// The roster form minus Result (the game tracks it). Shared by the new-game,
/// edit-details and archive-confirmation sheets, so the field set cannot drift.
///
/// **Its own file since 26 Aug 2026 (M16).** It was declared at the top of
/// `NewLiveGameSheet.swift` with three consumers elsewhere; a shared type carrying a refusal
/// (the D61′ seat guard below) lives in its own file. The placeholder helpers moved with it -
/// the form is what they serve.
struct LiveGameRosterForm: View {

    // MARK: Bound State

    @Binding var roster: LiveGame.Roster

    /// Identifier prefix for the six fields - the archive sheet passes `archive.form.*`.
    var identifierPrefix = AccessibilityID.liveFormPrefix

    /// Known-player **tag forms** for the seat pickers (the picker inserts
    /// `Player.tagName`, never `name`). The menu only fills; picking creates nothing.
    var knownPlayers: [String] = []

    /// `Roster.date` is optional but the dialog always supplies one (default today), so the picker
    /// binds through a non-optional facade.
    private var dateBinding: Binding<Date> {
        Binding(
            get: { roster.date ?? .now },
            set: { roster.date = $0 }
        )
    }

    /// The seat picker: a borderless menu trailing the field - the combo-box shape, no AppKit
    /// needed. Hidden when the host supplies no players.
    @ViewBuilder
    private func playerMenu(for field: Binding<String>, identifier: String) -> some View {
        if !knownPlayers.isEmpty {
            Menu {
                ForEach(knownPlayers, id: \.self) { name in
                    Button(name) { field.wrappedValue = name }
                }
            } label: {
                // One chevron (17 Aug 2026, by request): the old `chevron.up.chevron.down`
                // stacked beside the button style's own indicator and the pair read as a
                // stepper glued to a dropdown.
                Image(systemName: "chevron.down")
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Choose a known player")
            .accessibilityIdentifier(identifier)
        }
    }

    // MARK: Body

    var body: some View {
        Form {
            Section("Players") {
                HStack {
                    TextField(
                        "White",
                        text: $roster.white,
                        prompt: Text("White player")
                    )
                    .accessibilityIdentifier(
                        AccessibilityID.formWhite(identifierPrefix)
                    )
                    playerMenu(
                        for: $roster.white,
                        identifier: AccessibilityID.formWhitePicker(identifierPrefix)
                    )
                }

                HStack {
                    TextField(
                        "Black",
                        text: $roster.black,
                        prompt: Text("Black player")
                    )
                    .accessibilityIdentifier(AccessibilityID.formBlack(identifierPrefix))
                    playerMenu(
                        for: $roster.black,
                        identifier: AccessibilityID.formBlackPicker(identifierPrefix)
                    )
                }

                // The guard: the two seats are one `Roster`, so the check needs no drafts to compare.
                // A warning line plus a disabled Start - the alert belongs to Get Info's commit model.
                if roster.seatsNameOnePlayer {
                    Label(
                        "\(PlayerName.displayForm(of: roster.white)) can’t play both sides. "
                        + "Give one seat a different name, or clear it to “\(RosterSummary.unknownTag)”.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier(
                        AccessibilityID.formSeatConflict(identifierPrefix)
                    )
                }
            }

            Section("Event") {
                TextField(
                    "Event",
                    text: $roster.event,
                    prompt: Text("Casual Game")
                )
                .accessibilityIdentifier(AccessibilityID.formEvent(identifierPrefix))

                TextField(
                    "Site",
                    text: $roster.site,
                    prompt: Text(verbatim: "City, Region BEL")
                )
                .accessibilityIdentifier(AccessibilityID.formSite(identifierPrefix))

                // The seat guard's shape, applied to format: a warning line here, the disabled
                // affirmative button at each host. Empty is exempt - it folds to "?" at the door.
                if roster.siteViolatesFormat {
                    Label(
                        "Site follows PGN’s “City, Region CCC” - “Hasselt, Limburg BEL”. "
                        + "Clear the field for an unknown site.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier(
                        AccessibilityID.formSiteFormat(identifierPrefix)
                    )
                }

                DatePicker(
                    "Date",
                    selection: dateBinding,
                    displayedComponents: .date
                )
                .accessibilityIdentifier(AccessibilityID.formDate(identifierPrefix))

                TextField(
                    "Round",
                    value: $roster.round,
                    format: .number,
                    prompt: Text("Optional")
                )
                .accessibilityIdentifier(AccessibilityID.formRound(identifierPrefix))
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: Previews

/// The site-format guard's warning arm (16 Aug 2026) - the branch a well-behaved fixture
/// never reaches, which is why it has a preview.
#Preview("Roster Form, Malformed Site") {
    @Previewable @State var roster = LiveGame.Roster(
        event: "Club Night",
        site: "Home",
        white: "Senol, Bera",
        black: "Baelus, Lorenzo"
    )

    LiveGameRosterForm(roster: $roster)
        .frame(width: 420, height: 400)
}

/// The seat guard, which nothing else renders. The two seats are spelled differently on
/// purpose - tag form against display form, one player either way - proving the fold, not `==`.
#Preview("Roster Form, Seats Collide") {
    @Previewable @State var roster = LiveGame.Roster(
        event: "Club Night",
        white: "Lopez, Ruy",
        black: "Ruy Lopez"
    )

    LiveGameRosterForm(roster: $roster)
        .frame(width: 420, height: 380)
}
